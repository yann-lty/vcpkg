[CmdletBinding()]
param (
    $libraries = @(),
    $version = "boost-1.65.1"
)

$scriptsDir = split-path -parent $MyInvocation.MyCommand.Definition

$libsDisabledInUWP = "iostreams|filesystem|thread|context|python|stacktrace|program-options|program_options|coroutine`$|fiber|locale|test|type-erasure|type_erasure|wave|log"

function Generate()
{
    param (
        [string]$Name,
        [string]$Hash,
        [string]$Options = "",
        $Depends = @()
    )

    $controlDeps = ($Depends | sort) -join ", "

    $sanitizedName = $name -replace "_","-"

    mkdir "$scriptsDir/../boost-$sanitizedName" -erroraction SilentlyContinue | out-null
    $(gc "$scriptsDir/CONTROL.in") `
        -replace "@NAME@", "$sanitizedName" `
        -replace "@DEPENDS@", "$controlDeps" `
        -replace "@DESCRIPTION@", "Boost $Name module" `
    | out-file -enc ascii "$scriptsDir/../boost-$sanitizedName/CONTROL"

    $(gc "$scriptsDir/portfile.cmake.in") `
        -replace "@NAME@", "$Name" `
        -replace "@HASH@", "$Hash" `
        -replace "@OPTIONS@", "$Options" `
    | out-file -enc ascii "$scriptsDir/../boost-$sanitizedName/portfile.cmake"

    if ($Name -eq "locale")
    {
        "`nFeature: icu`nDescription: ICU backend for Boost.Locale`nBuild-Depends: icu`n" | out-file -enc ascii -append "$scriptsDir/../boost-$sanitizedName/CONTROL"
    }
    if ($Name -eq "regex")
    {
        "`nFeature: icu`nDescription: ICU backend for Boost.Regex`nBuild-Depends: icu`n" | out-file -enc ascii -append "$scriptsDir/../boost-$sanitizedName/CONTROL"
    }
}

if (!(Test-Path "$scriptsDir/boost"))
{
    "Cloning boost..."
    pushd $scriptsDir
    try
    {
        git clone https://github.com/boostorg/boost --branch $version
    }
    finally
    {
        popd
    }
}

$libraries_found = ls $scriptsDir/boost/libs -directory | % name | % {
    if ($_ -match "numeric")
    {
        "numeric_conversion"
        "interval"
        "odeint"
        "ublas"
    }
    else
    {
        $_
    }
}

mkdir $scriptsDir/downloads -erroraction SilentlyContinue | out-null

if ($libraries.Length -eq 0)
{
    $libraries = $libraries_found
}

$libraries_in_boost_port = @()

foreach ($library in $libraries)
{
    "Handling boost/$library..."
    $archive = "$scriptsDir/downloads/$library-$version.tar.gz"
    if (!(Test-Path $archive))
    {
        "Downloading boost/$library..."
        Invoke-WebRequest "https://github.com/boostorg/$library/archive/$version.tar.gz" -OutFile $archive
    }
    $hash = vcpkg hash $archive
    $unpacked = "$scriptsDir/libs/$library-$version"
    if (!(Test-Path $unpacked))
    {
        "Unpacking boost/$library..."
        mkdir $scriptsDir/libs -erroraction SilentlyContinue | out-null
        pushd $scriptsDir/libs
        try
        {
            cmake -E tar xf $archive
        }
        finally
        {
            popd
        }
    }
    pushd $unpacked
    try
    {
        $groups = $(
            findstr /si /C:"#include <boost/" include/*
            findstr /si /C:"#include <boost/" src/*
        ) |
        % { $_ -replace "^[^:]*:","" -replace "boost/numeric/conversion/","boost/numeric_conversion/" -replace "boost/detail/([^/]+)/","boost/`$1/" -replace "#include ?<boost/([a-zA-Z0-9\._]*)(/|>).*", "`$1" -replace "/|\.hp?p?| ","" } | group | % name | % {
            # mappings
            Write-Verbose "${library}: $_"
            if ($_ -match "aligned_storage") { "type_traits" }
            elseif ($_ -match "noncopyable|ref|swap|get_pointer|checked_delete|visit_each") { "core" }
            elseif ($_ -eq "type") { "core" }
            elseif ($_ -match "unordered_") { "unordered" }
            elseif ($_ -match "cstdint") { "integer" }
            elseif ($_ -match "call_traits|operators|current_function|cstdlib|next_prior") { "utility" }
            elseif ($_ -eq "version") { "config" }
            elseif ($_ -match "shared_ptr|make_shared|intrusive_ptr|scoped_ptr|pointer_to_other|weak_ptr|shared_array|scoped_array") { "smart_ptr" }
            elseif ($_ -match "iterator_adaptors|generator_iterator|pointee") { "iterator" }
            elseif ($_ -eq "regex_fwd") { "regex" }
            elseif ($_ -eq "make_default") { "convert" }
            elseif ($_ -eq "foreach_fwd") { "foreach" }
            elseif ($_ -eq "cerrno") { "system" }
            elseif ($_ -eq "archive") { "serialization" }
            elseif ($_ -eq "none") { "optional" }
            elseif ($_ -eq "integer_traits") { "integer" }
            elseif ($_ -eq "limits") { "compatibility" }
            elseif ($_ -eq "math_fwd") { "math" }
            elseif ($_ -match "polymorphic_cast|implicit_cast") { "conversion" }
            elseif ($_ -eq "nondet_random") { "random" }
            elseif ($_ -eq "memory_order") { "atomic" }
            elseif ($_ -eq "blank") { "detail" }
            elseif ($_ -match "is_placeholder|mem_fn") { "bind" }
            elseif ($_ -eq "exception_ptr") { "exception" }
            elseif ($_ -eq "multi_index_container") { "multi_index" }
            elseif ($_ -eq "lexical_cast") { "lexical_cast"; "math" }
            elseif ($_ -eq "numeric" -and $library -notmatch "numeric_conversion|interval|odeint|ublas") { "numeric_conversion"; "interval"; "odeint"; "ublas" }
            else { $_ }
        } | group | % name | ? { $_ -ne $library }

        #"`nFor ${library}:"
        "      [known] " + $($groups | ? { $libraries_found -contains $_ })
        "    [unknown] " + $($groups | ? { $libraries_found -notcontains $_ })

        $deps = @($groups | ? { $libraries_found -contains $_ })

        $deps = @($deps | ? {
            # Boost contains cycles, so remove a few dependencies to break the loop.
            (($library -notmatch "core|assert|mpl|detail|type_traits") -or ($_ -notmatch "utility")) `
            -and `
            (($library -notmatch "lexical_cast") -or ($_ -notmatch "math"))`
            -and `
            (($library -notmatch "functional") -or ($_ -notmatch "function"))`
            -and `
            (($library -notmatch "detail") -or ($_ -notmatch "integer|mpl|type_traits"))`
            -and `
            (($library -notmatch "property_map") -or ($_ -notmatch "mpi"))`
            -and `
            (($library -notmatch "spirit") -or ($_ -notmatch "serialization"))`
            -and `
            (($library -notmatch "utility|concept_check") -or ($_ -notmatch "iterator"))
        } | % { "boost-$_" -replace "_","-" } | % {
            if ($_ -match $libsDisabledInUWP)
            {
                "$_ (windows)"
            }
            else
            {
                $_
            }
        })

        $deps += @("boost-vcpkg-helpers")

        if (Test-Path $unpacked/build/Jamfile.v2)
        {
            $deps += @("boost-build")
        }

        if ($library -eq "python")
        {
            $deps += @("python3")
        }
        elseif ($library -eq "iostreams")
        {
            $deps += @("zlib", "bzip2")
        }

        Generate `
            -Name $library `
            -Hash $hash `
            -Depends $deps

        if ($library -match $libsDisabledInUWP)
        {
            $libraries_in_boost_port += @("$library (windows)")
        }
        else
        {
            $libraries_in_boost_port += @($library)
        }

    }
    finally
    {
        popd
    }
}

"Source: boost`nVersion: 1.65.1-4`nBuild-Depends: $($($libraries_in_boost_port | % { "boost-$_" -replace "_","-" }) -join ", ")`n" | out-file -enc ascii $scriptsDir/../boost/CONTROL
"set(VCPKG_POLICY_EMPTY_PACKAGE enabled)`n" | out-file -enc ascii $scriptsDir/../boost/portfile.cmake

return

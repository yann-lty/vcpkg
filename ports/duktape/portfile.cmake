include(vcpkg_common_functions)
set(VERSION 2.2.0)
set(SOURCE_PATH ${CURRENT_BUILDTREES_DIR}/src/duktape-${VERSION})
vcpkg_download_distfile(ARCHIVE_FILE
    URLS "https://github.com/svaarala/duktape/releases/download/v${VERSION}/duktape-${VERSION}.tar.xz"
    FILENAME "duktape-${VERSION}.tar.xz"
    SHA512 6fe67660ad4cfbab37b9048840bd8c42ee9585441c17253e1f17cb06e4527d1413851bc167d8b013990d5cae9f8e6eb4cb6ff80866f55bd8d67b0cf47580be7c
)
vcpkg_extract_source_archive(${ARCHIVE_FILE})

vcpkg_apply_patches(
    SOURCE_PATH ${SOURCE_PATH}
    PATCHES "${CMAKE_CURRENT_LIST_DIR}/duk_config.h.patch"
)

vcpkg_configure_cmake(
    SOURCE_PATH ${CMAKE_CURRENT_LIST_DIR}
    PREFER_NINJA
    OPTIONS -DSOURCE_PATH=${SOURCE_PATH}
)

vcpkg_install_cmake()

set(DUK_CONFIG_H_PATH "${CURRENT_PACKAGES_DIR}/include/duk_config.h")
file(READ ${DUK_CONFIG_H_PATH} CONTENT)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    string(REPLACE "// #undef DUK_F_DLL_BUILD" "#undef DUK_F_DLL_BUILD\n#define DUK_F_DLL_BUILD 1" CONTENT "${CONTENT}")
else()
    string(REPLACE "// #undef DUK_F_DLL_BUILD" "#undef DUK_F_DLL_BUILD\n#define DUK_F_DLL_BUILD 0" CONTENT "${CONTENT}")
endif()
file(WRITE ${DUK_CONFIG_H_PATH} "${CONTENT}")

# Remove debug include
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)

# Copy copright information
file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/duktape" RENAME "copyright")

vcpkg_copy_pdbs()

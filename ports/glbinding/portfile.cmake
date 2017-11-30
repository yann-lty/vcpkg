include(vcpkg_common_functions)
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cginternals/glbinding
    REF v2.1.3
    SHA512 2cb063ba905c72ea36583122bf2a263eac2ac17572f4bd16b43c406271bcb2e3e7af51e60e4458232f731b780488807a37da39849dd24b7553766a14677dbf1d
    HEAD_REF master
)

vcpkg_apply_patches(
    SOURCE_PATH ${SOURCE_PATH}
    PATCHES
        ${CMAKE_CURRENT_LIST_DIR}/use-gnuinstalldirs.patch
)

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
    OPTIONS
        -DOPTION_BUILD_TESTS=OFF
        -DOPTION_BUILD_GPU_TESTS=OFF
        -DOPTION_BUILD_TOOLS=OFF
        -DUSE_GNUINSTALLDIRS=ON
)

foreach(FILE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/source/glbinding/include/glbinding/glbinding_api.h" "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/source/glbinding/include/glbinding/glbinding_api.h")
    file(READ "${FILE}" _contents)
    string(REPLACE "/* We are building this library */\n#      define GLBINDING_TEMPLATE_API __attribute__((visibility(\"default\")))" "#define GLBINDING_TEMPLATE_API __declspec(dllexport)" _contents "${_contents}")
    string(REPLACE "__attribute__((visibility(\"default\")))" "" _contents "${_contents}")
    file(WRITE "${FILE}" "${_contents}")
endforeach()

vcpkg_install_cmake()

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
vcpkg_fixup_cmake_targets(CONFIG_PATH cmake/glbinding)

file(RENAME ${CURRENT_PACKAGES_DIR}/data ${CURRENT_PACKAGES_DIR}/share/data)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/data)
file(REMOVE ${CURRENT_PACKAGES_DIR}/AUTHORS
            ${CURRENT_PACKAGES_DIR}/LICENSE
            ${CURRENT_PACKAGES_DIR}/README.md
            ${CURRENT_PACKAGES_DIR}/VERSION
            ${CURRENT_PACKAGES_DIR}/debug/AUTHORS
            ${CURRENT_PACKAGES_DIR}/debug/LICENSE
            ${CURRENT_PACKAGES_DIR}/debug/README.md
            ${CURRENT_PACKAGES_DIR}/debug/VERSION
    )

# Handle copyright
file(COPY ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/glbinding)
file(RENAME ${CURRENT_PACKAGES_DIR}/share/glbinding/LICENSE ${CURRENT_PACKAGES_DIR}/share/glbinding/copyright)

vcpkg_copy_pdbs()
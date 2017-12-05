include(vcpkg_common_functions)

# This fixes the lib path to use desktop libs instead of uwp -- TODO: improve this with better "host" compilation
string(REPLACE "\\store\\;" "\\;" LIB "$ENV{LIB}")
set(ENV{LIB} "${LIB}")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO boostorg/build
    REF boost-1.65.1
    SHA512 7dae33884f2ae05054f5151cfa183f349ca83948a88c1c57eb8213444135acb43913581c03337d71c849cf98a654d828275da4ce05a8de68e1556fa25cef1aa5
    HEAD_REF master
)

vcpkg_download_distfile(ARCHIVE
    URLS "https://raw.githubusercontent.com/boostorg/boost/boost-1.65.1/LICENSE_1_0.txt"
    FILENAME "boost_LICENSE_1_0.txt"
    SHA512 d6078467835dba8932314c1c1e945569a64b065474d7aced27c9a7acc391d52e9f234138ed9f1aa9cd576f25f12f557e0b733c14891d42c16ecdc4a7bd4d60b8
)

vcpkg_download_distfile(BOOSTCPP_ARCHIVE
    URLS "https://raw.githubusercontent.com/boostorg/boost/boost-1.65.1/boostcpp.jam"
    FILENAME "boost-1.65.1-boostcpp.jam"
    SHA512 9006fe69054a9529fb0abce0d83b7a36f03993d4ce67084e081058d50368db8607b742e3f547a840ff7ab5ee94b9886d8f83ce67786131956c1a76504c947bc2
)

file(COPY
    ${SOURCE_PATH}/
    DESTINATION ${CURRENT_PACKAGES_DIR}/tools/boost-build
)

file(READ "${CURRENT_PACKAGES_DIR}/tools/boost-build/src/tools/msvc.jam" _contents)
string(REPLACE " /ZW /EHsc " "" _contents "${_contents}")
string(REPLACE "-nologo" "" _contents "${_contents}")
string(REPLACE "/nologo" "" _contents "${_contents}")
string(REPLACE "/Zm800" "" _contents "${_contents}")
string(REPLACE "<define>_WIN32_WINNT=0x0602" "" _contents "${_contents}")
file(WRITE "${CURRENT_PACKAGES_DIR}/tools/boost-build/src/tools/msvc.jam" "${_contents}")

message(STATUS "Bootstrapping...")
vcpkg_execute_required_process(
    COMMAND "${CURRENT_PACKAGES_DIR}/tools/boost-build/bootstrap.bat" msvc
    WORKING_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools/boost-build
    LOGNAME bootstrap-${TARGET_TRIPLET}
)

file(INSTALL ${ARCHIVE} DESTINATION ${CURRENT_PACKAGES_DIR}/share/boost-build RENAME copyright)
file(INSTALL ${BOOSTCPP_ARCHIVE} DESTINATION ${CURRENT_PACKAGES_DIR}/tools/boost-build RENAME boostcpp.jam)

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

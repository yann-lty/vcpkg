cmake_minimum_required(VERSION 3.8)
project(berkeleydb C CXX)

option(INSTALL_HEADERS "Install header files" ON)

add_definitions(
    -DWIN32
    -D_WINDOWS
    -D_CRT_SECURE_NO_DEPRECATE
    -D_CRT_NONSTDC_NO_DEPRECATE
)

if(BUILD_SHARED_LIBS)
    add_definitions(-DDB_CREATE_DLL -D_USRDLL)
endif()
    add_definitions(-D_LIB)
else()

file(GLOB_RECURSE SOURCES
    *.c
    *.cpp
    build_windows/libdb.def
)

add_library(libdb48 ${SOURCES})

include_directories(${CMAKE_CURRENT_SOURCE_DIR} build_windows dbinc)

target_link_libraries(libdb48 PUBLIC ws2_32.lib)

install(TARGETS libdb48
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

if(INSTALL_HEADERS)
    file(GLOB HEADERS build_windows/*.h)
    install(FILES ${HEADERS} DESTINATION include)
endif()

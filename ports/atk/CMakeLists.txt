cmake_minimum_required(VERSION 3.0)
project(atk C)

set(ATK_LIB_SUFFIX 1.0)
set(ATK_DLL_SUFFIX 1)
set(GLIB_LIB_VERSION 2.0)

if(BUILD_SHARED_LIBS)
    set(ATK_EXPORT_MACRO DLL_EXPORT)
endif()

# generate atkmarshal.c and atkmarshal.h source files
# glib-genmarshal should be installed along with glib
if(NOT EXISTS ${CMAKE_SOURCE_DIR}/atk/atkmarshal.h OR NOT EXISTS ${CMAKE_SOURCE_DIR}/atk/atkmarshal.c)
    find_program(GLIB_GENMARSHAL glib-genmarshal PATH_SUFFIXES glib)
    execute_process(
        COMMAND ${GLIB_GENMARSHAL} --prefix=atk_marshal atkmarshal.list --header
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/atk
        OUTPUT_FILE ${CMAKE_SOURCE_DIR}/atk/atkmarshal.h)
    execute_process(
        COMMAND ${GLIB_GENMARSHAL} --prefix=atk_marshal atkmarshal.list --body
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/atk
        OUTPUT_FILE ${CMAKE_SOURCE_DIR}/atk/atkmarshal.c)
endif()

configure_file(config.h.win32 ${CMAKE_SOURCE_DIR}/config.h COPYONLY)
add_definitions(-DHAVE_CONFIG_H)
include_directories(. ./atk)

find_path(GLIB_INCLUDE_DIR glib.h)
find_library(GLIB_GLIB_LIBRARY glib-${GLIB_LIB_VERSION})
find_library(GLIB_GOBJECT_LIBRARY gobject-${GLIB_LIB_VERSION})
find_library(GLIB_GMODULE_LIBRARY gmodule-${GLIB_LIB_VERSION})
set(GLIB_LIBRARIES ${GLIB_GLIB_LIBRARY} ${GLIB_GOBJECT_LIBRARY} ${GLIB_GMODULE_LIBRARY})

find_path(LIBINTL_INCLUDE_DIR libintl.h)
find_library(LIBINTL_LIBRARY NAMES libintl intl)

file(GLOB ATK_SOURCES atk/*.c)

add_library(atk ${ATK_SOURCES})
target_compile_definitions(atk PRIVATE ATK_COMPILATION ${ATK_EXPORT_MACRO} G_DISABLE_SINGLE_INCLUDES ATK_LOCALEDIR="/dummy/share/locale")
target_link_libraries(atk PRIVATE ${LIBINTL_LIBRARY} ${GLIB_LIBRARIES})
target_include_directories(atk PRIVATE ${GLIB_INCLUDE_DIR} ${LIBINTL_INCLUDE_DIR})

set_target_properties(atk PROPERTIES 
    OUTPUT_NAME atk-${ATK_DLL_SUFFIX}
    ARCHIVE_OUTPUT_NAME atk-${ATK_LIB_SUFFIX})

install(TARGETS atk RUNTIME DESTINATION bin ARCHIVE DESTINATION lib LIBRARY DESTINATION lib)

if(NOT ATK_SKIP_HEADERS)
    file(GLOB HEADERS atk/*.h)
    install(FILES ${HEADERS} DESTINATION include/atk)
endif()

message(STATUS "Link-time dependencies:")
message(STATUS "  " ${LIBINTL_LIBRARY})
foreach(GL ${GLIB_LIBRARIES})
    message(STATUS "  " ${GL})
endforeach()

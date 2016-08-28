find_package(Vala REQUIRED)

include(ValaVersion)
ensure_vala_version("0.11.3" MINIMUM)

include(ValaPrecompile)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0 gtksourceview-3.0 granite poppler-glib libxml-2.0 libsoup-2.4)

set(CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
set(LIB_PATHS ${DEPS_LIBRARY_DIRS})
link_directories(${LIB_PATHS})

file(GLOB_RECURSE VALA_SRC_ABS *.vala)
set(VALA_SRC "")
foreach(VALA_SRC_FILE_ABS ${VALA_SRC_ABS})
    file(RELATIVE_PATH VALA_SRC_FILE "${CMAKE_CURRENT_LIST_DIR}" "${VALA_SRC_FILE_ABS}")
    list(APPEND VALA_SRC "${VALA_SRC_FILE}")
endforeach(VALA_SRC_FILE_ABS)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(DEBUG "DEBUG")
endif()

add_definitions(${CFLAGS} -Wno-deprecated-declarations -DINSTALL_PREFIX="${CMAKE_INSTALL_PREFIX}" -DVERSION="${VERSION}")

vala_precompile(
    VALA_C ${VALA_SRC}
    PACKAGES gtk+-3.0 gtksourceview-3.0 granite poppler-glib libxml-2.0 posix libsoup-2.4
    OPTIONS --thread --target-glib=2.32
    DEFINITIONS DEBUG
    )

file(GLOB SYNCTEX_SRC_ABS ../lib/synctex/*.c)
include_directories(../lib/synctex)
add_executable(athena-latex-ide ${VALA_C} ${SYNCTEX_SRC_ABS} config.c)
target_link_libraries(athena-latex-ide ${DEPS_LIBRARIES} m z)
install(TARGETS athena-latex-ide DESTINATION bin)


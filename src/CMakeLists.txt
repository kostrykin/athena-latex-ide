find_package(Vala REQUIRED)

include(ValaVersion)
ensure_vala_version("0.11.3" MINIMUM)

include(ValaPrecompile)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0 gtksourceview-3.0 granite poppler-glib)

set(CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
set(LIB_PATHS ${DEPS_LIBRARY_DIRS})
link_directories(${LIB_PATHS})

file(GLOB VALA_SRC_ABS *.vala)
set(VALA_SRC "")
foreach(VALA_SRC_FILE_ABS ${VALA_SRC_ABS})
    file(RELATIVE_PATH VALA_SRC_FILE "${CMAKE_CURRENT_LIST_DIR}" "${VALA_SRC_FILE_ABS}")
    list(APPEND VALA_SRC "${VALA_SRC_FILE}")
endforeach(VALA_SRC_FILE_ABS)

add_definitions(${CFLAGS} -Wno-deprecated-declarations)
vala_precompile(VALA_C ${VALA_SRC} PACKAGES gtk+-3.0 gtksourceview-3.0 granite poppler-glib OPTIONS --thread --target-glib=2.32)

file(GLOB SYNCTEX_SRC_ABS ../lib/synctex/*.c)
include_directories(../lib/synctex)
add_executable(athena ${VALA_C} ${SYNCTEX_SRC_ABS})
target_link_libraries(athena ${DEPS_LIBRARIES} m z)


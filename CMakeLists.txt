cmake_minimum_required(VERSION 2.8)
cmake_policy(VERSION 2.8)

project(Athena)
set(MAJOR_VERSION "0")
set(MINOR_VERSION "1")
set(PATCH_VERSION "0")
set(VERSION "${MAJOR_VERSION}.${MINOR_VERSION}")

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "/usr" CACHE PATH "default install path" FORCE)
endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

add_subdirectory(src)
add_subdirectory(schemas)
add_subdirectory(assets)

set(CPACK_GENERATOR "DEB")
set(CPACK_PACKAGE_NAME "athena-latex-ide")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Streamlined LaTeX IDE designed for elementary OS with built-in support for pdflatex, lualatex, xetex and bibtex")
set(CPACK_PACKAGE_VENDOR "Leonid Kostrykin")
set(CPACK_PACKAGE_CONTACT "void@evoid.de")
set(CPACK_PACKAGE_VERSION_MAJOR "${MAJOR_VERSION}")
set(CPACK_PACKAGE_VERSION_MINOR "${MINOR_VERSION}")
set(CPACK_PACKAGE_VERSION_PATCH "${PATCH_VERSION}")
set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${MAJOR_VERSION}.${MINOR_VERSION}-${CPACK_PACKAGE_VERSION_PATCH}")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libgtksourceview-3.0-1 (>= 3.14.4), libxml2 (>= 2.9.1), libgranite3 (>= 0.3.1), libgtk-3-0 (>= 3.14), libglib2.0-0 (>= 2.32), libpoppler-glib8 (>= 0.24)")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_SECTION "editors")
set(CPACK_DEBIAN_ARCHITECTURE ${CMAKE_SYSTEM_PROCESSOR})
include(CPack)


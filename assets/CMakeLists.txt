install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/athena-128.png DESTINATION share/icons/hicolor/128x128/apps RENAME athena-latex-ide.png)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/athena-64.png  DESTINATION share/icons/hicolor/64x64/apps   RENAME athena-latex-ide.png)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/athena-48.png  DESTINATION share/icons/hicolor/48x48/apps   RENAME athena-latex-ide.png)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/athena-32.png  DESTINATION share/icons/hicolor/32x32/apps   RENAME athena-latex-ide.png)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/athena-24.png  DESTINATION share/icons/hicolor/24x24/apps   RENAME athena-latex-ide.png)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/athena-16.png  DESTINATION share/icons/hicolor/16x16/apps   RENAME athena-latex-ide.png)

if(CMAKE_INSTALL_PREFIX STREQUAL "/usr")
    install(CODE "execute_process(COMMAND gtk-update-icon-cache -q /usr/share/icons/hicolor)")
endif()

install(FILES     ${CMAKE_CURRENT_SOURCE_DIR}/athena-128.png DESTINATION share/athena-latex-ide RENAME logo.png)
install(FILES     ${CMAKE_CURRENT_SOURCE_DIR}/athena.css     DESTINATION share/athena-latex-ide                )
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/assistant      DESTINATION share/athena-latex-ide                )

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/athena-latex-ide.desktop DESTINATION share/applications)


# OSX packaging

set(PACKAGE_OUTPUT_DIR ${CMAKE_BINARY_DIR}/build/${CORE_BUILD_CONFIG})

configure_file(${CORE_SOURCE_DIR}/xbmc/platform/darwin/osx/Info.plist.in
               ${CMAKE_BINARY_DIR}/xbmc/platform/darwin/osx/Info.plist @ONLY)
execute_process(COMMAND perl -p -i -e "s/r####/${APP_SCMID}/" ${CMAKE_BINARY_DIR}/xbmc/platform/darwin/osx/Info.plist)

add_custom_target(bundle
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${APP_NAME_LC}> ${PACKAGE_OUTPUT_DIR}/${APP_NAME}
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/${CORE_BUILD_DIR}/DllPaths_generated.h
                                     ${CMAKE_BINARY_DIR}/xbmc/DllPaths_generated.h
    COMMAND "ACTION=build"
            "TARGET_BUILD_DIR=${PACKAGE_OUTPUT_DIR}"
            "TARGET_NAME=${APP_NAME}.app"
            "APP_NAME=${APP_NAME}"
            "SRCROOT=${CMAKE_BINARY_DIR}"
            ${CORE_SOURCE_DIR}/tools/darwin/Support/CopyRootFiles-osx.command
    COMMAND "XBMC_DEPENDS=${DEPENDS_PATH}"
            "TARGET_BUILD_DIR=${PACKAGE_OUTPUT_DIR}"
            "TARGET_NAME=${APP_NAME}.app"
            "APP_NAME=${APP_NAME}"
            "FULL_PRODUCT_NAME=${APP_NAME}.app"
            "SRCROOT=${CMAKE_BINARY_DIR}"
            ${CORE_SOURCE_DIR}/tools/darwin/Support/copyframeworks-osx.command)
add_dependencies(bundle ${APP_NAME_LC} export-files pack-skins wrap-libraries generate_json_header XBMCHelper)

configure_file(${CORE_SOURCE_DIR}/tools/darwin/packaging/osx/mkdmg-osx.sh.in
               ${CMAKE_BINARY_DIR}/tools/darwin/packaging/osx/mkdmg-osx.sh @ONLY)

add_custom_target(dmg
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CORE_SOURCE_DIR}/tools/darwin/packaging/osx/
                                               ${CMAKE_BINARY_DIR}/tools/darwin/packaging/osx/
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CORE_SOURCE_DIR}/tools/darwin/packaging/media/osx/
                                               ${CMAKE_BINARY_DIR}/tools/darwin/packaging/media/osx/
    COMMAND ./mkdmg-osx.sh ${CORE_BUILD_CONFIG}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/tools/darwin/packaging/osx)
add_dependencies(dmg bundle)

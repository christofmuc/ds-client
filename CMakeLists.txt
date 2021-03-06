cmake_minimum_required(VERSION 3.16.0)

#set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/vcpkg/scripts/buildsystems/vcpkg.cmake CACHE STRING "Vcpkg toolchain file")

## GLOBAL CONFIGURATION
project(DigitalStage LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_PROJECT_VERSION_MAJOR "0")
set(CMAKE_PROJECT_VERSION_MINOR "1")
set(CMAKE_PROJECT_VERSION_PATCH "0")


add_compile_definitions(STAGE_URL="https://single.dstage.org")
add_compile_definitions(AUTH_SERVER="https://single.dstage.org/api/auth")
add_compile_definitions(API_SERVER="wss://single.dstage.org/api/endpoint/")


# Excude js files inside the libs folder
set_property(SOURCE "ov-client/webmixer.js" PROPERTY SKIP_AUTOMOC ON)
set_property(SOURCE "ov-client/webmixer.js" PROPERTY SKIP_AUTOUIC ON)

if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    if (CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
        # Check whether we are running under Rosetta on arm64 hardware.
        execute_process(COMMAND sysctl -q hw.optional.arm64
                OUTPUT_VARIABLE _sysctl_stdout
                ERROR_VARIABLE _sysctl_stderr
                RESULT_VARIABLE _sysctl_result
                )
        if (_sysctl_result EQUAL 0 AND _sysctl_stdout MATCHES "hw.optional.arm64: 1")
            message("Compiling multi build for x84_64 and arm64")
            #set(CMAKE_HOST_SYSTEM_PROCESSOR "arm64")
            # Not possible right now with qt6
            #set(CMAKE_OSX_ARCHITECTURES arm64 x86_64)
            # set(CMAKE_CROSSCOMPILING false)
            #set(QMAKE_APPLE_DEVICE_ARCHS arm64)
            set(CMAKE_OSX_ARCHITECTURES arm64)
            #set(CMAKE_OSX_ARCHITECTURES x86_64)
        else ()
            set(CMAKE_OSX_ARCHITECTURES x86_64)
        endif ()
    endif ()
endif ()


## DEPENDENCIES
if (APPLE)
    find_program(BREW brew)
    # only if OPENSSL_ROOT_DIR is not set yet
    if (BREW AND NOT OPENSSL_ROOT_DIR AND NOT "$ENV{OPENSSL_ROOT_DIR}")
        execute_process(COMMAND ${BREW} --prefix openssl
                OUTPUT_VARIABLE BREW_OPENSSL_PREFIX
                RESULT_VARIABLE BREW_OPENSSL_RESULT
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
                )
        if (BREW_OPENSSL_RESULT EQUAL 0)
            message(STATUS "Set OPENSSL_ROOT_DIR=${BREW_OPENSSL_PREFIX} (from brew)")
            set(OPENSSL_ROOT_DIR "${BREW_OPENSSL_PREFIX}" CACHE PATH "")
        endif()
    endif()
endif()
#find_package(QT NAMES Qt6 Qt5 COMPONENTS Widgets LinguistTools REQUIRED)
find_package(QT NAMES Qt5 COMPONENTS Widgets LinguistTools REQUIRED)
find_package(Qt${QT_VERSION_MAJOR} COMPONENTS Widgets LinguistTools REQUIRED)
find_package(Qt5Keychain REQUIRED)
find_package(cpprestsdk REQUIRED)

# DEPENDENCIES
set(PLUGINPREFIX "ovclient")
add_subdirectory(libov)
list(APPEND RECEIVERS
        ortf
        hrtf
        simplefdn
        omni
        )
list(APPEND TASCARMODS
        system
        touchosc
        waitforjackport
        route
        jackrec
        )
list(APPEND SOURCEMODS
        omni
        cardioidmod
        )
list(APPEND AUDIOPLUGINS
        sndfile
        delay
        metronome
        )
add_subdirectory(libov/tascar/plugins ${PROJECT_BINARY_DIR}/plugins)
get_property(TASCAR_PLUGIN_LIBRARIES GLOBAL PROPERTY TASCAR_PLUGIN_LIBRARIES)
add_subdirectory(zita-njbridge ${PROJECT_BINARY_DIR}/zita)


## SOURCE AND RESOURCE CONTROL
# Language generation
set(TS_FILES i18n/DigitalStage_de.ts)

set(PROJECT_SOURCES
        src/main.cpp
        src/logindialog.cpp
        src/logindialog.h
        src/logindialog.ui
        src/api/auth.h
        src/api/auth.cpp
        src/api/keystore.h
        src/api/keystore.cpp
        src/app.h
        src/app.cpp
        resources.qrc
        ${TS_FILES}
        )

file(GLOB
        PROJECT_ASSETS
        ${CMAKE_CURRENT_SOURCE_DIR}/i18n/*.qm
        ${CMAKE_CURRENT_SOURCE_DIR}/images/*.png
        ${CMAKE_CURRENT_SOURCE_DIR}/images/*.svg
        )

set(PROJECT_RESOURCES
        resources.qrc
        ${PROJECT_ASSETS}
        )


## APPLE SPECIFIC
if (APPLE)
    # Add app icon
    set(MACOSX_BUNDLE_ICON_FILE appicon.icns)
    set(APP_ICON ${CMAKE_CURRENT_SOURCE_DIR}/images/appicon.icns)
    set_source_files_properties(${APP_ICON} PROPERTIES
            MACOSX_PACKAGE_LOCATION "Resources")
endif ()


## EXECUTABLE
if (${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    message("Building with QT6")
    qt_add_executable(DigitalStage
            ${PROJECT_SOURCES} ${PROJECT_RESOURCES} ${APP_ICON}
            )
    qt_create_translation(QM_FILES ${CMAKE_SOURCE_DIR} ${TS_FILES})
else ()
    message("Building with QT5")
    if (ANDROID)
        add_library(DigitalStage SHARED
                ${PROJECT_SOURCES} ${PROJECT_RESOURCES} ${APP_ICON}
                )
    else ()
        add_executable(DigitalStage ${PROJECT_SOURCES} ${PROJECT_RESOURCES} ${APP_ICON})
        if (APPLE)
            set_target_properties(DigitalStage PROPERTIES
                    MACOSX_BUNDLE TRUE
                    MACOSX_FRAMEWORK_IDENTIFIER org.cmake.ExecutableTarget
                    RESOURCE "${PROJECT_RESOURCES}"
                    )
        endif ()
    endif ()
    qt5_create_translation(QM_FILES ${CMAKE_SOURCE_DIR} ${TS_FILES})
endif ()

target_include_directories(DigitalStage
        PRIVATE
        libov/src
        )

target_link_libraries(DigitalStage
        PRIVATE
        Qt${QT_VERSION_MAJOR}::Widgets
        qt5keychain
        cpprestsdk::cpprest
        OpenSSL::Crypto
        ov
        PUBLIC
        ${TASCAR_PLUGIN_LIBRARIES}
        )

if (CMAKE_BUILD_TYPE MATCHES Release)
    message("Deploying application...")

    include(InstallRequiredSystemLibraries)
    set(CPACK_PACKAGE_NAME "DigitalStage")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Native client for Digital Stage")
    set(CPACK_PACKAGE_VENDOR "Digital Stage gGmbH")
    set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/ReadMe.txt")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/Copyright.txt")
    set(CPACK_PACKAGE_VERSION_MAJOR ${CMAKE_PROJECT_VERSION_MAJOR})
    set(CPACK_PACKAGE_VERSION_MINOR ${CMAKE_PROJECT_VERSION_MINOR})
    set(CPACK_PACKAGE_VERSION_PATCH ${CMAKE_PROJECT_VERSION_PATCH})
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "CMake ${CMake_VERSION_MAJOR}.${CMake_VERSION_MINOR}")
    set(CPACK_NSIS_CONTACT "info@digital-stage.com")
    set(CPACK_PACKAGE_EXECUTABLES "DigitalStage" "Digital Stage")


    if (WIN32 AND NOT UNIX)
        find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
        add_custom_command(TARGET DigitalStage POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -E
                env PATH="${_qt_bin_dir}" "${WINDEPLOYQT_EXECUTABLE}"
                "$<TARGET_FILE:DigitalStage>"
                COMMENT "Running windeployqt..."
                )
        set(CPACK_GENERATOR "NSIS")
        set(CPACK_PACKAGE_ICON "${CMake_SOURCE_DIR}/images\\\\appicon.bmp")
        set(CPACK_NSIS_INSTALLED_ICON_NAME "bin\\\\DigitalStage.exe")
        set(CPACK_NSIS_DISPLAY_NAME "${CPACK_PACKAGE_INSTALL_DIRECTORY} Digital Stage")
        set(CPACK_NSIS_HELP_LINK "http:\\\\\\\\www.digital-stage.org")
        set(CPACK_NSIS_URL_INFO_ABOUT "http:\\\\\\\\www.digital-stage.com")
        set(CPACK_NSIS_MODIFY_PATH ON)
    endif ()

    if (APPLE)
        find_program(MACDEPLOYQT_EXECUTABLE macdeployqt HINTS "${_qt_bin_dir}")
        set_target_properties(DigitalStage PROPERTIES
                MACOSX_BUNDLE TRUE
                MACOSX_FRAMEWORK_IDENTIFIER org.digital-stage.client
                RESOURCE "${PROJECT_RESOURCES}")
        install(DIRECTORY "${PROJECT_BINARY_DIR}/DigitalStage.app"
                DESTINATION "."
                USE_SOURCE_PERMISSIONS)
        add_custom_command(TARGET DigitalStage POST_BUILD
                #COMMAND ${CMAKE_COMMAND} -E copy
                #        ${CMAKE_BINARY_DIR}/plugins/*.dylib
                #        ${CMAKE_BINARY_DIR}/DigitalStage.app/Contents/libs/
                COMMAND "${MACDEPLOYQT_EXECUTABLE}"
                "$<TARGET_FILE_DIR:DigitalStage>/../.."
                -always-overwrite
                COMMENT "Running macdeployqt..."
                )
        set(CPACK_BUNDLE_APPLE_CERT_APP "")
        set(CPACK_GENERATOR "DragNDrop")
        set(CPACK_DMG_VOLUME_NAME "InstallDigitalStage")
        #set(CPACK_STRIP_FILES "${CMAKE_BINARY_DIR}/DigitalStage.app")
        set(CPACK_SOURCE_STRIP_FILES "")
        set(CPACK_DMG_DS_STORE_SETUP_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/Packaging_DMGSetup.scpt)
        set(CPACK_DMG_BACKGROUND_IMAGE ${CMAKE_CURRENT_SOURCE_DIR}/images/DMGBackground.tif)
        #set(CPACK_COMPONENTS_ALL "${CMAKE_BINARY_DIR}/DigitalStage.app")
    endif ()

    include(CPack)
else ()
    message("Not deploying application, set CMAKE_BUILD_TYPE to Release to deploy.")
endif ()

## VERBOSE
message("CMAKE_OSX_ARCHITECTURES: ${CMAKE_OSX_ARCHITECTURES}")
message("CMAKE_HOST_SYSTEM_PROCESSOR: ${CMAKE_HOST_SYSTEM_PROCESSOR}")
message("CMAKE_SYSTEM_PROCESSOR: ${CMAKE_SYSTEM_PROCESSOR}")
message("CMAKE_CROSSCOMPILING: ${CMAKE_CROSSCOMPILING}")


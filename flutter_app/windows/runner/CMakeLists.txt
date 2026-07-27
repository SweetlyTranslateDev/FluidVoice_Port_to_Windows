cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
set(FLUIDVOICE_OVERLAY_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../native_plugins/overlay_window/cpp")
set(FLUIDVOICE_TRAY_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../native_plugins/tray_host/cpp")
set(FLUIDVOICE_AUTOSTART_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../native_plugins/autostart/cpp")
set(FLUIDVOICE_CREDENTIALS_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../native_plugins/credentials/cpp")
set(FLUIDVOICE_WINDOW_CHROME_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../native_plugins/window_chrome/cpp")

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
  "${FLUIDVOICE_OVERLAY_DIR}/overlay_window.cpp"
  "${FLUIDVOICE_OVERLAY_DIR}/overlay_plugin.cpp"
  "${FLUIDVOICE_TRAY_DIR}/tray_icon.cpp"
  "${FLUIDVOICE_TRAY_DIR}/tray_plugin.cpp"
  "${FLUIDVOICE_AUTOSTART_DIR}/autostart_plugin.cpp"
  "${FLUIDVOICE_CREDENTIALS_DIR}/credentials_plugin.cpp"
  "${FLUIDVOICE_WINDOW_CHROME_DIR}/window_chrome_plugin.cpp"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app flutter_wrapper_plugin)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "shell32.lib" "Advapi32.lib")
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}"
  "${FLUIDVOICE_OVERLAY_DIR}"
  "${FLUIDVOICE_TRAY_DIR}"
  "${FLUIDVOICE_AUTOSTART_DIR}"
  "${FLUIDVOICE_CREDENTIALS_DIR}"
  "${FLUIDVOICE_WINDOW_CHROME_DIR}"
)

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

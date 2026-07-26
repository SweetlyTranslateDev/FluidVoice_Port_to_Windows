cmake_minimum_required(VERSION 3.14)
project(fluidvoice_hotkeys LANGUAGES CXX)

add_library(fluidvoice_hotkeys SHARED
  hotkey_hook.cpp
  fv_hotkey_api.cpp
)

target_include_directories(fluidvoice_hotkeys
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../plugin_api/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_features(fluidvoice_hotkeys PUBLIC cxx_std_17)
target_compile_definitions(fluidvoice_hotkeys PRIVATE
  FLUIDVOICE_PLUGIN_EXPORTS
  UNICODE
  _UNICODE
)

target_link_libraries(fluidvoice_hotkeys PRIVATE user32)

set_target_properties(fluidvoice_hotkeys PROPERTIES
  OUTPUT_NAME "fluidvoice_hotkeys"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

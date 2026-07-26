cmake_minimum_required(VERSION 3.14)
project(fluidvoice_inject LANGUAGES CXX)

add_library(fluidvoice_inject SHARED
  text_injector.cpp
  fv_inject_api.cpp
)

target_include_directories(fluidvoice_inject
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../plugin_api/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_features(fluidvoice_inject PUBLIC cxx_std_17)
target_compile_definitions(fluidvoice_inject PRIVATE
  FLUIDVOICE_PLUGIN_EXPORTS
  UNICODE
  _UNICODE
)

target_link_libraries(fluidvoice_inject PRIVATE
  user32
  ole32
  oleaut32
  uiautomationcore
)

set_target_properties(fluidvoice_inject PROPERTIES
  OUTPUT_NAME "fluidvoice_inject"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

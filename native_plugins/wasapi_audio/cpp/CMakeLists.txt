cmake_minimum_required(VERSION 3.14)
project(fluidvoice_wasapi LANGUAGES CXX)

add_library(fluidvoice_wasapi SHARED
  ring_buffer.cpp
  wasapi_capture.cpp
  device_enumerator.cpp
  audio_resample.cpp
  audio_engine.cpp
  fv_audio_api.cpp
)

target_include_directories(fluidvoice_wasapi
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../plugin_api/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_features(fluidvoice_wasapi PUBLIC cxx_std_17)
target_compile_definitions(fluidvoice_wasapi PRIVATE FLUIDVOICE_PLUGIN_EXPORTS UNICODE _UNICODE)

target_link_libraries(fluidvoice_wasapi PRIVATE
  ole32
  uuid
  avrt
  winmm
)

set_target_properties(fluidvoice_wasapi PROPERTIES
  OUTPUT_NAME "fluidvoice_wasapi"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

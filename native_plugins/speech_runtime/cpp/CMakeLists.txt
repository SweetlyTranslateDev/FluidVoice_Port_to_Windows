cmake_minimum_required(VERSION 3.14)
project(fluidvoice_speech LANGUAGES C CXX)

include(FetchContent)

set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_CURL OFF CACHE BOOL "" FORCE)

# Honor BUILD_SHARED_LIBS inside whisper.cpp / ggml.
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW CACHE STRING "" FORCE)

# Prefer static ggml/whisper inside fluidvoice_speech.dll.
set(_fv_saved_build_shared_libs "${BUILD_SHARED_LIBS}")
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)

FetchContent_Declare(
  whispercpp
  GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
  GIT_TAG v1.7.5
  GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(whispercpp)

# Restore shared-lib preference for the rest of the Flutter Windows tree.
if(_fv_saved_build_shared_libs STREQUAL "")
  set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries" FORCE)
else()
  set(BUILD_SHARED_LIBS "${_fv_saved_build_shared_libs}" CACHE BOOL "Build shared libraries" FORCE)
endif()
unset(_fv_saved_build_shared_libs)

add_library(fluidvoice_speech SHARED
  speech_engine.cpp
  fv_speech_api.cpp
)

target_include_directories(fluidvoice_speech
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../plugin_api/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${whispercpp_SOURCE_DIR}/include
    ${whispercpp_SOURCE_DIR}
)

target_compile_features(fluidvoice_speech PUBLIC cxx_std_17)
target_compile_definitions(fluidvoice_speech PRIVATE
  FLUIDVOICE_PLUGIN_EXPORTS
  UNICODE
  _UNICODE
)

target_link_libraries(fluidvoice_speech PRIVATE whisper)

set_target_properties(fluidvoice_speech PROPERTIES
  OUTPUT_NAME "fluidvoice_speech"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# CMake regenerates whisper's cmake_install.cmake at generate-time; overwrite
# it after every speech build so the Flutter INSTALL step does not run those rules.
add_custom_command(TARGET fluidvoice_speech POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake_install_stub.cmake"
    "${whispercpp_BINARY_DIR}/cmake_install.cmake"
  COMMENT "Neutralize whisper.cpp install rules for Flutter bundle"
)

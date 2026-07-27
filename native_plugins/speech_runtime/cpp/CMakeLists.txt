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

# --- sherpa-onnx (Parakeet) prebuilt Windows x64 MD Release ---
set(FV_SHERPA_VERSION "v1.12.23")
set(FV_SHERPA_PACKAGE
  "sherpa-onnx-${FV_SHERPA_VERSION}-win-x64-shared-MD-Release-no-tts")
set(FV_SHERPA_URL
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/${FV_SHERPA_VERSION}/${FV_SHERPA_PACKAGE}.tar.bz2")
set(FV_SHERPA_ROOT "${CMAKE_BINARY_DIR}/_deps/sherpa-onnx-prebuilt")
set(FV_SHERPA_DIR "${FV_SHERPA_ROOT}/${FV_SHERPA_PACKAGE}")
set(FV_SHERPA_ARCHIVE "${FV_SHERPA_ROOT}/${FV_SHERPA_PACKAGE}.tar.bz2")

if(NOT EXISTS "${FV_SHERPA_DIR}/lib/sherpa-onnx-c-api.lib")
  file(MAKE_DIRECTORY "${FV_SHERPA_ROOT}")
  message(STATUS "Downloading sherpa-onnx prebuilt: ${FV_SHERPA_URL}")
  file(DOWNLOAD "${FV_SHERPA_URL}" "${FV_SHERPA_ARCHIVE}"
    SHOW_PROGRESS
    STATUS _fv_sherpa_dl_status
    TLS_VERIFY ON)
  list(GET _fv_sherpa_dl_status 0 _fv_sherpa_dl_code)
  if(NOT _fv_sherpa_dl_code EQUAL 0)
    list(GET _fv_sherpa_dl_status 1 _fv_sherpa_dl_msg)
    message(FATAL_ERROR "Failed to download sherpa-onnx: ${_fv_sherpa_dl_msg}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xjf "${FV_SHERPA_ARCHIVE}"
    WORKING_DIRECTORY "${FV_SHERPA_ROOT}"
    RESULT_VARIABLE _fv_sherpa_extract_rc
  )
  if(NOT _fv_sherpa_extract_rc EQUAL 0)
    message(FATAL_ERROR "Failed to extract sherpa-onnx archive")
  endif()
endif()

if(NOT EXISTS "${FV_SHERPA_DIR}/lib/sherpa-onnx-c-api.lib")
  message(FATAL_ERROR "sherpa-onnx prebuilt missing at ${FV_SHERPA_DIR}")
endif()

add_library(sherpa_onnx_c_api SHARED IMPORTED GLOBAL)
set_target_properties(sherpa_onnx_c_api PROPERTIES
  IMPORTED_IMPLIB "${FV_SHERPA_DIR}/lib/sherpa-onnx-c-api.lib"
  IMPORTED_LOCATION "${FV_SHERPA_DIR}/lib/sherpa-onnx-c-api.dll"
  INTERFACE_INCLUDE_DIRECTORIES "${FV_SHERPA_DIR}/include"
)

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
    "${FV_SHERPA_DIR}/include"
)

target_compile_features(fluidvoice_speech PUBLIC cxx_std_17)
target_compile_definitions(fluidvoice_speech PRIVATE
  FLUIDVOICE_PLUGIN_EXPORTS
  UNICODE
  _UNICODE
)

# Exceptions required by filesystem / sherpa headers on MSVC.
if(MSVC)
  target_compile_options(fluidvoice_speech PRIVATE /EHsc)
  target_compile_definitions(fluidvoice_speech PRIVATE _HAS_EXCEPTIONS=1)
endif()

target_link_libraries(fluidvoice_speech PRIVATE whisper sherpa_onnx_c_api)

set_target_properties(fluidvoice_speech PROPERTIES
  OUTPUT_NAME "fluidvoice_speech"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# Expose sherpa DLL dir for the Flutter install step.
set(FV_SHERPA_LIB_DIR "${FV_SHERPA_DIR}/lib" CACHE INTERNAL "sherpa-onnx lib dir")

# CMake regenerates whisper's cmake_install.cmake at generate-time; overwrite
# it after every speech build so the Flutter INSTALL step does not run those rules.
add_custom_command(TARGET fluidvoice_speech POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake_install_stub.cmake"
    "${whispercpp_BINARY_DIR}/cmake_install.cmake"
  COMMENT "Neutralize whisper.cpp install rules for Flutter bundle"
)

# Copy sherpa/onnxruntime DLLs next to fluidvoice_speech.dll after build.
add_custom_command(TARGET fluidvoice_speech POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FV_SHERPA_DIR}/lib/sherpa-onnx-c-api.dll"
    "$<TARGET_FILE_DIR:fluidvoice_speech>/sherpa-onnx-c-api.dll"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FV_SHERPA_DIR}/lib/onnxruntime.dll"
    "$<TARGET_FILE_DIR:fluidvoice_speech>/onnxruntime.dll"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FV_SHERPA_DIR}/lib/onnxruntime_providers_shared.dll"
    "$<TARGET_FILE_DIR:fluidvoice_speech>/onnxruntime_providers_shared.dll"
  COMMENT "Copy sherpa-onnx / onnxruntime DLLs beside fluidvoice_speech"
)

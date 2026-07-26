# FluidVoice: whisper.cpp nested install rules are intentionally skipped.
# Flutter's CMAKE_INSTALL_PREFIX is a generator expression; whisper's
# file(INSTALL) rules cannot evaluate it and break the Windows bundle step.
# Runtime DLLs are installed via flutter_app/windows/CMakeLists.txt.

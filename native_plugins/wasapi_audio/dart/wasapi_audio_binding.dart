/// FFI binding stub for wasapi_audio.
///
/// Phase 0 does not load a native library. Phase 1 will `DynamicLibrary.open`
/// the built DLL and wire [AudioCapture].
class WasapiAudioBinding {
  const WasapiAudioBinding();

  bool get isAvailable => false;

  Never _nyi() =>
      throw UnimplementedError('wasapi_audio FFI not linked (Phase 1)');

  void init() => _nyi();

  void start() => _nyi();

  void stop() => _nyi();
}

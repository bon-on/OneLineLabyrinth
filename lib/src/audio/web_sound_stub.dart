/// Non-web builds play sounds through the native shell audio channel.
class WebSound {
  void play(String assetKey, double volume) {}

  /// Starts [assetKey] on repeat. The stub never plays.
  Future<bool> loop(String assetKey, double volume) async => false;

  void pauseLoop() {}

  Future<bool> resumeLoop() async => false;

  void stopLoop() {}
}

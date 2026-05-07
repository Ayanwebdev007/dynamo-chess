import 'package:audioplayers/audioplayers.dart';
import 'settings_controller.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Create separate players for overlapping sounds
  final AudioPlayer _movePlayer = AudioPlayer();
  final AudioPlayer _capturePlayer = AudioPlayer();
  final AudioPlayer _checkPlayer = AudioPlayer();
  final AudioPlayer _gameOverPlayer = AudioPlayer();

  bool _initialized = false;
  final SettingsController _settings = SettingsController();

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Pre-load assets
      await _movePlayer.setSource(AssetSource('sounds/move.mp3'));
      await _capturePlayer.setSource(AssetSource('sounds/capture.mp3'));
      await _checkPlayer.setSource(AssetSource('sounds/check.mp3'));
      await _gameOverPlayer.setSource(AssetSource('sounds/game_over.mp3'));
      
      _initialized = true;
    } catch (e) {
      print('AudioService init error: $e');
    }
  }

  void playMove() async {
    if (!_settings.isSoundEnabled) return;
    try {
      await _movePlayer.stop();
      await _movePlayer.play(AssetSource('sounds/move.mp3'));
    } catch (e) {
      print('playMove error: $e');
    }
  }

  void playCapture() async {
    if (!_settings.isSoundEnabled) return;
    try {
      await _capturePlayer.stop();
      await _capturePlayer.play(AssetSource('sounds/capture.mp3'));
    } catch (e) {
      print('playCapture error: $e');
    }
  }

  void playCheck() async {
    if (!_settings.isSoundEnabled) return;
    try {
      await _checkPlayer.stop();
      await _checkPlayer.play(AssetSource('sounds/check.mp3'));
    } catch (e) {
      print('playCheck error: $e');
    }
  }

  void playGameOver() async {
    if (!_settings.isSoundEnabled) return;
    try {
      await _gameOverPlayer.stop();
      await _gameOverPlayer.play(AssetSource('sounds/game_over.mp3'));
    } catch (e) {
      print('playGameOver error: $e');
    }
  }

  void playChallenge() async {
    if (!_settings.isSoundEnabled) return;
    try {
      await _checkPlayer.stop();
      await _checkPlayer.play(AssetSource('sounds/check.mp3'));
    } catch (e) {
      print('playChallenge error: $e');
    }
  }

  void stopAmbient() {}
}

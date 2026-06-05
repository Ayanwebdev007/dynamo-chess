import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static final SettingsController _instance = SettingsController._internal();
  factory SettingsController() => _instance;
  SettingsController._internal();

  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyShowLegalMoves = 'show_legal_moves';
  static const String _keyShowLastMove = 'show_last_move';
  static const String _keyShowCoordinates = 'show_coordinates';
  static const String _keyBoardTheme = 'board_theme';
  
  SharedPreferences? _prefs;
  bool _isSoundEnabled = true;
  bool _showLegalMoves = true;
  bool _showLastMove = true;
  bool _showCoordinates = true;
  String _boardTheme = 'classic'; // 'classic', 'onyx', 'wood', 'emerald'

  bool get isSoundEnabled => _isSoundEnabled;
  bool get showLegalMoves => _showLegalMoves;
  bool get showLastMove => _showLastMove;
  bool get showCoordinates => _showCoordinates;
  String get boardTheme => _boardTheme;

  /// Initialize the controller and load settings from disk.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isSoundEnabled = _prefs?.getBool(_keySoundEnabled) ?? true;
      _showLegalMoves = _prefs?.getBool(_keyShowLegalMoves) ?? true;
      _showLastMove = _prefs?.getBool(_keyShowLastMove) ?? true;
      _showCoordinates = _prefs?.getBool(_keyShowCoordinates) ?? true;
      _boardTheme = _prefs?.getString(_keyBoardTheme) ?? 'classic';
    } catch (e) {
      debugPrint('SettingsController: SharedPreferences not available: $e');
    }
    notifyListeners();
  }

  /// Toggle sound effects on/off and persist the choice.
  Future<void> toggleSound(bool value) async {
    _isSoundEnabled = value;
    await _prefs?.setBool(_keySoundEnabled, value);
    notifyListeners();
  }

  Future<void> toggleLegalMoves(bool value) async {
    _showLegalMoves = value;
    await _prefs?.setBool(_keyShowLegalMoves, value);
    notifyListeners();
  }

  Future<void> toggleLastMove(bool value) async {
    _showLastMove = value;
    await _prefs?.setBool(_keyShowLastMove, value);
    notifyListeners();
  }

  Future<void> toggleCoordinates(bool value) async {
    _showCoordinates = value;
    await _prefs?.setBool(_keyShowCoordinates, value);
    notifyListeners();
  }

  Future<void> setBoardTheme(String theme) async {
    _boardTheme = theme;
    await _prefs?.setString(_keyBoardTheme, theme);
    notifyListeners();
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class SavedPuzzlesService {
  static const String _storageKey = 'saved_puzzle_ids';

  Future<Set<String>> getSavedPuzzleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_storageKey) ?? [];
    return list.toSet();
  }

  Future<bool> isPuzzleSaved(String puzzleId) async {
    final saved = await getSavedPuzzleIds();
    return saved.contains(puzzleId);
  }

  Future<bool> toggleSavePuzzle(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await getSavedPuzzleIds();
    bool isNowSaved = false;
    if (saved.contains(puzzleId)) {
      saved.remove(puzzleId);
      isNowSaved = false;
    } else {
      saved.add(puzzleId);
      isNowSaved = true;
    }
    await prefs.setStringList(_storageKey, saved.toList());
    return isNowSaved;
  }
}

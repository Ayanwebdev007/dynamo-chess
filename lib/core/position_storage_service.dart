import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class SavedPosition {
  final String id;
  final String title;
  final String fen;
  final String createdAt;

  SavedPosition({
    required this.id,
    required this.title,
    required this.fen,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fen': fen,
        'createdAt': createdAt,
      };

  factory SavedPosition.fromJson(Map<String, dynamic> json) {
    return SavedPosition(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Saved Position',
      fen: json['fen'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class PositionStorageService {
  static const String _storageKey = 'dynamo_saved_positions';

  Future<List<SavedPosition>> getSavedPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_storageKey);
    if (rawJson == null || rawJson.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(rawJson);
      return decoded
          .map((item) => SavedPosition.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> savePosition(String title, String fen) async {
    final prefs = await SharedPreferences.getInstance();
    final positions = await getSavedPositions();

    final newPosition = SavedPosition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Position ${positions.length + 1}' : title.trim(),
      fen: fen,
      createdAt: DateTime.now().toIso8601String().split('T').first,
    );

    positions.insert(0, newPosition);
    final String encoded = jsonEncode(positions.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> deletePosition(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final positions = await getSavedPositions();
    positions.removeWhere((p) => p.id == id);
    final String encoded = jsonEncode(positions.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

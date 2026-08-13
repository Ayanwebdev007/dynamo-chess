import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'models.dart';

class PuzzleMove {
  final Position start;
  final Position end;
  final PieceType? promotionPiece;

  PuzzleMove({
    required this.start,
    required this.end,
    this.promotionPiece,
  });

  Map<String, dynamic> toJson() => {
        'startX': start.x,
        'startY': start.y,
        'endX': end.x,
        'endY': end.y,
        if (promotionPiece != null) 'promotionPiece': promotionPiece!.name,
      };

  factory PuzzleMove.fromJson(Map<dynamic, dynamic> json) {
    PieceType? promo;
    if (json['promotionPiece'] != null) {
      promo = PieceType.values.firstWhere(
        (e) => e.name == json['promotionPiece'],
        orElse: () => PieceType.queen,
      );
    }
    return PuzzleMove(
      start: Position(json['startX'] as int, json['startY'] as int),
      end: Position(json['endX'] as int, json['endY'] as int),
      promotionPiece: promo,
    );
  }
}

class Puzzle {
  final String id;
  final String title;
  final String description;
  final String initialFen;
  final int movesToWin;
  final PlayerColor startTurn;
  final List<PuzzleMove> solutionMoves;
  final List<List<PuzzleMove>> alternativeSolutions;
  final PuzzleMove? previousMove;

  Puzzle({
    required this.id,
    required this.title,
    required this.description,
    required this.initialFen,
    required this.movesToWin,
    required this.startTurn,
    required this.solutionMoves,
    this.alternativeSolutions = const [],
    this.previousMove,
  });

  List<List<PuzzleMove>> get allSolutions => [solutionMoves, ...alternativeSolutions];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'initialFen': initialFen,
        'movesToWin': movesToWin,
        'startTurn': startTurn == PlayerColor.white ? 'white' : 'black',
        'solutionMoves': solutionMoves.map((m) => m.toJson()).toList(),
        if (alternativeSolutions.isNotEmpty)
          'alternativeSolutions': alternativeSolutions
              .map((line) => line.map((m) => m.toJson()).toList())
              .toList(),
        if (previousMove != null) 'previousMove': previousMove!.toJson(),
      };

  factory Puzzle.fromJson(Map<dynamic, dynamic> json) {
    final list = json['solutionMoves'] as List<dynamic>? ?? [];
    final altList = json['alternativeSolutions'] as List<dynamic>? ?? [];
    PuzzleMove? prevMove;
    if (json['previousMove'] != null) {
      prevMove = PuzzleMove.fromJson(Map<dynamic, dynamic>.from(json['previousMove'] as Map));
    }

    return Puzzle(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      initialFen: json['initialFen'] as String? ?? '',
      movesToWin: json['movesToWin'] as int? ?? 1,
      startTurn: (json['startTurn'] as String? ?? 'white') == 'white'
          ? PlayerColor.white
          : PlayerColor.black,
      solutionMoves: list
          .map((m) => PuzzleMove.fromJson(Map<dynamic, dynamic>.from(m as Map)))
          .toList(),
      alternativeSolutions: altList.map((line) {
        final moves = line as List<dynamic>? ?? [];
        return moves
            .map((m) => PuzzleMove.fromJson(Map<dynamic, dynamic>.from(m as Map)))
            .toList();
      }).toList(),
      previousMove: prevMove,
    );
  }
}

class PuzzleService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Stream<List<Puzzle>> streamPuzzles() {
    return _db.child('puzzles').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <Puzzle>[];
      data.forEach((key, value) {
        list.add(Puzzle.fromJson(Map<dynamic, dynamic>.from(value as Map)));
      });
      return list;
    });
  }

  Future<void> savePuzzle(Puzzle puzzle) async {
    await _db.child('puzzles').child(puzzle.id).set(puzzle.toJson());
  }

  Future<void> deletePuzzle(String id) async {
    await _db.child('puzzles').child(id).remove();
  }

  String generatePuzzleId() {
    return _db.child('puzzles').push().key ??
        DateTime.now().millisecondsSinceEpoch.toString();
  }
}

import 'dart:async';
import 'dart:math';
// Custom simple test helpers to run without flutter_test dependency
void group(String name, void Function() body) {
  print("Group: $name");
  body();
}
void test(String name, FutureOr<void> Function() body) async {
  print("Test: $name");
  await body();
}
void expect(dynamic actual, dynamic matcher) {
  if (actual != matcher) {
    throw Exception("Expected: $matcher, but got: $actual");
  }
}
dynamic equals(dynamic val) => val;

// Copying necessary models and enums from tournament_models.dart and models.dart to make it self-contained
enum PlayerColor { white, black }

enum TournamentStatus { enrolling, active, completed, archived }

class TournamentParticipant {
  final String userId;
  final String name;
  final int rating;
  double score;
  double buchholz;
  List<String> opponents;
  List<PlayerColor?> colors;

  TournamentParticipant({
    required this.userId,
    required this.name,
    this.rating = 1500,
    this.score = 0.0,
    this.buchholz = 0.0,
    List<String>? opponents,
    List<PlayerColor?>? colors,
  }) : opponents = opponents ?? [],
       colors = colors ?? [];

  void recordResult(double points, String opponentId, PlayerColor color) {
    score += points;
    opponents.add(opponentId);
    colors.add(color);
  }
}

class TournamentMatch {
  final String id;
  final String whitePlayerId;
  final String blackPlayerId;
  final String? whitePlayerName;
  final String? blackPlayerName;
  double? whiteScore;
  double? blackScore;
  final bool isCompleted;
  final String? method;
  final DateTime startTime;

  TournamentMatch({
    required this.id,
    required this.whitePlayerId,
    required this.blackPlayerId,
    this.whitePlayerName,
    this.blackPlayerName,
    this.whiteScore,
    this.blackScore,
    this.isCompleted = false,
    this.method,
    required this.startTime,
  });
}

class TournamentRound {
  final int roundNumber;
  final List<TournamentMatch> matches;
  final bool isCompleted;

  TournamentRound({
    required this.roundNumber,
    required this.matches,
    this.isCompleted = false,
  });
}

class Tournament {
  final String id;
  final String title;
  final String description;
  final TournamentStatus status;
  final int totalRounds;
  final int currentRound;
  final List<TournamentParticipant> participants;
  final List<TournamentRound> rounds;
  final int prizePool;
  final DateTime? autoStartAt;
  final DateTime? scheduledStartAt;
  final DateTime? nextEventAt;
  final int? restTimerSetForRound;

  Tournament({
    required this.id,
    required this.title,
    required this.description,
    this.status = TournamentStatus.enrolling,
    required this.totalRounds,
    this.currentRound = 0,
    required this.participants,
    required this.rounds,
    this.prizePool = 0,
    this.autoStartAt,
    this.scheduledStartAt,
    this.nextEventAt,
    this.restTimerSetForRound,
  });
}

// Simple Mock Database for Simulation supporting nested paths
class MockDatabase {
  final Map<String, dynamic> _data = {};
  final List<String> eventLog = [];

  // Helper to split path into top-level key (collection/id) and nested keys
  List<String> _parsePath(String path) {
    final parts = path.split('/');
    if (parts.length < 2) return [path];
    return ["${parts[0]}/${parts[1]}", ...parts.sublist(2)];
  }

  dynamic get(String path) {
    final parsed = _parsePath(path);
    final topKey = parsed[0];
    if (!_data.containsKey(topKey)) return null;
    dynamic current = _data[topKey];
    for (int i = 1; i < parsed.length; i++) {
      if (current is Map) {
        current = current[parsed[i]];
      } else {
        return null;
      }
    }
    return current;
  }

  void set(String path, dynamic value) {
    final parsed = _parsePath(path);
    final topKey = parsed[0];
    if (parsed.length == 1) {
      _data[topKey] = _clone(value);
    } else {
      if (!_data.containsKey(topKey) || _data[topKey] is! Map) {
        _data[topKey] = <String, dynamic>{};
      }
      final existing = _data[topKey] as Map<String, dynamic>;
      _setNested(existing, parsed.sublist(1).join('/'), _clone(value));
    }
    eventLog.add("SET: $path -> $value");
  }

  void update(String path, Map<String, dynamic> updates) {
    final parsed = _parsePath(path);
    final topKey = parsed[0];
    if (!_data.containsKey(topKey) || _data[topKey] is! Map) {
      _data[topKey] = <String, dynamic>{};
    }
    final existing = _data[topKey] as Map<String, dynamic>;
    if (parsed.length == 1) {
      updates.forEach((key, val) {
        _setNested(existing, key, _clone(val));
      });
    } else {
      final subPath = parsed.sublist(1).join('/');
      updates.forEach((key, val) {
        _setNested(existing, "$subPath/$key", _clone(val));
      });
    }
    eventLog.add("UPDATE: $path -> $updates");
  }

  // Basic implementation of transaction
  Future<bool> runTransaction(String path, dynamic Function(dynamic) updateFn) async {
    final currentVal = get(path);
    final result = updateFn(_clone(currentVal));
    if (result == null) {
      // Abort
      return false;
    }
    set(path, result);
    eventLog.add("TRANSACTION COMMIT: $path -> $result");
    return true;
  }

  dynamic _clone(dynamic val) {
    if (val is Map) return Map<String, dynamic>.from(val.map((k, v) => MapEntry(k.toString(), _clone(v))));
    if (val is List) return List<dynamic>.from(val.map((e) => _clone(e)));
    return val;
  }

  void _setNested(Map<String, dynamic> map, String path, dynamic value) {
    final parts = path.split('/');
    Map<String, dynamic> current = map;
    for (int i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (current[part] == null || current[part] is! Map) {
        current[part] = <String, dynamic>{};
      }
      current = current[part] as Map<String, dynamic>;
    }
    current[parts.last] = value;
  }
}

// Simulated Client executing automation tick
class SimulatedClient {
  final String id;
  final MockDatabase db;
  final Set<String> _activeAutomations = {};
  final Set<String> _activeMatchResolutions = {};

  SimulatedClient(this.id, this.db);

  Map<dynamic, dynamic> _firebaseToMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) return Map<dynamic, dynamic>.from(value);
    if (value is List) {
      final map = <dynamic, dynamic>{};
      for (int i = 0; i < value.length; i++) {
        if (value[i] != null) {
          map[i.toString()] = value[i];
        }
      }
      return map;
    }
    return {};
  }

  List<dynamic> _safeList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is Map) return _firebaseToMap(value).values.toList();
    return [];
  }

  int _toInt(dynamic val, [int defaultValue = 0]) {
    if (val == null) return defaultValue;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  double _toDouble(dynamic val, [double defaultValue = 0.0]) {
    if (val == null) return defaultValue;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    final intValue = _toInt(val);
    if (intValue == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(intValue);
  }

  Tournament _parseTournament(String id, Map<dynamic, dynamic> data) {
    final List<TournamentParticipant> participants = [];
    final dynamic participantsRaw = data['participants'];
    if (participantsRaw != null) {
      final pMap = _firebaseToMap(participantsRaw);
      for (var entry in pMap.entries) {
        final dynamic val = entry.value;
        if (val != null && (val is Map || val is List)) {
          final v = _firebaseToMap(val);
          participants.add(TournamentParticipant(
            userId: entry.key.toString(),
            name: v['name']?.toString() ?? 'Unknown',
            rating: _toInt(v['rating'], 1200),
            score: _toDouble(v['score'], 0.0),
            buchholz: _toDouble(v['buchholz'], 0.0),
            opponents: _safeList(v['opponents']).map((e) => e.toString()).toList(),
            colors: _safeList(v['colors']).map<PlayerColor?>((c) {
              final s = c.toString();
              if (s == 'white') return PlayerColor.white;
              if (s == 'black') return PlayerColor.black;
              return null;
            }).toList(),
          ));
        }
      }
    }

    final List<TournamentRound> rounds = [];
    final dynamic roundsRaw = data['rounds'];
    if (roundsRaw != null) {
      final rMap = _firebaseToMap(roundsRaw);

      for (var rEntry in rMap.entries) {
        final dynamic rVal = rEntry.value;

        if (rVal != null && (rVal is Map || rVal is List)) {
          final v = _firebaseToMap(rVal);
          final List<TournamentMatch> matches = [];
          final dynamic matchesRaw = v['matches'];
          if (matchesRaw != null) {
            final mMap = _firebaseToMap(matchesRaw);
            for (var mEntry in mMap.entries) {
              final dynamic mv = mEntry.value;
              if (mv != null && (mv is Map || mv is List)) {
                final m = _firebaseToMap(mv);
                matches.add(TournamentMatch(
                  id: mEntry.key.toString(),
                  whitePlayerId: m['whitePlayerId']?.toString() ?? '',
                  blackPlayerId: m['blackPlayerId']?.toString() ?? '',
                  whitePlayerName: m['whitePlayerName']?.toString() ?? '',
                  blackPlayerName: m['blackPlayerName']?.toString() ?? '',
                  whiteScore: _toDouble(m['whiteScore'], 0.0),
                  blackScore: _toDouble(m['blackScore'], 0.0),
                  isCompleted: m['isCompleted'] == true,
                  method: m['method']?.toString(),
                  startTime: _parseDateTime(m['createdAt']) ?? DateTime.now(),
                ));
              }
            }
          }
          rounds.add(TournamentRound(
            roundNumber: int.tryParse(rEntry.key.toString()) ?? 0,
            matches: matches,
            isCompleted: v['isCompleted'] == true,
          ));
        }
      }
    }

    return Tournament(
      id: id,
      title: data['title']?.toString() ?? 'Unknown Tournament',
      description: data['description']?.toString() ?? '',
      totalRounds: _toInt(data['totalRounds'], 5),
      currentRound: _toInt(data['currentRound'], 0),
      participants: participants,
      rounds: rounds,
      prizePool: _toInt(data['prizePool'], 0),
      autoStartAt: _parseDateTime(data['autoStartAt']),
      scheduledStartAt: _parseDateTime(data['scheduledStartAt']),
      nextEventAt: _parseDateTime(data['nextEventAt']),
      status: TournamentStatus.values.firstWhere(
        (s) => s.name == (data['status']?.toString() ?? 'enrolling'),
        orElse: () => TournamentStatus.enrolling,
      ),
      restTimerSetForRound: data['restTimerSetForRound'] != null ? _toInt(data['restTimerSetForRound']) : null,
    );
  }

  // Run the automation tick logic
  Future<void> runAutomationTick(String tournamentId, DateTime now) async {
    final tDataRaw = db.get('tournaments/$tournamentId');
    if (tDataRaw == null) return;
    final tournament = _parseTournament(tournamentId, tDataRaw as Map<String, dynamic>);

    if (_activeAutomations.contains(tournament.id)) return;

    if (tournament.status == TournamentStatus.active) {
      final currentRound = tournament.rounds.firstWhere(
        (r) => r.roundNumber == tournament.currentRound,
        orElse: () => TournamentRound(roundNumber: 0, matches: []),
      );

      // We skip match expiry checks for this simulation unless needed
      // Check round completion
      final hasUncompletedRealMatches = currentRound.matches.any(
        (m) => !m.isCompleted && m.blackPlayerId != 'BYE',
      );

      if (currentRound.isCompleted && currentRound.matches.isNotEmpty && !hasUncompletedRealMatches) {
        if (tournament.currentRound < tournament.totalRounds) {
          if (tournament.nextEventAt == null && tournament.restTimerSetForRound != tournament.currentRound) {
            
            // TRANSACTION
            final timerCommitted = await db.runTransaction(
              'tournaments/$tournamentId/restTimerSetForRound',
              (currentVal) {
                if (currentVal != null && currentVal is num && currentVal.toInt() == tournament.currentRound) {
                  return null; // abort
                }
                return tournament.currentRound;
              },
            );

            if (timerCommitted) {
              db.eventLog.add("🤖 CLIENT $id: Round ${tournament.currentRound} finished. Setting rest timer.");
              final nextTime = now.add(const Duration(seconds: 30));
              db.update('tournaments/$tournamentId', {
                'nextEventAt': nextTime.millisecondsSinceEpoch,
              });
            }
          } else if (tournament.nextEventAt != null && now.isAfter(tournament.nextEventAt!)) {
            if (_activeAutomations.contains(tournament.id)) return;
            _activeAutomations.add(tournament.id);
            db.eventLog.add("🤖 CLIENT $id: Triggering Next Round (${tournament.currentRound + 1})");
            try {
              db.update('tournaments/$tournamentId', {
                'nextEventAt': null,
              });
              await pairNextRound(tournamentId, tournament.currentRound);
            } catch (e) {
              db.eventLog.add("❌ CLIENT $id: Next round failed: $e");
            } finally {
              _activeAutomations.remove(tournament.id);
            }
          }
        }
      }
    }
  }

  // Pairing algorithm copied from tournament_service.dart
  Future<void> pairNextRound(String tournamentId, [int? expectedCurrentRound]) async {
    final tDataRaw = db.get('tournaments/$tournamentId');
    if (tDataRaw == null) return;
    final tournament = _parseTournament(tournamentId, tDataRaw as Map<String, dynamic>);
    if (expectedCurrentRound != null && tournament.currentRound != expectedCurrentRound) {
      db.eventLog.add("⚠️ CLIENT $id: Current round (${tournament.currentRound}) does not match expected ($expectedCurrentRound). Skipping pairing.");
      return;
    }
    final nextRoundNumber = tournament.currentRound + 1;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lockCommitted = await db.runTransaction(
      'tournaments/$tournamentId/pairing_locks/$nextRoundNumber',
      (currentLock) {
        if (currentLock == null) {
          return nowMs;
        }
        final lockTime = currentLock as int;
        if (nowMs - lockTime > 15000) {
          return nowMs;
        }
        return null; // abort
      },
    );

    if (!lockCommitted) {
      db.eventLog.add("⚠️ CLIENT $id: Round $nextRoundNumber pairing lock held. Skipping.");
      return;
    }

    try {
      int effectiveTotalRounds = tournament.totalRounds;
      if (nextRoundNumber == 1 || effectiveTotalRounds <= 0) {
        int count = tournament.participants.length;
        if (count > 0) {
          effectiveTotalRounds = (log(count) / log(2)).ceil();
          if (effectiveTotalRounds < 1) effectiveTotalRounds = 1;
          db.update('tournaments/$tournamentId', {'totalRounds': effectiveTotalRounds});
        }
      }

      final existingRound = db.get('tournaments/$tournamentId/rounds/$nextRoundNumber');
      if (existingRound != null) {
        db.eventLog.add("⚠️ CLIENT $id: Round $nextRoundNumber already exists. Skipping.");
        db.set('tournaments/$tournamentId/pairing_locks/$nextRoundNumber', 99999999999999);
        return;
      }

      if (nextRoundNumber > effectiveTotalRounds) {
        db.update('tournaments/$tournamentId', {'status': TournamentStatus.completed.name});
        db.set('tournaments/$tournamentId/pairing_locks/$nextRoundNumber', 99999999999999);
        return;
      }

      final sortedParticipants = List<TournamentParticipant>.from(tournament.participants);
      sortedParticipants.sort((a, b) {
        if (b.score != a.score) return b.score.compareTo(a.score);
        return b.rating.compareTo(a.rating);
      });

      final unassigned = List<TournamentParticipant>.from(sortedParticipants);
      final List<Map<String, dynamic>> matchesData = [];
      final Map<String, dynamic> updates = {};

      if (unassigned.length % 2 != 0) {
        int byeIndex = unassigned.length - 1;
        for (int i = unassigned.length - 1; i >= 0; i--) {
          if (!unassigned[i].opponents.contains("BYE")) {
            byeIndex = i;
            break;
          }
        }
        final byePlayer = unassigned.removeAt(byeIndex);
        updates['participants/${byePlayer.userId}/score'] = byePlayer.score + 1.0;
        updates['participants/${byePlayer.userId}/opponents'] = [...byePlayer.opponents, "BYE"];
        updates['participants/${byePlayer.userId}/colors'] = [...byePlayer.colors.map((c) => c?.name ?? "none"), "none"];

        matchesData.add({
          'id': "bye_${nextRoundNumber}_${byePlayer.userId}",
          'whitePlayerId': byePlayer.userId,
          'whitePlayerName': byePlayer.name,
          'blackPlayerId': 'BYE',
          'blackPlayerName': 'BYE',
          'whiteScore': 1.0,
          'blackScore': 0.0,
          'isCompleted': true,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      while (unassigned.length >= 2) {
        final p1 = unassigned.removeAt(0);
        int foundIndex = -1;
        for (int i = 0; i < unassigned.length; i++) {
          if (!p1.opponents.contains(unassigned[i].userId)) {
            foundIndex = i;
            break;
          }
        }
        final p2 = unassigned.removeAt(foundIndex != -1 ? foundIndex : 0);
        final p1WhiteCount = p1.colors.where((c) => c == PlayerColor.white).length;
        final p2WhiteCount = p2.colors.where((c) => c == PlayerColor.white).length;
        final whitePlayer = p1WhiteCount <= p2WhiteCount ? p1 : p2;
        final blackPlayer = whitePlayer == p1 ? p2 : p1;

        final matchId = "tm_${tournamentId}_r${nextRoundNumber}_${whitePlayer.userId}_${blackPlayer.userId}";
        matchesData.add({
          'id': matchId,
          'whitePlayerId': whitePlayer.userId,
          'whitePlayerName': whitePlayer.name,
          'blackPlayerId': blackPlayer.userId,
          'blackPlayerName': blackPlayer.name,
          'whiteScore': 0.0,
          'blackScore': 0.0,
          'isCompleted': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Initialize game node
        db.set('games/$matchId', {
          'status': 'playing',
          'whitePlayerId': whitePlayer.userId,
          'blackPlayerId': blackPlayer.userId,
        });
      }

      updates['currentRound'] = nextRoundNumber;
      updates['status'] = TournamentStatus.active.name;
      updates['rounds/$nextRoundNumber/matches'] = { for (var m in matchesData) m['id']: m };
      updates['rounds/$nextRoundNumber/isCompleted'] = false;
      updates['pairing_locks/$nextRoundNumber'] = 99999999999999;

      db.update('tournaments/$tournamentId', updates);
    } catch (e) {
      db.eventLog.add("❌ CLIENT $id: pairing failed, releasing lock. $e");
      db.set('tournaments/$tournamentId/pairing_locks/$nextRoundNumber', null);
      rethrow;
    }
  }

  // Report match result
  Future<void> reportMatchResult(String tournamentId, int roundNumber, String matchId, double whiteScore, double blackScore) async {
    final tDataRaw = db.get('tournaments/$tournamentId');
    if (tDataRaw == null) {
      print("reportMatchResult: tDataRaw is null for tournaments/$tournamentId");
      return;
    }
    final tournament = _parseTournament(tournamentId, tDataRaw as Map<String, dynamic>);
    final round = tournament.rounds.firstWhere((r) => r.roundNumber == roundNumber, orElse: () => TournamentRound(roundNumber: 0, matches: []));
    if (round.roundNumber == 0) {
      print("reportMatchResult: round $roundNumber not found in tournament rounds: ${tournament.rounds.map((r) => r.roundNumber)}");
      return;
    }
    final match = round.matches.firstWhere((m) => m.id == matchId, orElse: () => TournamentMatch(id: '', whitePlayerId: '', blackPlayerId: '', startTime: DateTime.now()));

    if (match.id.isEmpty) {
      print("reportMatchResult: match $matchId not found in round $roundNumber matches: ${round.matches.map((m) => m.id)}");
      return;
    }
    if (match.isCompleted) {
      print("reportMatchResult: match $matchId is already completed");
      return;
    }

    // 1. Transaction on Match
    final matchCommitted = await db.runTransaction(
      'tournaments/$tournamentId/rounds/$roundNumber/matches/$matchId',
      (currentVal) {
        if (currentVal == null) return null;
        final valMap = Map<String, dynamic>.from(currentVal as Map);
        if (valMap['isCompleted'] == true) return null;
        valMap['whiteScore'] = whiteScore;
        valMap['blackScore'] = blackScore;
        valMap['isCompleted'] = true;
        return valMap;
      },
    );

    if (!matchCommitted) return;

    // 2. Transaction on Participants
    await db.runTransaction(
      'tournaments/$tournamentId/participants',
      (currentParticipants) {
        if (currentParticipants == null) return null;
        final pMap = Map<String, dynamic>.from(currentParticipants as Map);

        final whiteVal = pMap[match.whitePlayerId];
        if (whiteVal != null) {
          final w = Map<String, dynamic>.from(whiteVal as Map);
          final currentScore = _toDouble(w['score'], 0.0);
          final currentOpponents = _safeList(w['opponents']).map((e) => e.toString()).toList();
          final currentColors = _safeList(w['colors']).map((c) => c?.toString() ?? "none").toList();
          w['score'] = currentScore + whiteScore;
          w['opponents'] = [...currentOpponents, match.blackPlayerId];
          w['colors'] = [...currentColors, PlayerColor.white.name];
          pMap[match.whitePlayerId] = w;
        }

        final blackVal = pMap[match.blackPlayerId];
        if (blackVal != null) {
          final b = Map<String, dynamic>.from(blackVal as Map);
          final currentScore = _toDouble(b['score'], 0.0);
          final currentOpponents = _safeList(b['opponents']).map((e) => e.toString()).toList();
          final currentColors = _safeList(b['colors']).map((c) => c?.toString() ?? "none").toList();
          b['score'] = currentScore + blackScore;
          b['opponents'] = [...currentOpponents, match.whitePlayerId];
          b['colors'] = [...currentColors, PlayerColor.black.name];
          pMap[match.blackPlayerId] = b;
        }

        return pMap;
      },
    );

    // 3. Transaction on Round Completion
    await db.runTransaction(
      'tournaments/$tournamentId/rounds/$roundNumber',
      (currentRoundVal) {
        if (currentRoundVal == null) return null;
        final roundMap = Map<String, dynamic>.from(currentRoundVal as Map);
        if (roundMap['isCompleted'] == true) return roundMap;
        final matchesMap = _firebaseToMap(roundMap['matches']);
        bool allCompleted = true;
        for (var mVal in matchesMap.values) {
          final m = _firebaseToMap(mVal);
          if (m['isCompleted'] != true) {
            allCompleted = false;
            break;
          }
        }
        if (allCompleted) {
          roundMap['isCompleted'] = true;
        }
        return roundMap;
      },
    );
  }
}

void main() {
  group('Tournament Automated Testing & Bug Reproduction', () {
    test('Simulate Tournament with 20 Players', () async {
      final db = MockDatabase();
      
      // Initialize Tournament in database
      const tournamentId = "test_tournament_20_players";
      db.set("tournaments/$tournamentId", {
        'title': 'Test 20 Players Tournament',
        'description': 'Simulation',
        'totalRounds': 5,
        'currentRound': 0,
        'status': TournamentStatus.enrolling.name,
        'participants': {},
        'rounds': {},
      });

      // Add 100 participants
      final Map<String, dynamic> participants = {};
      for (int i = 1; i <= 100; i++) {
        participants["player_$i"] = {
          'name': 'Player $i',
          'rating': 1500 - (i * 10),
          'score': 0.0,
          'buchholz': 0.0,
          'opponents': [],
          'colors': [],
        };
      }
      db.update("tournaments/$tournamentId", {'participants': participants});

      // We have multiple clients running automation ticks
      final clients = List.generate(5, (index) => SimulatedClient("Client_${index + 1}", db));

      // 1. Start the tournament (pair round 1)
      db.eventLog.add("--- STARTING ROUND 1 ---");
      await clients[0].pairNextRound(tournamentId, 0);

      DateTime simTime = DateTime.now();

      try {
        // Loop through rounds 1 to 5
        final tDataAtStart = db.get("tournaments/$tournamentId") as Map<String, dynamic>;
        final totalRounds = tDataAtStart['totalRounds'] as int;
        for (int round = 1; round <= totalRounds; round++) {
          db.eventLog.add("--- SIMULATING ROUND $round ---");

          // Verify round started
          final tData = db.get("tournaments/$tournamentId") as Map<String, dynamic>;
          if (tData['currentRound'] != round) {
            print("=== DB EVENT LOG ON FAILURE ===");
            db.eventLog.forEach(print);
          }
          expect(tData['currentRound'], equals(round));

          // Get all matches for this round
          final roundsData = tData['rounds'] as Map<String, dynamic>;
          final roundData = roundsData[round.toString()] as Map<String, dynamic>;
          final matchesMap = roundData['matches'] as Map<String, dynamic>;

          db.eventLog.add("Round $round has ${matchesMap.length} matches.");

          // Simulate playing matches
          for (var matchId in matchesMap.keys) {
            await clients[0].reportMatchResult(tournamentId, round, matchId, 0.5, 0.5);
          }

          db.eventLog.add("All matches in Round $round completed. Triggering automation tick for clients.");

          // Run automation ticks for clients to detect round completion and start the rest timer
          for (var client in clients) {
            await client.runAutomationTick(tournamentId, simTime);
          }

          // Advance simulation time by 31 seconds to expire the rest timer
          simTime = simTime.add(const Duration(seconds: 31));

          // Run automation ticks again to trigger the next round pairing
          // Simulate race condition where clients tick concurrently
          db.eventLog.add("Rest timer expired. Running concurrent automation ticks...");
          
          final List<Future> tickFutures = [];
          for (var client in clients) {
            tickFutures.add(client.runAutomationTick(tournamentId, simTime));
          }
          await Future.wait(tickFutures);

          // Check database event log for simultaneous round starting
          final currentTData = db.get("tournaments/$tournamentId") as Map<String, dynamic>;
          db.eventLog.add("End of Round $round. Current DB round is ${currentTData['currentRound']}");
        }
      } catch (e) {
        print("=== DB EVENT LOG ON EXCEPTION ===");
        db.eventLog.forEach(print);
        rethrow;
      }

      // Print event log
      print("=== DB EVENT LOG ===");
      db.eventLog.forEach(print);
    });
  });
}

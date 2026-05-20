import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tournament_models.dart';
import 'models.dart';

class TournamentService {
  static final TournamentService _instance = TournamentService._internal();
  factory TournamentService() => _instance;
   final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final Set<String> _activeAutomations = {};
  Timer? _automationTimer;

  TournamentService._internal() {
    _startBackgroundCoordinator();
  }

  void _startBackgroundCoordinator() {
    _automationTimer?.cancel();
    _automationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkAllTournamentsForAutomation();
    });
  }

  Future<void> _checkAllTournamentsForAutomation() async {
    final snapshot = await _db.child('tournaments').get();
    if (!snapshot.exists || snapshot.value == null) return;
    
    final mapData = _firebaseToMap(snapshot.value);
    for (var entry in mapData.entries) {
      try {
        final tData = _firebaseToMap(entry.value);
        final tournament = _parseTournament(entry.key.toString(), tData);
        _runAutomationTick(tournament);
      } catch (e) {
        // Silent catch for background errors
      }
    }
  }

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

  /// Stream of all active tournaments
  Stream<List<Tournament>> streamTournaments() {
    print('📡 TOURNAMENT: Listening to live feed...');
    return _db.child('tournaments').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) {
        print('📡 TOURNAMENT: Feed empty (Node does not exist)');
        return [];
      }
      final mapData = _firebaseToMap(data);
      print('📡 TOURNAMENT: Received ${mapData.length} active operations');
      final tournaments = mapData.entries.map((e) {
        try {
          if (e.value == null) return null;
          final tData = _firebaseToMap(e.value);
          final tournament = _parseTournament(e.key.toString(), tData);
          
          // Automation Logic
          _runAutomationTick(tournament);
          
          return tournament;
        } catch (err) {
          print('❌ TOURNAMENT: Parse error for ${e.key}: $err');
          return null;
        }
      }).whereType<Tournament>().toList();
      return tournaments;
    });
  }

  void _runAutomationTick(Tournament t) async {
    if (_activeAutomations.contains(t.id)) return;

    final now = DateTime.now();
    
    // 1. Auto-Start from Enrolling
    if (t.status == TournamentStatus.enrolling && t.autoStartAt != null) {
      if (now.isAfter(t.autoStartAt!)) {
        if (t.participants.length < 2) {
          _activeAutomations.add(t.id);
          try {
            print('🤖 AUTO: Joining timeout reached with ${t.participants.length} players for ${t.id}. Marking as completed.');
            await updateTournamentStatus(t.id, TournamentStatus.completed);
          } catch (e) {
            print('❌ AUTO ERROR: Auto-complete failed for ${t.id}: $e');
          } finally {
            _activeAutomations.remove(t.id);
          }
          return;
        }
        
        _activeAutomations.add(t.id);
        print('🤖 AUTO: Triggering Start for ${t.id}');
        try {
          // Double check status before pairing
          final currentT = await _db.child('tournaments').child(t.id).get();
          if (currentT.exists && (currentT.value as Map)['status'] == 'enrolling') {
            await pairNextRound(t.id);
          }
        } catch (e) {
          print('❌ AUTO ERROR: Start failed for ${t.id}: $e');
        } finally {
          _activeAutomations.remove(t.id);
        }
      }
    }
    
    // 2. Auto-Next Round
    if (t.status == TournamentStatus.active) {
      final currentRound = t.rounds.firstWhere((r) => r.roundNumber == t.currentRound, orElse: () => TournamentRound(roundNumber: 0, matches: []));
      
      // Safety: Only proceed if the round is actually completed and has matches
      if (currentRound.isCompleted && currentRound.matches.isNotEmpty) {
        // ONLY set next event if we haven't reached the end
        if (t.currentRound < t.totalRounds) {
          // Use a round-specific lock to prevent double timer setting
          if (t.nextEventAt == null && t.restTimerSetForRound != t.currentRound) {
            // Set timer for next round (rest period)
            print('🤖 AUTO: Round ${t.currentRound} finished. Setting rest timer.');
            final nextTime = now.add(const Duration(seconds: 30));
            await _db.child('tournaments').child(t.id).update({
              'nextEventAt': nextTime.millisecondsSinceEpoch,
              'restTimerSetForRound': t.currentRound,
            });
          } else if (t.nextEventAt != null && now.isAfter(t.nextEventAt!)) {
            if (_activeAutomations.contains(t.id)) return;
            
            _activeAutomations.add(t.id);
            print('🤖 AUTO: Triggering Next Round (${t.currentRound + 1}) for ${t.id}');
            try {
              // CRITICAL: Clear timer first to avoid double pairing
              await _db.child('tournaments').child(t.id).update({'nextEventAt': null});
              await pairNextRound(t.id);
            } catch (e) {
              print('❌ AUTO ERROR: Next round failed for ${t.id}: $e');
            } finally {
              _activeAutomations.remove(t.id);
            }
          }
        } else {
          // Final round is completed
          if (t.status != TournamentStatus.completed) {
            print('🤖 AUTO: Final Round ${t.currentRound} completed. Marking tournament as finished.');
            await updateTournamentStatus(t.id, TournamentStatus.completed);
            // Ensure all stale timers and locks are cleared
            await _db.child('tournaments').child(t.id).update({
              'nextEventAt': null,
              'restTimerSetForRound': null,
            });
          }
        }
      }
    }
  }

  /// Stream of a specific tournament
  Stream<Tournament?> streamTournament(String tournamentId) {
    return _db.child('tournaments').child(tournamentId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return _parseTournament(tournamentId, _firebaseToMap(data));
    });
  }

  Tournament _parseTournament(String id, Map<dynamic, dynamic> data) {
    // Parse participants
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
            rating: (v['rating'] ?? 1200).toInt(),
            score: (v['score'] ?? 0).toDouble(),
            buchholz: (v['buchholz'] ?? 0).toDouble(),
            opponents: _safeList(v['opponents']).map((e) => e.toString()).toList(),
            colors: _safeList(v['colors']).map<PlayerColor>((c) => c.toString() == 'white' ? PlayerColor.white : PlayerColor.black).toList(),
          ));
        }
      }
    }

    // Parse rounds
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
                  whiteScore: (m['whiteScore'] ?? 0).toDouble(),
                  blackScore: (m['blackScore'] ?? 0).toDouble(),
                  isCompleted: m['isCompleted'] == true,
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
      totalRounds: (data['totalRounds'] ?? 5).toInt(),
      currentRound: (data['currentRound'] ?? 0).toInt(),
      participants: participants,
      rounds: rounds,
      prizePool: (data['prizePool'] ?? 0).toInt(),
      settings: GameSettings(timeLimit: Duration(seconds: (data['timeLimit'] ?? 180).toInt())),
      autoStartAt: data['autoStartAt'] != null ? DateTime.fromMillisecondsSinceEpoch((data['autoStartAt'] as num).toInt()) : null,
      scheduledStartAt: data['scheduledStartAt'] != null ? DateTime.fromMillisecondsSinceEpoch((data['scheduledStartAt'] as num).toInt()) : null,
      nextEventAt: data['nextEventAt'] != null ? DateTime.fromMillisecondsSinceEpoch((data['nextEventAt'] as num).toInt()) : null,
      status: TournamentStatus.values.firstWhere(
        (s) => s.name == (data['status']?.toString() ?? 'enrolling'),
        orElse: () => TournamentStatus.enrolling,
      ),
      restTimerSetForRound: data['restTimerSetForRound'] != null ? (data['restTimerSetForRound'] as num).toInt() : null,
    );
  }

  /// Join the tournament
  Future<void> joinTournament(String tournamentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Must be logged in");

    // Fetch tournament to validate joining deadline
    final tSnapshot = await _db.child('tournaments').child(tournamentId).get();
    if (tSnapshot.exists && tSnapshot.value != null) {
      final tData = _firebaseToMap(tSnapshot.value);
      if (tData['status'] == 'completed') {
        throw Exception("Tournament has already completed.");
      }
      if (tData['status'] == 'active') {
        throw Exception("Tournament has already started.");
      }
      if (tData['autoStartAt'] != null) {
        final deadline = DateTime.fromMillisecondsSinceEpoch((tData['autoStartAt'] as num).toInt());
        if (DateTime.now().isAfter(deadline)) {
          throw Exception("Registration window is closed.");
        }
      }
      if (tData['scheduledStartAt'] != null) {
        final start = DateTime.fromMillisecondsSinceEpoch((tData['scheduledStartAt'] as num).toInt());
        if (DateTime.now().isBefore(start)) {
          throw Exception("Registration has not opened yet.");
        }
      }
    }

    // Fetch user rating for seeding
    final statsSnapshot = await _db.child('users').child(user.uid).child('stats').get();
    int rating = 1200;
    if (statsSnapshot.exists && statsSnapshot.value != null) {
        final stats = _firebaseToMap(statsSnapshot.value);
        rating = (stats['rating'] ?? 1200).toInt();
    }

    await _db.child('tournaments').child(tournamentId).child('participants').child(user.uid).set({
      'name': user.displayName ?? 'Anonymous',
      'rating': rating,
      'score': 0,
      'buchholz': 0,
      'opponents': [],
      'colors': [],
    });
  }

  /// Create a new tournament
  Future<void> createTournament({
    required String id,
    required String title,
    required String description,
    required int totalRounds,
    required int prizePool,
    required int timeLimitSeconds,
    required DateTime scheduledStartAt,
    required int autoStartDelayMinutes,
  }) async {
    final autoStartAt = scheduledStartAt.add(Duration(minutes: autoStartDelayMinutes));
    await _db.child('tournaments').child(id).set({
      'title': title,
      'description': description,
      'totalRounds': totalRounds,
      'currentRound': 0,
      'status': 'enrolling',
      'prizePool': prizePool,
      'timeLimit': timeLimitSeconds,
      'scheduledStartAt': scheduledStartAt.millisecondsSinceEpoch,
      'autoStartAt': autoStartAt.millisecondsSinceEpoch,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Update tournament status
  Future<void> updateTournamentStatus(String tournamentId, TournamentStatus status) async {
    await _db.child('tournaments').child(tournamentId).update({
      'status': status.name,
    });
  }

  /// Delete a tournament
  Future<void> deleteTournament(String tournamentId) async {
    await _db.child('tournaments').child(tournamentId).remove();
  }

  /// Pair next round (Admin/Automated)
  Future<void> pairNextRound(String tournamentId) async {
    final tRef = _db.child('tournaments').child(tournamentId);
    final snapshot = await tRef.get();
    if (!snapshot.exists || snapshot.value == null) return;
    
    final tournament = _parseTournament(tournamentId, _firebaseToMap(snapshot.value));
    final nextRoundNumber = tournament.currentRound + 1;

    // 1. DYNAMIC ROUND CALCULATION (If not set or first round)
    int effectiveTotalRounds = tournament.totalRounds;
    if (nextRoundNumber == 1 || effectiveTotalRounds <= 0) {
      int count = tournament.participants.length;
      if (count > 0) {
        effectiveTotalRounds = (log(count) / log(2)).ceil();
        if (effectiveTotalRounds < 1) effectiveTotalRounds = 1;
        await tRef.update({'totalRounds': effectiveTotalRounds});
        print('🤖 AUTO: Dynamically set totalRounds to $effectiveTotalRounds for $count players.');
      }
    }

    // CRITICAL: Check if this round was already paired in the DB to avoid double-triggers
    final existingRoundSnapshot = await tRef.child('rounds').child(nextRoundNumber.toString()).get();
    if (existingRoundSnapshot.exists) {
      print('⚠️ AUTO: Round $nextRoundNumber already exists in DB. Skipping duplicate pairing.');
      return;
    }
    
    if (nextRoundNumber > effectiveTotalRounds) {
      await updateTournamentStatus(tournamentId, TournamentStatus.completed);
      return;
    }

    // Sort participants by score, then rating
    final sortedParticipants = List<TournamentParticipant>.from(tournament.participants);
    sortedParticipants.sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      return b.rating.compareTo(a.rating);
    });

    final unassigned = List<TournamentParticipant>.from(sortedParticipants);
    final List<Map<String, dynamic>> matchesData = [];
    
    // 2. Handle BYE if odd number of participants
    if (unassigned.length % 2 != 0) {
      // Find the best candidate for a BYE (lowest score, hasn't had a BYE)
      // Since they are already sorted by score ascending in pairNextRound, we take the first one?
      // Wait, unassigned was sorted by score DESCENDING (sortedParticipants.sort(b.score.compareTo(a.score)))
      // So the last one has the lowest score.
      final byePlayer = unassigned.removeLast();
      
      print('🤖 AUTO: Assigning BYE to ${byePlayer.name}');
      
      // Give 1.0 point for the BYE
      final byeUpdate = {
        'score': byePlayer.score + 1.0,
        'opponents': [...byePlayer.opponents, "BYE"],
        'colors': [...byePlayer.colors.map((c) => c.name), "none"],
      };
      await tRef.child('participants').child(byePlayer.userId).update(byeUpdate);

      // Record the BYE match
      matchesData.add({
        'id': "bye_${nextRoundNumber}_${byePlayer.userId}",
        'whitePlayerId': byePlayer.userId,
        'whitePlayerName': byePlayer.name,
        'blackPlayerId': 'BYE',
        'blackPlayerName': 'BYE',
        'whiteScore': 1.0,
        'blackScore': 0.0,
        'isCompleted': true,
        'createdAt': ServerValue.timestamp,
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
      
      // DETERMINISTIC MATCH ID: tm_[tournamentId]_r[round]_[whiteId]_[blackId]
      // This prevents duplicate rooms if the logic triggers multiple times.
      final matchId = "tm_${tournamentId}_r${nextRoundNumber}_${whitePlayer.userId}_${blackPlayer.userId}";

      matchesData.add({
        'id': matchId,
        'whitePlayerId': whitePlayer.userId,
        'whitePlayerName': whitePlayer.name,
        'blackPlayerId': blackPlayer.userId,
        'blackPlayerName': blackPlayer.name,
        'whiteScore': 0,
        'blackScore': 0,
        'isCompleted': false,
        'createdAt': ServerValue.timestamp,
      });

      // INITIALIZE GAME NODE IN REALTIME DB
      // This ensures the BoardScreen can find the match data
      await _db.child('games').child(matchId).set({
        'status': 'playing',
        'whitePlayerId': whitePlayer.userId,
        'whitePlayerName': whitePlayer.name,
        'blackPlayerId': blackPlayer.userId,
        'blackPlayerName': blackPlayer.name,
        'boardState': 'rnbmqkmbnr/pppppppppp/91/91/91/91/91/91/PPPPPPPPPP/RNBMQKMBNR w - -',
        'turn': 'white',
        'whiteTime': tournament.settings.timeLimit.inSeconds,
        'blackTime': tournament.settings.timeLimit.inSeconds,
        'createdAt': ServerValue.timestamp,
        'tournamentId': tournamentId,
        'roundNumber': nextRoundNumber,
      });
    }

    final updates = {
      'currentRound': nextRoundNumber,
      'status': 'active',
      'rounds/$nextRoundNumber/matches': { for (var m in matchesData) m['id']: m },
      'rounds/$nextRoundNumber/isCompleted': false,
    };
    
    await _db.child('tournaments').child(tournamentId).update(updates);
  }

  /// Record a match result and update participant scores
  Future<void> reportMatchResult(String tournamentId, int roundNumber, String matchId, double whiteScore, double blackScore) async {
    final tRef = _db.child('tournaments').child(tournamentId);
    final snapshot = await tRef.get();
    if (!snapshot.exists || snapshot.value == null) return;

    final tournament = _parseTournament(tournamentId, _firebaseToMap(snapshot.value));
    final round = tournament.rounds.firstWhere((r) => r.roundNumber == roundNumber);
    final match = round.matches.firstWhere((m) => m.id == matchId);

    if (match.isCompleted) return;

    await tRef.child('rounds').child(roundNumber.toString()).child('matches').child(matchId).update({
      'whiteScore': whiteScore,
      'blackScore': blackScore,
      'isCompleted': true,
    });

    final whiteUpdate = _getParticipantUpdate(tournament, match.whitePlayerId, whiteScore, match.blackPlayerId, PlayerColor.white);
    final blackUpdate = _getParticipantUpdate(tournament, match.blackPlayerId, blackScore, match.whitePlayerId, PlayerColor.black);

    await tRef.child('participants').child(match.whitePlayerId).update(whiteUpdate);
    await tRef.child('participants').child(match.blackPlayerId).update(blackUpdate);

    final updatedSnapshotForRound = await tRef.get();
    if (updatedSnapshotForRound.value != null) {
      final updatedTournamentForRound = _parseTournament(tournamentId, _firebaseToMap(updatedSnapshotForRound.value));
      final updatedRound = updatedTournamentForRound.rounds.firstWhere((r) => r.roundNumber == roundNumber);
      if (updatedRound.matches.every((m) => m.isCompleted)) {
        await tRef.child('rounds').child(roundNumber.toString()).update({'isCompleted': true});
      }
    }

    final updatedSnapshot = await tRef.get();
    if (updatedSnapshot.value != null) {
      final updatedTournament = _parseTournament(tournamentId, _firebaseToMap(updatedSnapshot.value));
      final Map<String, dynamic> bhUpdates = {};
      for (var p in updatedTournament.participants) {
        double bh = 0.0;
        for (var oppId in p.opponents) {
          if (oppId == "BYE") continue;
          final opp = updatedTournament.participants.firstWhere((part) => part.userId == oppId, orElse: () => TournamentParticipant(userId: "", name: ""));
          bh += opp.score;
        }
        bhUpdates['${p.userId}/buchholz'] = bh;
      }
      await tRef.child('participants').update(bhUpdates);
    }
  }

  Map<String, dynamic> _getParticipantUpdate(Tournament tournament, String uid, double points, String opponentId, PlayerColor color) {
    final p = tournament.participants.firstWhere((part) => part.userId == uid);
    final newOpponents = List<String>.from(p.opponents)..add(opponentId);
    final newColors = List<String>.from(p.colors.map((c) => c.name))..add(color.name);
    
    return {
      'score': p.score + points,
      'opponents': newOpponents,
      'colors': newColors,
    };
  }
}

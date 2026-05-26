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
  final Set<String> _activeMatchResolutions = {};
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
      
      // Check for expired matches in the current active round
      for (var match in currentRound.matches) {
        if (!match.isCompleted && !_activeMatchResolutions.contains(match.id)) {
          final expiryTime = match.startTime.add(t.settings.timeLimit * 2).add(const Duration(minutes: 2));
          if (now.isAfter(expiryTime)) {
            _activeMatchResolutions.add(match.id);
            print('🤖 AUTO: Match ${match.id} has expired. Triggering auto-resolution.');
            _autoResolveMatch(t.id, t.currentRound, match).then((_) {
              _activeMatchResolutions.remove(match.id);
            }).catchError((e) {
              _activeMatchResolutions.remove(match.id);
            });
          }
        }
      }

      // Safety: Only proceed if the round is actually completed and has real (non-BYE) matches
      // Also verify ALL matches are completed, not just the round flag (defense against stale data)
      final hasUncompletedRealMatches = currentRound.matches.any(
        (m) => !m.isCompleted && m.blackPlayerId != 'BYE',
      );
      if (currentRound.isCompleted && currentRound.matches.isNotEmpty && !hasUncompletedRealMatches) {
        // ONLY set next event if we haven't reached the end
        if (t.currentRound < t.totalRounds) {
          // Use a round-specific lock to prevent double timer setting
          if (t.nextEventAt == null && t.restTimerSetForRound != t.currentRound) {
            // Use a transaction to atomically set the rest timer,
            // preventing multiple clients from setting it simultaneously
            final timerRef = _db.child('tournaments').child(t.id).child('restTimerSetForRound');
            final timerResult = await timerRef.runTransaction((Object? currentVal) {
              // Only set timer if no other client has set it for this round
              if (currentVal != null && currentVal is num && currentVal.toInt() == t.currentRound) {
                return Transaction.abort(); // Another client already set it
              }
              return Transaction.success(t.currentRound);
            });

            if (timerResult.committed) {
              print('🤖 AUTO: Round ${t.currentRound} finished. Setting rest timer.');
              final nextTime = now.add(const Duration(seconds: 30));
              await _db.child('tournaments').child(t.id).update({
                'nextEventAt': nextTime.millisecondsSinceEpoch,
              });
            }
          } else if (t.nextEventAt != null && now.isAfter(t.nextEventAt!)) {
            if (_activeAutomations.contains(t.id)) return;
            
            _activeAutomations.add(t.id);
            print('🤖 AUTO: Triggering Next Round (${t.currentRound + 1}) for ${t.id}');
            try {
              // Clear the timer. We do NOT pre-set restTimerSetForRound here,
              // because the newly created round has isCompleted=false (set in pairNextRound),
              // which prevents the automation from immediately treating it as completed.
              // Pre-setting restTimerSetForRound to nextRound would block the timer
              // from being set when that round ACTUALLY completes later.
              await _db.child('tournaments').child(t.id).update({
                'nextEventAt': null,
              });
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
                  whiteScore: _toDouble(m['whiteScore'], 0.0),
                  blackScore: _toDouble(m['blackScore'], 0.0),
                  isCompleted: m['isCompleted'] == true,
                  startTime: _parseDateTime(m['createdAt']),
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
      settings: GameSettings(timeLimit: Duration(seconds: _toInt(data['timeLimit'], 180))),
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

    // Acquire pairing lock to prevent concurrent clients from running pairing logic
    final lockRef = tRef.child('pairing_locks').child(nextRoundNumber.toString());
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lockResult = await lockRef.runTransaction((Object? currentLock) {
      if (currentLock == null) {
        return Transaction.success(nowMs);
      }
      // Self-healing: if lock was acquired more than 15s ago, assume the client crashed and reclaim it
      final lockTime = currentLock as int;
      if (nowMs - lockTime > 15000) {
        return Transaction.success(nowMs);
      }
      return Transaction.abort();
    });

    if (!lockResult.committed) {
      print('⚠️ AUTO: Round $nextRoundNumber pairing lock is held by another client. Skipping.');
      return;
    }

    try {
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
        await lockRef.set(99999999999999);
        return;
      }
      
      if (nextRoundNumber > effectiveTotalRounds) {
        await updateTournamentStatus(tournamentId, TournamentStatus.completed);
        await lockRef.set(99999999999999);
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
      final Map<String, dynamic> updates = {};
      
      // 2. Handle BYE if odd number of participants
      if (unassigned.length % 2 != 0) {
        // Find the lowest ranked player who HAS NOT yet received a BYE
        int byeIndex = unassigned.length - 1;
        for (int i = unassigned.length - 1; i >= 0; i--) {
          if (!unassigned[i].opponents.contains("BYE")) {
            byeIndex = i;
            break;
          }
        }
        final byePlayer = unassigned.removeAt(byeIndex);
        
        print('🤖 AUTO: Assigning BYE to ${byePlayer.name}');
        
        // Give 1.0 point for the BYE inside updates atomically
        updates['participants/${byePlayer.userId}/score'] = byePlayer.score + 1.0;
        updates['participants/${byePlayer.userId}/opponents'] = [...byePlayer.opponents, "BYE"];
        updates['participants/${byePlayer.userId}/colors'] = [...byePlayer.colors.map((c) => c?.name ?? "none"), "none"];

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

      updates['currentRound'] = nextRoundNumber;
      updates['status'] = 'active';
      updates['rounds/$nextRoundNumber/matches'] = { for (var m in matchesData) m['id']: m };
      updates['rounds/$nextRoundNumber/isCompleted'] = false;
      updates['pairing_locks/$nextRoundNumber'] = 99999999999999;
      
      await tRef.update(updates);

      // Recalculate Buchholz scores at the end of pairing
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
        if (bhUpdates.isNotEmpty) {
          await tRef.child('participants').update(bhUpdates);
        }
      }
    } catch (e) {
      print('❌ AUTO ERROR: pairing failed, releasing lock. $e');
      await lockRef.remove();
      rethrow;
    }
  }

  /// Record a match result and update participant scores
  Future<void> reportMatchResult(String tournamentId, int roundNumber, String matchId, double whiteScore, double blackScore) async {
    final tRef = _db.child('tournaments').child(tournamentId);
    final snapshot = await tRef.get();
    if (!snapshot.exists || snapshot.value == null) return;

    final tournament = _parseTournament(tournamentId, _firebaseToMap(snapshot.value));
    final round = tournament.rounds.firstWhere((r) => r.roundNumber == roundNumber, orElse: () => TournamentRound(roundNumber: 0, matches: []));
    final match = round.matches.firstWhere((m) => m.id == matchId, orElse: () => TournamentMatch(id: '', whitePlayerId: '', blackPlayerId: ''));

    if (match.id.isEmpty || match.isCompleted) return;

    // 1. Transactionally mark match as completed
    final matchRef = tRef.child('rounds').child(roundNumber.toString()).child('matches').child(matchId);
    final transactionResult = await matchRef.runTransaction((Object? currentMatchValue) {
      if (currentMatchValue == null) return Transaction.abort();
      final matchMap = _firebaseToMap(currentMatchValue);
      if (matchMap['isCompleted'] == true) return Transaction.abort();
      matchMap['whiteScore'] = whiteScore;
      matchMap['blackScore'] = blackScore;
      matchMap['isCompleted'] = true;
      return Transaction.success(matchMap);
    });

    if (!transactionResult.committed) {
      print('⚠️ AUTO: Match $matchId result was already reported. Skipping.');
      return;
    }

    // 2. Transactionally update participant scores and recalculate Buchholz
    final participantsRef = tRef.child('participants');
    await participantsRef.runTransaction((Object? currentParticipants) {
      if (currentParticipants == null) return Transaction.abort();
      final pMap = _firebaseToMap(currentParticipants);

      // Update white player
      final whiteVal = pMap[match.whitePlayerId];
      if (whiteVal != null) {
        final w = _firebaseToMap(whiteVal);
        final currentScore = _toDouble(w['score'], 0.0);
        final currentOpponents = _safeList(w['opponents']).map((e) => e.toString()).toList();
        final currentColors = _safeList(w['colors']).map((c) => c?.toString() ?? "none").toList();

        w['score'] = currentScore + whiteScore;
        w['opponents'] = [...currentOpponents, match.blackPlayerId];
        w['colors'] = [...currentColors, PlayerColor.white.name];
        pMap[match.whitePlayerId] = w;
      }

      // Update black player
      final blackVal = pMap[match.blackPlayerId];
      if (blackVal != null) {
        final b = _firebaseToMap(blackVal);
        final currentScore = _toDouble(b['score'], 0.0);
        final currentOpponents = _safeList(b['opponents']).map((e) => e.toString()).toList();
        final currentColors = _safeList(b['colors']).map((c) => c?.toString() ?? "none").toList();

        b['score'] = currentScore + blackScore;
        b['opponents'] = [...currentOpponents, match.whitePlayerId];
        b['colors'] = [...currentColors, PlayerColor.black.name];
        pMap[match.blackPlayerId] = b;
      }

      // Recalculate Buchholz scores for all participants based on the new scores and opponents in pMap
      final playerScores = <String, double>{};
      pMap.forEach((uid, val) {
        final v = _firebaseToMap(val);
        playerScores[uid.toString()] = _toDouble(v['score'], 0.0);
      });

      pMap.forEach((uid, val) {
        final v = _firebaseToMap(val);
        final opponents = _safeList(v['opponents']).map((e) => e.toString()).toList();
        double bh = 0.0;
        for (var oppId in opponents) {
          if (oppId == "BYE") continue;
          bh += playerScores[oppId] ?? 0.0;
        }
        v['buchholz'] = bh;
        pMap[uid] = v;
      });

      return Transaction.success(pMap);
    });

    // 3. Transactionally check round completion
    final roundRef = tRef.child('rounds').child(roundNumber.toString());
    await roundRef.runTransaction((Object? currentRoundVal) {
      if (currentRoundVal == null) return Transaction.abort();
      final roundMap = _firebaseToMap(currentRoundVal);
      if (roundMap['isCompleted'] == true) {
        return Transaction.success(roundMap); // already completed, no-op
      }
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
      return Transaction.success(roundMap);
    });
  }

  Future<void> _autoResolveMatch(String tournamentId, int roundNumber, TournamentMatch match) async {
    final gameRef = _db.child('games').child(match.id);
    double whiteScore = 0.5;
    double blackScore = 0.5;
    
    try {
      final gameSnapshot = await gameRef.get();
      if (gameSnapshot.exists && gameSnapshot.value != null) {
        final gameData = _firebaseToMap(gameSnapshot.value);
        final status = gameData['status']?.toString();
        
        if (status == 'white_won') {
          whiteScore = 1.0;
          blackScore = 0.0;
        } else if (status == 'black_won') {
          whiteScore = 0.0;
          blackScore = 1.0;
        } else if (status == 'draw') {
          whiteScore = 0.5;
          blackScore = 0.5;
        } else {
          final transactionResult = await gameRef.runTransaction((Object? currentGame) {
            if (currentGame == null) return Transaction.abort();
            final gMap = _firebaseToMap(currentGame);
            final currentStatus = gMap['status']?.toString();
            if (currentStatus == 'white_won' || currentStatus == 'black_won' || currentStatus == 'draw') {
              return Transaction.abort();
            }
            gMap['status'] = 'draw';
            gMap['gameMethod'] = 'timeout_expiry';
            gMap['finishedAt'] = DateTime.now().millisecondsSinceEpoch;
            return Transaction.success(gMap);
          });
          
          if (!transactionResult.committed) {
            final freshSnapshot = await gameRef.get();
            if (freshSnapshot.exists && freshSnapshot.value != null) {
              final freshData = _firebaseToMap(freshSnapshot.value);
              final freshStatus = freshData['status']?.toString();
              if (freshStatus == 'white_won') {
                whiteScore = 1.0;
                blackScore = 0.0;
              } else if (freshStatus == 'black_won') {
                whiteScore = 0.0;
                blackScore = 1.0;
              }
            }
          }
        }
      }
      
      await reportMatchResult(tournamentId, roundNumber, match.id, whiteScore, blackScore);
    } catch (e) {
      print('❌ AUTO ERROR: _autoResolveMatch failed for ${match.id}: $e');
    }
  }
}

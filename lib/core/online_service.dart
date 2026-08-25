import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/models.dart';
import '../core/fcm_sender_service.dart';

class OnlineService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  String get userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Must be logged in to play online");
    return user.uid;
  }

  // Create a new game
  Future<String> createGame(int timeLimitSeconds, {bool isPublic = false}) async {
    String roomId = _generateRoomId();
    String myId = userId;
    
    try {
      print('DEBUG: Creating game with roomId: $roomId, isPublic: $isPublic');
      
      String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';
      
      await _db.child('games').child(roomId).set({
        'status': 'waiting',
        'isPublic': isPublic,
        'whitePlayerId': myId,
        'whitePlayerName': myName,
        'blackPlayerId': '',
        'blackPlayerName': '',
        'boardState': 'rnbmqkmbnr/pppppppppp/91/91/91/91/91/91/PPPPPPPPPP/RNBMQKMBNR w - -',
        'turn': 'white',
        'whiteTime': timeLimitSeconds,
        'blackTime': timeLimitSeconds,
        'createdAt': ServerValue.timestamp,
      });

      // Handle disconnect
      _db.child('games').child(roomId).onDisconnect().update({'status': 'aborted'});
      
      print('DEBUG: Game created successfully: $roomId');
      return roomId;
    } catch (e) {
      print('ERROR creating game: $e');
      rethrow;
    }
  }

  // Find a random public game, or create one if none exists
  Future<String> findRandomMatch(int timeLimitSeconds) async {
    String myId = userId;
    
    try {
      // Find a waiting game with the same time limit where we are not the creator
      final snapshot = await _db.child('games')
          .orderByChild('status')
          .equalTo('waiting')
          .get();
          
      if (snapshot.exists) {
        final games = Map<dynamic, dynamic>.from(snapshot.value as Map);
        
        for (var entry in games.entries) {
          final roomId = entry.key;
          final gameData = Map<dynamic, dynamic>.from(entry.value as Map);
          
          if (gameData['isPublic'] == true && 
              gameData['whiteTime'] == timeLimitSeconds && 
              gameData['whitePlayerId'] != myId) {
              
            // Attempt to join via transaction
            bool joined = await joinGame(roomId);
            if (joined) {
              print('DEBUG: Successfully joined random match: $roomId');
              return roomId;
            }
          }
        }
      }
      
      // If we couldn't join any game, create a new public one
      print('DEBUG: No matching games found, creating new one for matchmaking');
      return await createGame(timeLimitSeconds, isPublic: true);
    } catch (e) {
      print('ERROR finding random match: $e');
      rethrow;
    }
  }

  // Join an existing game (Updated with Transaction)
  Future<bool> joinGame(String roomId) async {
    try {
      print('DEBUG: Attempting to join game: $roomId');
      String myId = userId;
      
      final gameRef = _db.child('games').child(roomId);
      
      final result = await gameRef.runTransaction((Object? post) {
        if (post == null) return Transaction.success(post);
        
        final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(post as Map);
        
        if (data['status'] != 'waiting') {
           // Can't join
           return Transaction.abort(); 
        }
        
        if (data['blackPlayerId'] == '' || data['blackPlayerId'] == null) {
          // Prevent joining own game
          if (data['whitePlayerId'] == myId) {
             print('DEBUG: Cannot join own game');
             return Transaction.abort();
          }

          String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';
          data['blackPlayerId'] = myId;
          data['blackPlayerName'] = myName;
          data['status'] = 'playing';
          return Transaction.success(data);
        } else {
          return Transaction.abort(); // Seat taken
        }
      });

      if (result.committed) {
         // Handle disconnect
         gameRef.onDisconnect().update({'status': 'aborted'});
         print('DEBUG: Successfully joined game: $roomId');
         return true;
      } else {
         print('DEBUG: Failed to join room $roomId (Full or Not Waiting)');
         return false;
      }
    } catch (e) {
      print('ERROR joining game: $e');
      rethrow;
    }
  }
  
  // Explicitly leave game
  Future<void> leaveGame(String roomId) async {
    if (roomId.startsWith('tm_')) {
      print('DEBUG: Not aborting tournament game: $roomId');
      return;
    }
    try {
      await _db.child('games').child(roomId).update({'status': 'aborted'});
      await _db.child('games').child(roomId).onDisconnect().cancel();
    } catch (e) {
      print('ERROR leaving game: $e');
    }
  }

  // Stream game updates
  Stream<DatabaseEvent> getGameStream(String roomId) {
    return _db.child('games').child(roomId).onValue;
  }

  // Make a move
  Future<void> makeMove(String roomId, String fen, PlayerColor nextTurn, int wTime, int bTime, Position from, Position to, {String? pieceType}) async {
    final gameRef = _db.child('games').child(roomId);
    
    // Record basic move update
    await gameRef.update({
      'boardState': fen,
      'turn': nextTurn == PlayerColor.white ? 'white' : 'black',
      'whiteTime': wTime,
      'blackTime': bTime,
      'lastMove': {
        'from': {'x': from.x, 'y': from.y},
        'to': {'x': to.x, 'y': to.y},
        if (pieceType != null) 'pieceType': pieceType,
      },
      'lastMoveTimestamp': ServerValue.timestamp,
    });

    // Record to move history for replay
    await gameRef.child('moveHistory').push().set({
      'fen': fen,
      'timestamp': ServerValue.timestamp,
      'from': {'x': from.x, 'y': from.y},
      'to': {'x': to.x, 'y': to.y},
      if (pieceType != null) 'pieceType': pieceType,
      'player': nextTurn == PlayerColor.white ? 'black' : 'white', // The player who just moved
    });
  }

  Future<void> resignGame(String roomId, PlayerColor resigningPlayer) async {
    final gameRef = _db.child('games').child(roomId);
    String newStatus = resigningPlayer == PlayerColor.white ? 'black_won' : 'white_won';
    await gameRef.update({
      'status': newStatus,
      'gameMethod': 'resignation',  // Mark how the game ended
    });
  }

  Future<void> requestRematch(String roomId, String userId, String userName) async {
    final gameRef = _db.child('games').child(roomId);
    await gameRef.child('rematch').set({
      'requestedBy': userId,
      'requestedByName': userName,
      'status': 'pending',
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> declineRematch(String roomId) async {
    final gameRef = _db.child('games').child(roomId);
    await gameRef.child('rematch').update({
      'status': 'declined',
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> cancelRematch(String roomId) async {
    final gameRef = _db.child('games').child(roomId);
    await gameRef.child('rematch').remove();
  }

  Future<void> acceptRematch(String roomId, int timeLimitSeconds) async {
    final gameRef = _db.child('games').child(roomId);
    final snapshot = await gameRef.get();
    if (!snapshot.exists) return;

    final gameData = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final oldWhiteId = gameData['whitePlayerId'];
    final oldWhiteName = gameData['whitePlayerName'];
    final oldBlackId = gameData['blackPlayerId'];
    final oldBlackName = gameData['blackPlayerName'];

    const startingFen = 'rnbmqkmbnr/pppppppppp/10/10/10/10/10/10/PPPPPPPPPP/RNBMQKMBNR w - -';

    // Clear moveHistory for the new game
    await gameRef.child('moveHistory').remove();

    // Reset game room with swapped colors for a balanced rematch
    await gameRef.update({
      'boardState': startingFen,
      'turn': 'white',
      'status': 'playing',
      'whiteTime': timeLimitSeconds,
      'blackTime': timeLimitSeconds,
      'whitePlayerId': oldBlackId,
      'whitePlayerName': oldBlackName,
      'blackPlayerId': oldWhiteId,
      'blackPlayerName': oldWhiteName,
      'lastMove': null,
      'winnerId': null,
      'gameMethod': null,
      'finishedAt': null,
      'lastMoveTimestamp': ServerValue.timestamp,
      'rematch': {
        'status': 'accepted',
        'timestamp': ServerValue.timestamp,
      },
    });
  }

  // Record game result and update stats for both players
  Future<void> recordGameResult(String roomId, String? winnerId, String result, String method) async {
    print('🎮 recordGameResult CALLED: roomId=$roomId, winnerId=$winnerId, result=$result, method=$method');
    try {
      final gameRef = _db.child('games').child(roomId);
      final snapshot = await gameRef.get();
      
      if (!snapshot.exists) return;
      
      final gameData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final whiteId = gameData['whitePlayerId'];
      final blackId = gameData['blackPlayerId'];
      final whiteName = gameData['whitePlayerName'] ?? 'Guest';
      final blackName = gameData['blackPlayerName'] ?? 'Guest';
      final moveHistory = gameData['moveHistory'] ?? {};
      
      // Update game with final result
      await gameRef.update({
        'status': result,
        'winnerId': winnerId,
        'finishedAt': ServerValue.timestamp,
        'gameMethod': method,
      });
      
      // Prepare history record with move history
      final historyRecord = {
        'opponent': '', // Will be set per player
        'opponentId': '',
        'result': '',
        'method': method,
        'myColor': '',
        'finishedAt': ServerValue.timestamp,
        'gameId': roomId,
        'moveHistory': moveHistory, // Save the full DNA of the match
      };

      // Record in both players' history
      if (whiteId != null && whiteId != '') {
        await _recordPlayerGame(whiteId, roomId, blackId ?? 'ai', blackName == '' ? 'Dynamo AI' : blackName, PlayerColor.white, result, method, moveHistory: moveHistory);
      }
      if (blackId != null && blackId != '') {
        await _recordPlayerGame(blackId, roomId, whiteId ?? 'ai', whiteName == '' ? 'Dynamo AI' : whiteName, PlayerColor.black, result, method, moveHistory: moveHistory);
      }
    } catch (e) {
      print('ERROR recording game result: $e');
    }
  }

  /// Abort a game (Admin tool)
  Future<void> abortGame(String roomId) async {
    try {
      await _db.child('games').child(roomId).update({
        'status': 'aborted',
        'finishedAt': ServerValue.timestamp,
        'gameMethod': 'aborted_by_admin',
      });
    } catch (e) {
      print('Error aborting game: $e');
    }
  }

  // Record an offline or AI game result for the logged-in user
  Future<void> recordOfflineGame(String result, String method, String opponentName, PlayerColor myColor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final gameId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      await _recordPlayerGame(user.uid, gameId, 'offline_opp', opponentName, myColor, result, method, moveHistory: {}); // TODO: Pass moves for offline too
    } catch (e) {
      print('ERROR recording offline game: $e');
    }
  }

  Future<void> _recordPlayerGame(String playerId, String gameId, String opponentId, String opponentName, PlayerColor myColor, String gameResult, String method, {Map<dynamic, dynamic>? moveHistory}) async {
    try {
      print('=== RECORDING PLAYER GAME ===');
      print('PlayerId: $playerId');
      print('GameId: $gameId');
      print('OpponentId: $opponentId');
      print('OpponentName: $opponentName');
      print('MyColor: $myColor');
      print('GameResult: $gameResult');
      print('Method: $method');
      
      // Determine player result
      String playerResult;
      if (gameResult == 'draw') {
        playerResult = 'draw';
      } else if (gameResult == 'white_won') {
        playerResult = myColor == PlayerColor.white ? 'win' : 'loss';
      } else {  // black_won
        playerResult = myColor == PlayerColor.black ? 'win' : 'loss';
      }
      print('Player result: $playerResult');
      
      // Try to fetch opponent rating
      int? opponentRating;
      if (opponentId == 'ai' || opponentId == 'offline_opp') {
        opponentRating = 1200; // Default AI rating
      } else {
        try {
          final oppStats = await _db.child('users').child(opponentId).child('stats').get();
          if (oppStats.exists) {
            opponentRating = (oppStats.value as Map)['rating'] ?? 1200;
          } else {
            opponentRating = 1200;
          }
        } catch (_) {
          opponentRating = 1200;
        }
      }

      // Save to game history
      print('Saving to gameHistory/$playerId/$gameId');
      final historyData = {
        'opponent': opponentName,
        'opponentId': opponentId,
        'myColor': myColor == PlayerColor.white ? 'white' : 'black',
        'result': playerResult,
        'gameId': gameId,
        'method': method,
        'opponentRating': opponentRating,
        'finishedAt': ServerValue.timestamp,
        'moveHistory': moveHistory ?? {},
      };
      print('History data: $historyData');
      
      await _db.child('gameHistory').child(playerId).child(gameId).set(historyData);
      print('Game history saved successfully!');

      await _updateUserStats(playerId, playerResult, opponentRating: opponentRating);
      print('=== RECORDING COMPLETE ===');
    } catch (e) {
      print('ERROR recording player game: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _updateUserStats(String userId, String result, {int? opponentRating}) async {
    try {
      final statsRef = _db.child('users').child(userId).child('stats');
      final snapshot = await statsRef.get();
      
      Map<String, dynamic> stats = {
        'totalGames': 0,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'rating': 1200, // Default rating
      };
      
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        stats = {
          'totalGames': data['totalGames'] ?? 0,
          'wins': data['wins'] ?? 0,
          'losses': data['losses'] ?? 0,
          'draws': data['draws'] ?? 0,
          'rating': data['rating'] ?? 1200,
          'winStreak': data['winStreak'] ?? 0,
          'bestWin': data['bestWin'] ?? 0,
        };
      } else {
        stats['winStreak'] = 0;
        stats['bestWin'] = 0;
      }
      
      // Calculate Elo if opponent rating is provided
      int currentRating = stats['rating'];
      int newRating = currentRating;
      
      if (opponentRating != null) {
        double actualScore = (result == 'win') ? 1.0 : (result == 'draw' ? 0.5 : 0.0);
        double expectedScore = 1.0 / (1.0 + pow(10, (opponentRating - currentRating) / 400.0));
        int kFactor = 32;
        newRating = (currentRating + kFactor * (actualScore - expectedScore)).round();
      }

      stats['totalGames'] = stats['totalGames']! + 1;
      if (result == 'win') {
        stats['wins'] = stats['wins']! + 1;
        stats['winStreak'] = (stats['winStreak'] ?? 0) + 1;
        if (opponentRating != null && opponentRating > (stats['bestWin'] ?? 0)) {
          stats['bestWin'] = opponentRating;
        }
      } else if (result == 'loss') {
        stats['losses'] = stats['losses']! + 1;
        stats['winStreak'] = 0;
      } else if (result == 'draw') {
        stats['draws'] = stats['draws']! + 1;
        stats['winStreak'] = 0;
      }
      stats['rating'] = newRating;
      
      await statsRef.set(stats);
    } catch (e) {
      print('ERROR updating user stats: $e');
    }
  }

  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      final snapshot = await _db.child('users').child(userId).child('stats').get();
      
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        return {
          'totalGames': data['totalGames'] ?? 0,
          'wins': data['wins'] ?? 0,
          'losses': data['losses'] ?? 0,
          'draws': data['draws'] ?? 0,
          'rating': data['rating'] ?? 1200,
        };
      }
      
      return {'totalGames': 0, 'wins': 0, 'losses': 0, 'draws': 0, 'rating': 1200};
    } catch (e) {
      print('ERROR getting user stats: $e');
      return {'totalGames': 0, 'wins': 0, 'losses': 0, 'draws': 0, 'rating': 1200};
    }
  }

  Future<List<Map<String, dynamic>>> getGameHistory(String userId, {int limit = 100}) async {
    try {
      Query query = _db.child('gameHistory').child(userId).orderByChild('finishedAt');
      if (limit > 0) {
        query = query.limitToLast(limit);
      }
      final snapshot = await query.get();
      
      if (!snapshot.exists) return [];
      
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      List<Map<String, dynamic>> history = [];
      
      data.forEach((key, value) {
        final game = Map<dynamic, dynamic>.from(value as Map);
        history.add({
          'gameId': key,
          'opponent': game['opponent'] ?? 'Unknown',
          'opponentId': game['opponentId'],
          'myColor': game['myColor'] ?? 'white',
          'result': game['result'] ?? 'draw',
          'method': game['method'] ?? 'checkmate',
          'finishedAt': game['finishedAt'] ?? 0,
          'moveHistory': game['moveHistory'], // Include the tactical DNA
        });
      });
      
      // Sort by finishedAt descending (most recent first)
      history.sort((a, b) => (b['finishedAt'] as int).compareTo(a['finishedAt'] as int));
      
      return history;
    } catch (e) {
      print('ERROR getting game history: $e');
      return [];
    }
  }

  Future<void> updateUserProfile(String userId, String displayName, String email) async {
    try {
      final userRef = _db.child('users').child(userId);
      final snapshot = await userRef.get();
      
      if (!snapshot.exists) {
        // Create new profile
        await userRef.set({
          'displayName': displayName,
          'email': email,
          'createdAt': ServerValue.timestamp,
          'stats': {
            'totalGames': 0,
            'wins': 0,
            'losses': 0,
            'draws': 0,
            'rating': 1200,
          }
        });
      } else {
        // Update existing profile
        await userRef.update({
          'displayName': displayName,
          'email': email,
        });
      }
    } catch (e) {
      print('ERROR updating user profile: $e');
    }
  }
  
  
  String _generateRoomId() {
    var rng = Random();
    return (100000 + rng.nextInt(900000)).toString(); // 6 digit code
  }
  
  PlayerColor getMyColor(String whitePlayerId) {
    // If not logged in, this might crash, but createGame/joinGame enforces login
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return whitePlayerId == uid ? PlayerColor.white : PlayerColor.black;
  }
  
  // ================== USERNAME SYSTEM ==================
  
  // Check if username is already taken
  Future<bool> checkUsernameExists(String username) async {
    try {
      final snapshot = await _db.child('usernames').child(username.toLowerCase()).get();
      return snapshot.exists;
    } catch (e) {
      print('ERROR checking username: $e');
      return false;
    }
  }
  
  // Reserve username for a user (called during signup)
  Future<void> reserveUsername(String username, String uid) async {
    try {
      await _db.child('usernames').child(username.toLowerCase()).set({
        'uid': uid,
        'displayName': username,
        'createdAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('ERROR reserving username: $e');
    }
  }

  // Update username for an existing user
  Future<void> updateUsername(String oldUsername, String newUsername, String uid, String email) async {
    try {
      if (oldUsername.isNotEmpty) {
        await _db.child('usernames').child(oldUsername.toLowerCase()).remove();
      }
      await reserveUsername(newUsername, uid);
      await updateUserProfile(uid, newUsername, email);
    } catch (e) {
      print('ERROR updating username: $e');
    }
  }
  
  // Find user by username
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    try {
      final snapshot = await _db.child('usernames').child(username.toLowerCase()).get();
      if (!snapshot.exists) return null;
      
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final uid = data['uid'];
      
      // Get full user profile
      final userSnapshot = await _db.child('users').child(uid).get();
      if (!userSnapshot.exists) return null;
      
      final userData = Map<dynamic, dynamic>.from(userSnapshot.value as Map);
      
      return {
        'uid': uid,
        'username': username.toLowerCase(),
        'displayName': data['displayName'] ?? username,
        'email': userData['email'] ?? '',
      };
    } catch (e) {
      print('ERROR finding user: $e');
      return null;
    }
  }
  
  // ================== INVITATION SYSTEM ==================
  
  // Send game invitation to a user by username
  Future<String?> sendInvitationByUsername(String username, int timeControl) async {
    try {
      print('📨 Sending invitation to: $username');
      
      // 1. Find the user
      final targetUser = await findUserByUsername(username);
      if (targetUser == null) {
        throw 'User "$username" not found';
      }
      
      final currentUser = FirebaseAuth.instance.currentUser!;
      final fromUserId = currentUser.uid;
      final fromUserName = currentUser.displayName ?? 'Unknown';
      
      // 2. Create game room
    final roomId = _generateRoomId();
    print('📨 Creating game room: $roomId');
    await _db.child('games').child(roomId).set({
      'whitePlayerId': fromUserId,
      'whitePlayerName': fromUserName,
      'blackPlayerId': '',
      'blackPlayerName': '',
      'turn': 'white',
      'status': 'waiting',
      'whiteTime': timeControl,
      'blackTime': timeControl,
      'createdAt': ServerValue.timestamp,
    });
      
      // 3. Create invitation
      final inviteRef = _db.child('invitations').push();
      final inviteId = inviteRef.key!;
      
      await inviteRef.set({
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': targetUser['uid'],
        'toUserName': targetUser['displayName'],
        'roomId': roomId,
        'timeControl': timeControl,
        'status': 'pending',
        'createdAt': ServerValue.timestamp,
        'expiresAt': DateTime.now().add(Duration(minutes: 5)).millisecondsSinceEpoch,
      });
      
      print('📨 Invitation sent! ID: $inviteId');

      // Send push notification to the invited player
      try {
        final fcmToken = await FcmSenderService.getUserFcmToken(targetUser['uid']);
        if (fcmToken != null) {
          await FcmSenderService.sendToToken(
            token: fcmToken,
            title: 'New Challenge! ♟️',
            body: '$fromUserName invited you to a game!',
            data: {'type': 'invitation', 'roomId': roomId},
          );
        }
      } catch (pushError) {
        print('Push notification error (non-fatal): $pushError');
      }

      return inviteId;
    } catch (e) {
      print('ERROR sending invitation: $e');
      rethrow;
    }
  }
  
  // Listen for invitations sent to current user
  Stream<List<Map<String, dynamic>>> listenForInvitations(String userId) {
    return _db
        .child('invitations')
        .orderByChild('toUserId')
        .equalTo(userId)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      List<Map<String, dynamic>> invitations = [];
      
      data.forEach((key, value) {
        final invite = Map<dynamic, dynamic>.from(value);
        invitations.add({
          'id': key,
          'fromUserId': invite['fromUserId'],
          'fromUserName': invite['fromUserName'],
          'roomId': invite['roomId'],
          'timeControl': invite['timeControl'],
          'createdAt': invite['createdAt'],
          'expiresAt': invite['expiresAt'],
          'status': invite['status'] ?? 'pending',
        });
      });
      
      // Sort by most recent first
      invitations.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
      return invitations;
    });
  }
  
  // Accept an invitation and join the game
  Future<String> acceptInvitation(String inviteId) async {
    try {
      print('✅ Accepting invitation: $inviteId');
      
      final inviteRef = _db.child('invitations').child(inviteId);
      final snapshot = await inviteRef.get();
      
      if (!snapshot.exists) {
        throw 'Invitation not found';
      }
      
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final roomId = data['roomId'];
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      
      // Update invitation status
      await inviteRef.update({'status': 'accepted'});
      
      String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';
      // Join the game as black player
      await _db.child('games').child(roomId).update({
        'blackPlayerId': currentUserId,
        'blackPlayerName': myName,
        'status': 'playing',  // Game starts now
      });
      
      print('✅ Joined game: $roomId');
      return roomId;
    } catch (e) {
      print('ERROR accepting invitation: $e');
      rethrow;
    }
  }
  
  // Decline an invitation
  Future<void> declineInvitation(String inviteId) async {
    try {
      await _db.child('invitations').child(inviteId).update({'status': 'declined'});
      print('❌ Invitation declined');
    } catch (e) {
      print('ERROR declining invitation: $e');
    }
  }
  
  
  // Get room ID from invitation (for challenger to join)
  Future<String> getRoomIdFromInvitation(String inviteId) async {
    try {
      final snapshot = await _db.child('invitations').child(inviteId).get();
      if (!snapshot.exists) {
        throw 'Invitation not found';
      }
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return data['roomId'];
    } catch (e) {
      print('ERROR getting roomId from invitation: $e');
      rethrow;
    }
  }
  
  // Stream invitation status changes (for Player A to detect decline/expiry)
  Stream<String> getInvitationStatusStream(String inviteId) {
    return _db.child('invitations').child(inviteId).child('status').onValue.map((event) {
      if (event.snapshot.value == null) return 'unknown';
      return event.snapshot.value.toString();
    });
  }

  // --- CHAT SYSTEM ---

  /// Send a message in a game room
  Future<void> sendChatMessage(String roomId, String senderId, String senderName, String text) async {
    final chatRef = _db.child('games').child(roomId).child('chats').push();
    await chatRef.set({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Get real-time chat messages for a room
  Stream<DatabaseEvent> getChatStream(String roomId) {
    return _db.child('games').child(roomId).child('chats').orderByChild('timestamp').onChildAdded;
  }

  // Save FCM token for push notifications
  Future<void> saveFcmToken(String userId, String token) async {
    try {
      await _db.child('users').child(userId).child('fcmToken').set(token);
    } catch (e) {
      print('ERROR saving FCM token: $e');
    }
  }

  // --- GLOBAL BROADCAST SYSTEM ---

  /// Send a message to all online users
  Future<void> sendGlobalBroadcast(String message, String adminName, {String? imageUrl}) async {
    final broadcastRef = _db.child('broadcasts').push();
    await broadcastRef.set({
      'message': message,
      'admin': adminName,
      'timestamp': ServerValue.timestamp,
      'expiresAt': DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });

    // Send push notification to all users
    try {
      final tokens = await FcmSenderService.getAllFcmTokens();
      if (tokens.isNotEmpty) {
        await FcmSenderService.sendToMultiple(
          tokens: tokens,
          title: 'Announcement from $adminName',
          body: message,
          imageUrl: imageUrl,
        );
      }
    } catch (pushError) {
      print('Broadcast push error (non-fatal): $pushError');
    }
  }

  /// Listen for recent broadcasts
  Stream<Map<String, dynamic>?> listenForGlobalBroadcasts() {
    return _db.child('broadcasts').orderByChild('timestamp').limitToLast(1).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final key = data.keys.first;
      final broadcast = Map<String, dynamic>.from(data[key] as Map);
      
      // Check if it's expired
      final expiresAt = broadcast['expiresAt'] as int?;
      if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
        return null;
      }
      
      broadcast['id'] = key;
      return broadcast;
    });
  }
}


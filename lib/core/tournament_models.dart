import 'models.dart';

enum TournamentStatus {
  enrolling,
  active,
  completed,
  archived
}

enum TournamentType {
  swiss,
  arena,
  elimination
}

class TournamentParticipant {
  final String userId;
  final String name;
  final int rating;
  double score;
  double buchholz;
  List<String> opponents; // IDs of opponents faced
  List<PlayerColor> colors; // List of colors played (white, black)

  TournamentParticipant({
    required this.userId,
    required this.name,
    this.rating = 1500,
    this.score = 0.0,
    this.buchholz = 0.0,
    List<String>? opponents,
    List<PlayerColor>? colors,
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
  double? whiteScore; // 1, 0.5, or 0
  double? blackScore;
  final bool isCompleted;
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
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();
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
  final TournamentType type;
  final TournamentStatus status;
  final int totalRounds;
  final int currentRound;
  final List<TournamentParticipant> participants;
  final List<TournamentRound> rounds;
  final GameSettings settings;
  final int prizePool;
  final DateTime? autoStartAt;
  final DateTime? scheduledStartAt;
  final DateTime? nextEventAt;
  final int? restTimerSetForRound;

  Tournament({
    required this.id,
    required this.title,
    required this.description,
    this.type = TournamentType.swiss,
    this.status = TournamentStatus.enrolling,
    required this.totalRounds,
    this.currentRound = 0,
    required this.participants,
    required this.rounds,
    required this.settings,
    this.prizePool = 0,
    this.autoStartAt,
    this.scheduledStartAt,
    this.nextEventAt,
    this.restTimerSetForRound,
  });
}

import 'package:equatable/equatable.dart';

class PlayerStats extends Equatable {
  final int gamesPlayed;
  final int gamesWon;
  final int currentStreak;
  final int bestStreak;
  final int totalTimePlayed; // in seconds
  final int bestTimeEasy;
  final int bestTimeMedium;
  final int bestTimeHard;
  final Map<String, int> difficultyWins;
  final DateTime lastPlayedDate;

  const PlayerStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalTimePlayed = 0,
    this.bestTimeEasy = 0,
    this.bestTimeMedium = 0,
    this.bestTimeHard = 0,
    this.difficultyWins = const {},
    required this.lastPlayedDate,
  });

  double get winRate {
    if (gamesPlayed == 0) return 0.0;
    return (gamesWon / gamesPlayed) * 100;
  }

  factory PlayerStats.initial() {
    return PlayerStats(
      lastPlayedDate: DateTime.now(),
      difficultyWins: {
        'easy': 0,
        'medium': 0,
        'hard': 0,
      },
    );
  }

  PlayerStats copyWith({
    int? gamesPlayed,
    int? gamesWon,
    int? currentStreak,
    int? bestStreak,
    int? totalTimePlayed,
    int? bestTimeEasy,
    int? bestTimeMedium,
    int? bestTimeHard,
    Map<String, int>? difficultyWins,
    DateTime? lastPlayedDate,
  }) {
    return PlayerStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalTimePlayed: totalTimePlayed ?? this.totalTimePlayed,
      bestTimeEasy: bestTimeEasy ?? this.bestTimeEasy,
      bestTimeMedium: bestTimeMedium ?? this.bestTimeMedium,
      bestTimeHard: bestTimeHard ?? this.bestTimeHard,
      difficultyWins: difficultyWins ?? this.difficultyWins,
      lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
    );
  }

  @override
  List<Object?> get props => [
        gamesPlayed,
        gamesWon,
        currentStreak,
        bestStreak,
        totalTimePlayed,
        bestTimeEasy,
        bestTimeMedium,
        bestTimeHard,
        difficultyWins,
        lastPlayedDate,
      ];
}

import 'package:equatable/equatable.dart';
import 'sudoku_puzzle.dart';

enum GameStatus {
  idle,
  playing,
  paused,
  completed,
  failed,
}

class GameState extends Equatable {
  final SudokuPuzzle puzzle;
  final GameStatus status;
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
  final List<List<List<int>>> pencilMarks; // Pencil marks for each cell
  final List<GameMove> moveHistory;
  final int currentMoveIndex;
  final bool isPencilMode;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<GameState> history;
  final List<GameState> redoStack;


  const GameState({
    required this.puzzle,
    required this.status,
    this.elapsedSeconds = 0,
    this.mistakes = 0,
    this.hintsUsed = 0,
    required this.pencilMarks,
    this.moveHistory = const [],
    this.currentMoveIndex = -1,
    this.isPencilMode = false,
    this.startTime,
    this.endTime,
    this.history = const [],
    this.redoStack = const [],
  });

  factory GameState.initial(SudokuPuzzle puzzle) {
    return GameState(
      puzzle: puzzle,
      status: GameStatus.idle,
      pencilMarks: List.generate(
        9,
        (_) => List.generate(9, (_) => <int>[]),
      ),
    );
  }

  bool get canUndo => currentMoveIndex >= 0;
  bool get canRedo => currentMoveIndex < moveHistory.length - 1;
  bool get isGameOver => status == GameStatus.completed || status == GameStatus.failed;

  GameState copyWith({
    SudokuPuzzle? puzzle,
    GameStatus? status,
    int? elapsedSeconds,
    int? mistakes,
    int? hintsUsed,
    List<List<List<int>>>? pencilMarks,
    List<GameMove>? moveHistory,
    int? currentMoveIndex,
    bool? isPencilMode,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return GameState(
      puzzle: puzzle ?? this.puzzle,
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      mistakes: mistakes ?? this.mistakes,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      pencilMarks: pencilMarks ?? this.pencilMarks,
      moveHistory: moveHistory ?? this.moveHistory,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      isPencilMode: isPencilMode ?? this.isPencilMode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props => [
        puzzle,
        status,
        elapsedSeconds,
        mistakes,
        hintsUsed,
        pencilMarks,
        moveHistory,
        currentMoveIndex,
        isPencilMode,
        startTime,
        endTime,
      ];
  
}

class GameMove extends Equatable {
  final int row;
  final int col;
  final int? previousValue;
  final int? newValue;
  final List<int>? previousPencilMarks;
  final List<int>? newPencilMarks;
  final DateTime timestamp;

  const GameMove({
    required this.row,
    required this.col,
    this.previousValue,
    this.newValue,
    this.previousPencilMarks,
    this.newPencilMarks,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        row,
        col,
        previousValue,
        newValue,
        previousPencilMarks,
        newPencilMarks,
        timestamp,
      ];
}

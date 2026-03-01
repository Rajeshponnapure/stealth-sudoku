import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/entities/sudoku_puzzle.dart';
import '../../../../core/utils/sudoku_generator.dart';
import '../../../../core/constants/app_constants.dart';

final sudokuGeneratorProvider = Provider((ref) => SudokuGenerator());

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier(ref.watch(sudokuGeneratorProvider));
});

class GameNotifier extends StateNotifier<GameState> {
  final SudokuGenerator _generator;
  Timer? _timer;

  GameNotifier(this._generator) : super(GameState.initial(SudokuPuzzle.empty()));

  // Start new game
  void startNewGame(String difficulty) {
    final result = _generator.generatePuzzle(difficulty);
    final puzzle = SudokuPuzzle(
      grid: result['puzzle'],
      solution: result['solution'],
      isFixed: result['isFixed'],
      difficulty: difficulty,
      createdAt: DateTime.now(),
    );

    state = GameState.initial(puzzle).copyWith(
      status: GameStatus.playing,
      startTime: DateTime.now(),
    );

    _startTimer();
  }

  // Make a move
  void makeMove(int row, int col, int value) {
    if (state.puzzle.isFixed[row][col]) return;
    if (state.isGameOver) return;

    final newGrid = state.puzzle.grid.map((r) => List<int>.from(r)).toList();
    final previousValue = newGrid[row][col];
    newGrid[row][col] = value;

    final move = GameMove(
      row: row,
      col: col,
      previousValue: previousValue,
      newValue: value,
      timestamp: DateTime.now(),
    );

    // Check if move is incorrect
    int newMistakes = state.mistakes;
    if (value != 0 && value != state.puzzle.solution[row][col]) {
      newMistakes++;
    }

    final newPuzzle = state.puzzle.copyWith(grid: newGrid);
    final newHistory = state.moveHistory.sublist(0, state.currentMoveIndex + 1);
    newHistory.add(move);

    state = state.copyWith(
      puzzle: newPuzzle,
      mistakes: newMistakes,
      moveHistory: newHistory,
      currentMoveIndex: newHistory.length - 1,
    );

    // Check if game is complete
    if (_isComplete() && _isCorrect()) {
      _onGameWon();
    } else if (newMistakes >= AppConstants.maxMistakes) {
      _onGameLost();
    }
  }

  // Toggle pencil mode
  void togglePencilMode() {
    state = state.copyWith(isPencilMode: !state.isPencilMode);
  }

  // Add/remove pencil mark
  void togglePencilMark(int row, int col, int number) {
    if (state.puzzle.isFixed[row][col]) return;
    if (state.puzzle.grid[row][col] != 0) return;

    final newMarks = state.pencilMarks.map((r) =>
      r.map((c) => List<int>.from(c)).toList()
    ).toList();

    if (newMarks[row][col].contains(number)) {
      newMarks[row][col].remove(number);
    } else {
      newMarks[row][col].add(number);
      newMarks[row][col].sort();
    }

    state = state.copyWith(pencilMarks: newMarks);
  }

  // Undo move
  void undo() {
    if (!state.canUndo) return;

    final move = state.moveHistory[state.currentMoveIndex];
    final newGrid = state.puzzle.grid.map((r) => List<int>.from(r)).toList();
    newGrid[move.row][move.col] = move.previousValue ?? 0;

    final newPuzzle = state.puzzle.copyWith(grid: newGrid);

    state = state.copyWith(
      puzzle: newPuzzle,
      currentMoveIndex: state.currentMoveIndex - 1,
    );
  }

  // Redo move
  void redo() {
    if (!state.canRedo) return;

    final move = state.moveHistory[state.currentMoveIndex + 1];
    final newGrid = state.puzzle.grid.map((r) => List<int>.from(r)).toList();
    newGrid[move.row][move.col] = move.newValue ?? 0;

    final newPuzzle = state.puzzle.copyWith(grid: newGrid);

    state = state.copyWith(
      puzzle: newPuzzle,
      currentMoveIndex: state.currentMoveIndex + 1,
    );
  }

  // Use hint
  void useHint() {
    final hint = _generator.getHint(state.puzzle.grid, state.puzzle.solution);
    if (hint == null) return;

    final row = hint['row']!;
    final col = hint['col']!;
    final value = state.puzzle.solution[row][col];

    makeMove(row, col, value);
    state = state.copyWith(hintsUsed: state.hintsUsed + 1);
  }

  // Pause game
  void pauseGame() {
    _timer?.cancel();
    state = state.copyWith(status: GameStatus.paused);
  }

  // Resume game
  void resumeGame() {
    _startTimer();
    state = state.copyWith(status: GameStatus.playing);
  }

  // Clear cell
  void clearCell(int row, int col) {
    makeMove(row, col, 0);
  }

  // Private methods
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == GameStatus.playing) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
    });
  }

  bool _isComplete() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (state.puzzle.grid[i][j] == 0) return false;
      }
    }
    return true;
  }

  bool _isCorrect() {
    return _generator.isPuzzleSolved(
      state.puzzle.grid,
      state.puzzle.solution,
    );
  }

  void _onGameWon() {
    _timer?.cancel();
    state = state.copyWith(
      status: GameStatus.completed,
      endTime: DateTime.now(),
    );
  }

  void _onGameLost() {
    _timer?.cancel();
    state = state.copyWith(
      status: GameStatus.failed,
      endTime: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

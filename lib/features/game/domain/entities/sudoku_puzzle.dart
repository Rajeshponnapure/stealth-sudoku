import 'package:equatable/equatable.dart';

class SudokuPuzzle extends Equatable {
  final List<List<int>> grid;
  final List<List<int>> solution;
  final List<List<bool>> isFixed;
  final String difficulty;
  final DateTime createdAt;
  final String? id;

  const SudokuPuzzle({
    required this.grid,
    required this.solution,
    required this.isFixed,
    required this.difficulty,
    required this.createdAt,
    this.id,
  });

  // Create empty puzzle
  factory SudokuPuzzle.empty() {
    final emptyGrid = List.generate(9, (_) => List.filled(9, 0));
    return SudokuPuzzle(
      grid: emptyGrid,
      solution: emptyGrid,
      isFixed: List.generate(9, (_) => List.filled(9, false)),
      difficulty: 'medium',
      createdAt: DateTime.now(),
    );
  }

  // Check if puzzle is complete
  bool get isComplete {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] == 0) return false;
      }
    }
    return true;
  }

  // Check if puzzle is correct
  bool get isCorrect {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] != solution[i][j]) return false;
      }
    }
    return true;
  }

  // Get remaining numbers for each digit
  Map<int, int> get remainingNumbers {
    final counts = <int, int>{};
    for (int num = 1; num <= 9; num++) {
      counts[num] = 9;
    }

    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] != 0) {
          counts[grid[i][j]] = counts[grid[i][j]]! - 1;
        }
      }
    }

    return counts;
  }

  // Copy with modifications
  SudokuPuzzle copyWith({
    List<List<int>>? grid,
    List<List<int>>? solution,
    List<List<bool>>? isFixed,
    String? difficulty,
    DateTime? createdAt,
    String? id,
  }) {
    return SudokuPuzzle(
      grid: grid ?? this.grid.map((row) => List<int>.from(row)).toList(),
      solution: solution ?? this.solution.map((row) => List<int>.from(row)).toList(),
      isFixed: isFixed ?? this.isFixed.map((row) => List<bool>.from(row)).toList(),
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
    );
  }

  @override
  List<Object?> get props => [grid, solution, isFixed, difficulty, createdAt, id];
}

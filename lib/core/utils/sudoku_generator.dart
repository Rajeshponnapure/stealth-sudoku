import 'dart:math';

class SudokuGenerator {
  final Random _random = Random();

  // Generate a complete valid Sudoku puzzle
  List<List<int>> generateComplete() {
    final grid = List.generate(9, (_) => List.filled(9, 0));
    _fillDiagonalBoxes(grid);
    _solveSudoku(grid);
    return grid;
  }

  // Generate puzzle with specified difficulty
  Map<String, dynamic> generatePuzzle(String difficulty) {
    final solution = generateComplete();
    final puzzle = solution.map((row) => List<int>.from(row)).toList();
    
    int cellsToRemove;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        cellsToRemove = 38;
        break;
      case 'hard':
        cellsToRemove = 55;
        break;
      case 'medium':
      default:
        cellsToRemove = 47;
    }

    _removeCells(puzzle, cellsToRemove);

    final isFixed = List.generate(9, (i) => 
      List.generate(9, (j) => puzzle[i][j] != 0)
    );

    return {
      'puzzle': puzzle,
      'solution': solution,
      'isFixed': isFixed,
    };
  }

  // Fill diagonal 3x3 boxes (they are independent)
  void _fillDiagonalBoxes(List<List<int>> grid) {
    for (int box = 0; box < 9; box += 3) {
      _fillBox(grid, box, box);
    }
  }

  // Fill a 3x3 box
  void _fillBox(List<List<int>> grid, int row, int col) {
    final numbers = List.generate(9, (i) => i + 1)..shuffle(_random);
    int index = 0;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        grid[row + i][col + j] = numbers[index++];
      }
    }
  }

  // Solve Sudoku using backtracking
  bool _solveSudoku(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          final numbers = List.generate(9, (i) => i + 1)..shuffle(_random);
          for (int num in numbers) {
            if (_isSafe(grid, row, col, num)) {
              grid[row][col] = num;
              if (_solveSudoku(grid)) {
                return true;
              }
              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  // Check if placing a number is safe
  bool _isSafe(List<List<int>> grid, int row, int col, int num) {
    // Check row
    for (int x = 0; x < 9; x++) {
      if (grid[row][x] == num) return false;
    }

    // Check column
    for (int x = 0; x < 9; x++) {
      if (grid[x][col] == num) return false;
    }

    // Check 3x3 box
    int startRow = row - row % 3;
    int startCol = col - col % 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (grid[i + startRow][j + startCol] == num) return false;
      }
    }

    return true;
  }

  // Remove cells to create puzzle
  void _removeCells(List<List<int>> grid, int count) {
    int removed = 0;
    while (removed < count) {
      int row = _random.nextInt(9);
      int col = _random.nextInt(9);
      if (grid[row][col] != 0) {
        grid[row][col] = 0;
        removed++;
      }
    }
  }

  // Validate if move is correct
  bool isValidMove(List<List<int>> grid, int row, int col, int num) {
    return _isSafe(grid, row, col, num);
  }

  // Check if puzzle is solved correctly
  bool isPuzzleSolved(List<List<int>> grid, List<List<int>> solution) {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] != solution[i][j]) return false;
      }
    }
    return true;
  }

  // Get hint (reveal one cell)
  Map<String, int>? getHint(List<List<int>> puzzle, List<List<int>> solution) {
    final emptyCells = <Map<String, int>>[];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (puzzle[i][j] == 0) {
          emptyCells.add({'row': i, 'col': j});
        }
      }
    }
    if (emptyCells.isEmpty) return null;
    return emptyCells[_random.nextInt(emptyCells.length)];
  }
}

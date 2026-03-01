import 'package:flutter/material.dart';
import '../../domain/entities/sudoku_puzzle.dart';
import '../../../../core/theme/app_theme.dart';

class SudokuGrid extends StatefulWidget {
  final SudokuPuzzle puzzle;
  final List<List<List<int>>> pencilMarks;
  final int? selectedRow;
  final int? selectedCol;
  final bool highlightEnabled;
  final Function(int row, int col) onCellTap;

  const SudokuGrid({
    super.key,
    required this.puzzle,
    required this.pencilMarks,
    this.selectedRow,
    this.selectedCol,
    this.highlightEnabled = true,
    required this.onCellTap,
  });

  @override
  State<SudokuGrid> createState() => _SudokuGridState();
}

class _SudokuGridState extends State<SudokuGrid> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white70 : Colors.black87,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: List.generate(9, (row) {
              return Expanded(
                child: Row(
                  children: List.generate(9, (col) {
                    return Expanded(
                      child: _buildCell(context, row, col, isDark),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(BuildContext context, int row, int col, bool isDark) {
    final value = widget.puzzle.grid[row][col];
    final isFixed = widget.puzzle.isFixed[row][col];
    final isSelected = widget.selectedRow == row && widget.selectedCol == col;
    final isHighlighted = widget.highlightEnabled && _shouldHighlight(row, col);
    final isSameNumber = widget.highlightEnabled && 
                         value != 0 && 
                         widget.selectedRow != null && 
                         widget.selectedCol != null &&
                         value == widget.puzzle.grid[widget.selectedRow!][widget.selectedCol!];
    
    final isCorrect = value != 0 && value == widget.puzzle.solution[row][col];
    final isIncorrect = value != 0 && value != widget.puzzle.solution[row][col];

    return GestureDetector(
      onTap: () => widget.onCellTap(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: _getCellColor(isSelected, isHighlighted, isSameNumber, isDark),
          border: _getCellBorder(row, col, isDark),
        ),
        child: Center(
          child: value == 0
              ? _buildPencilMarks(row, col, isDark)
              : _buildNumber(value, isFixed, isCorrect, isIncorrect, isDark),
        ),
      ),
    );
  }

  Widget _buildNumber(int value, bool isFixed, bool isCorrect, bool isIncorrect, bool isDark) {
    Color textColor;
    if (isFixed) {
      textColor = isDark ? Colors.white : Colors.black87;
    } else if (isIncorrect) {
      textColor = isDark ? AppTheme.incorrectDark : AppTheme.incorrectLight;
    } else {
      textColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
    }

    return Text(
      value.toString(),
      style: TextStyle(
        fontSize: 24,
        fontWeight: isFixed ? FontWeight.bold : FontWeight.w600,
        color: textColor,
      ),
    );
  }

  Widget _buildPencilMarks(int row, int col, bool isDark) {
    final marks = widget.pencilMarks[row][col];
    if (marks.isEmpty) return const SizedBox();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        final number = index + 1;
        final hasMark = marks.contains(number);
        return Center(
          child: Text(
            hasMark ? number.toString() : '',
            style: TextStyle(
              fontSize: 10,
              color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Color _getCellColor(bool isSelected, bool isHighlighted, bool isSameNumber, bool isDark) {
    if (isSelected) {
      return isDark 
          ? AppTheme.primaryDark.withValues(alpha: 0.3)
          : AppTheme.primaryLight.withValues(alpha: 0.2);
    }
    if (isSameNumber) {
      return isDark
          ? AppTheme.primaryDark.withValues(alpha: 0.15)
          : AppTheme.primaryLight.withValues(alpha: 0.1);
    }
    if (isHighlighted) {
      return isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.1);
    }
    return Colors.transparent;
  }

  Border _getCellBorder(int row, int col, bool isDark) {
    final normalColor = isDark ? Colors.white24 : Colors.black26;
    final thickColor = isDark ? Colors.white54 : Colors.black54;

    return Border(
      top: BorderSide(
        color: row % 3 == 0 ? thickColor : normalColor,
        width: row % 3 == 0 ? 2 : 0.5,
      ),
      left: BorderSide(
        color: col % 3 == 0 ? thickColor : normalColor,
        width: col % 3 == 0 ? 2 : 0.5,
      ),
      right: BorderSide(
        color: col == 8 ? thickColor : Colors.transparent,
        width: col == 8 ? 2 : 0,
      ),
      bottom: BorderSide(
        color: row == 8 ? thickColor : Colors.transparent,
        width: row == 8 ? 2 : 0,
      ),
    );
  }

  bool _shouldHighlight(int row, int col) {
    if (widget.selectedRow == null || widget.selectedCol == null) return false;
    return row == widget.selectedRow || col == widget.selectedCol;
  }
}

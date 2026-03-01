import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/game_state.dart';
import '../providers/game_provider.dart';
import '../widgets/sudoku_grid.dart';
import '../widgets/number_pad.dart';
import '../widgets/game_timer.dart';
import '../widgets/game_controls.dart';
import '../widgets/win_animation.dart';

class GamePage extends ConsumerStatefulWidget {
  final String difficulty;

  const GamePage({super.key, required this.difficulty});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  int? selectedRow;
  int? selectedCol;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProvider.notifier).startNewGame(widget.difficulty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final screenSize = MediaQuery.of(context).size;

    return WinAnimation(
      show: gameState.status == GameStatus.completed,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_capitalize(widget.difficulty)} Sudoku'),
          actions: [
            GameTimer(elapsedSeconds: gameState.elapsedSeconds),
            const SizedBox(width: 16),
            _buildMistakesCounter(gameState.mistakes),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Sudoku Grid - responsive sizing
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: screenSize.width - 32,
                        maxHeight: screenSize.height * 0.55,
                      ),
                      child: SudokuGrid(
                        puzzle: gameState.puzzle,
                        pencilMarks: gameState.pencilMarks,
                        selectedRow: selectedRow,
                        selectedCol: selectedCol,
                        onCellTap: _onCellTap,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GameControls(
                  canUndo: gameState.canUndo,
                  canRedo: gameState.canRedo,
                  onUndo: () => ref.read(gameProvider.notifier).undo(),
                  onRedo: () => ref.read(gameProvider.notifier).redo(),
                  onHint: () => ref.read(gameProvider.notifier).useHint(),
                  onRestart: _showRestartDialog,
                ),
              ),
              
              // Number Pad
              NumberPad(
                remainingNumbers: gameState.puzzle.remainingNumbers,
                isPencilMode: gameState.isPencilMode,
                onNumberTap: _onNumberTap,
                onPencilToggle: () => ref.read(gameProvider.notifier).togglePencilMode(),
                onDelete: _onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCellTap(int row, int col) {
    if (ref.read(gameProvider).isGameOver) return;
    
    setState(() {
      selectedRow = row;
      selectedCol = col;
    });
  }

  void _onNumberTap(int number) {
    if (selectedRow == null || selectedCol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a cell first'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    if (ref.read(gameProvider).isGameOver) return;

    final gameNotifier = ref.read(gameProvider.notifier);
    
    if (ref.read(gameProvider).isPencilMode) {
      gameNotifier.togglePencilMark(selectedRow!, selectedCol!, number);
    } else {
      gameNotifier.makeMove(selectedRow!, selectedCol!, number);
    }
  }

  void _onDelete() {
    if (selectedRow == null || selectedCol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a cell first'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    ref.read(gameProvider.notifier).clearCell(selectedRow!, selectedCol!);
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Game?'),
        content: const Text('Are you sure you want to restart? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.pop();
              ref.read(gameProvider.notifier).startNewGame(widget.difficulty);
              setState(() {
                selectedRow = null;
                selectedCol = null;
              });
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Widget _buildMistakesCounter(int mistakes) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 20),
        const SizedBox(width: 4),
        Text(
          '$mistakes/3',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _capitalize(String text) {
    return text[0].toUpperCase() + text.substring(1);
  }
}

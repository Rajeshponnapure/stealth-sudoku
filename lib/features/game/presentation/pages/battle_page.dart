import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class BattlePage extends ConsumerStatefulWidget {
  const BattlePage({super.key});

  @override
  ConsumerState<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends ConsumerState<BattlePage> {
  int _playerProgress = 0;
  int _aiProgress = 0;
  Timer? _aiTimer;
  Timer? _gameTimer;
  int _elapsedSeconds = 0;
  bool _gameStarted = false;
  bool _gameOver = false;
  String? _winner;

  @override
  void dispose() {
    _aiTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startBattle() {
    setState(() {
      _playerProgress = 0;
      _aiProgress = 0;
      _elapsedSeconds = 0;
      _gameStarted = true;
      _gameOver = false;
      _winner = null;
    });

    // AI timer - completes in 60-90 seconds
    _aiTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_gameOver) {
        timer.cancel();
        return;
      }

      setState(() {
        _aiProgress += 2;
        if (_aiProgress >= 100) {
          _aiProgress = 100;
          _endGame('AI');
          timer.cancel();
        }
      });
    });

    // Game timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _simulatePlayerMove() {
    if (_gameOver || !_gameStarted) return;

    setState(() {
      _playerProgress += 5;
      if (_playerProgress >= 100) {
        _playerProgress = 100;
        _endGame('Player');
      }
    });
  }

  void _endGame(String winner) {
    setState(() {
      _gameOver = true;
      _winner = winner;
    });
    _aiTimer?.cancel();
    _gameTimer?.cancel();

    _showResultDialog();
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_winner == 'Player' ? '🎉 You Won!' : '😔 AI Won!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _winner == 'Player'
                  ? 'Congratulations! You beat the AI!'
                  : 'Better luck next time!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Time: ${_elapsedSeconds}s',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              context.pop();
            },
            child: const Text('Back to Home'),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              _startBattle();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Battle Mode'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Timer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '${_elapsedSeconds ~/ 60}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Player Progress
              _buildProgressBar(
                label: 'You',
                progress: _playerProgress,
                color: Colors.blue,
                icon: Icons.person,
              ),

              const SizedBox(height: 24),

              // AI Progress
              _buildProgressBar(
                label: 'AI',
                progress: _aiProgress,
                color: Colors.red,
                icon: Icons.smart_toy,
              ),

              const Spacer(),

              // Game Board Placeholder (tap to simulate moves)
              if (_gameStarted && !_gameOver)
                GestureDetector(
                  onTap: _simulatePlayerMove,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha:0.1),
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app, size: 48, color: Colors.blue),
                          SizedBox(height: 8),
                          Text(
                            'Tap to solve puzzle!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '(Each tap = 5% progress)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // Start Button
              if (!_gameStarted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startBattle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.primaryDark
                          : AppTheme.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Start Battle!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required int progress,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '$progress%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 20,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

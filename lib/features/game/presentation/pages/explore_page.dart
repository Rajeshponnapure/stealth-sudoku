import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  int _selectedCategory = 0;

  final List<PuzzlePack> _puzzlePacks = [
    PuzzlePack(
      title: 'Daily Challenge',
      subtitle: 'New puzzle every day',
      icon: Icons.today,
      color: Colors.orange,
      puzzleCount: 1,
      isDaily: true,
    ),
    PuzzlePack(
      title: 'Classic Collection',
      subtitle: '50 traditional puzzles',
      icon: Icons.grid_4x4,
      color: Colors.blue,
      puzzleCount: 50,
    ),
    PuzzlePack(
      title: 'Speed Run',
      subtitle: 'Beat the clock!',
      icon: Icons.speed,
      color: Colors.red,
      puzzleCount: 30,
    ),
    PuzzlePack(
      title: 'Expert Mode',
      subtitle: 'For Sudoku masters',
      icon: Icons.emoji_events,
      color: Colors.purple,
      puzzleCount: 25,
    ),
    PuzzlePack(
      title: 'Beginner Friendly',
      subtitle: 'Learn the basics',
      icon: Icons.school,
      color: Colors.green,
      puzzleCount: 40,
    ),
    PuzzlePack(
      title: 'Pattern Puzzles',
      subtitle: 'Unique layouts',
      icon: Icons.auto_awesome,
      color: Colors.pink,
      puzzleCount: 20,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Puzzles'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Tabs
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('All', 0, isDark),
                  _buildCategoryChip('Daily', 1, isDark),
                  _buildCategoryChip('Classic', 2, isDark),
                  _buildCategoryChip('Challenge', 3, isDark),
                ],
              ),
            ),

            // Puzzle Packs Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _puzzlePacks.length,
                itemBuilder: (context, index) {
                  final pack = _puzzlePacks[index];
                  return _buildPuzzlePackCard(pack, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, int index, bool isDark) {
    final isSelected = _selectedCategory == index;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = index;
          });
        },
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        selectedColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildPuzzlePackCard(PuzzlePack pack, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _openPuzzlePack(pack),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: pack.color.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  pack.icon,
                  size: 36,
                  color: pack.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                pack.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                pack.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pack.color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pack.color),
                ),
                child: Text(
                  '${pack.puzzleCount} puzzles',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pack.color,
                  ),
                ),
              ),
              if (pack.isDaily)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  void _openPuzzlePack(PuzzlePack pack) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pack.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pack.subtitle),
            const SizedBox(height: 16),
            Text(
              '${pack.puzzleCount} puzzles available',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select difficulty:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening ${pack.title}...'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }
}

class PuzzlePack {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int puzzleCount;
  final bool isDaily;

  PuzzlePack({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.puzzleCount,
    this.isDaily = false,
  });
}

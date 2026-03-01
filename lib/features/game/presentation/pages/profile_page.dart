import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection_container.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsService = ref.watch(preferencesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: FutureBuilder<List<int>>(
        future: Future.wait([
          prefsService.getGamesPlayed(),
          prefsService.getGamesWon(),
          prefsService.getCurrentStreak(),
          prefsService.getBestStreak(),
        ]),
        builder: (context, AsyncSnapshot<List<int>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final gamesPlayed = snapshot.data![0];
          final gamesWon = snapshot.data![1];
          final currentStreak = snapshot.data![2];
          final bestStreak = snapshot.data![3];
          final winRate = gamesPlayed > 0
              ? ((gamesWon / gamesPlayed) * 100).toStringAsFixed(1)
              : '0.0';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 24),
                _buildStatsGrid(
                    gamesPlayed, gamesWon, winRate, currentStreak, bestStreak),
                const SizedBox(height: 24),
                _buildAchievements(),
                const SizedBox(height: 40), // Extra padding at bottom
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sudoku Master',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Playing since ${DateTime.now().year}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
      int played, int won, String winRate, int current, int best) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4, // ✅ Increased from 1.5 to give more height
      children: [
        _StatCard(
          icon: Icons.videogame_asset,
          label: 'Games Played',
          value: played.toString(),
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.emoji_events,
          label: 'Games Won',
          value: won.toString(),
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.percent,
          label: 'Win Rate',
          value: '$winRate%',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.local_fire_department,
          label: 'Current Streak',
          value: current.toString(),
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildAchievements() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Achievements',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const _AchievementTile(
              icon: Icons.star,
              title: 'First Win',
              subtitle: 'Win your first game',
              unlocked: true,
            ),
            const _AchievementTile(
              icon: Icons.flash_on,
              title: 'Speed Demon',
              subtitle: 'Complete a game in under 5 minutes',
              unlocked: false,
            ),
            const _AchievementTile(
              icon: Icons.trending_up,
              title: 'Win Streak',
              subtitle: 'Win 5 games in a row',
              unlocked: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12), // ✅ Reduced padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // ✅ Added this
          children: [
            Icon(icon, size: 28, color: color), // ✅ Smaller icon
            const SizedBox(height: 6), // ✅ Smaller spacing
            Flexible( // ✅ Wrapped in Flexible
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22, // ✅ Slightly smaller font
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2), // ✅ Smaller spacing
            Flexible( // ✅ Wrapped in Flexible
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2, // ✅ Allow 2 lines
                style: const TextStyle(
                  fontSize: 11, // ✅ Smaller font
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool unlocked;

  const _AchievementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: unlocked ? Colors.amber : Colors.grey.shade300,
        child: Icon(
          icon,
          color: unlocked ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: unlocked ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: unlocked
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.lock, color: Colors.grey, size: 20),
    );
  }
}

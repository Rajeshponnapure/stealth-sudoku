import 'package:flutter/material.dart';

class GameControls extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onHint;
  final VoidCallback onRestart;

  const GameControls({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onHint,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: Icons.undo,
          label: 'Undo',
          enabled: canUndo,
          onTap: onUndo,
        ),
        _ControlButton(
          icon: Icons.redo,
          label: 'Redo',
          enabled: canRedo,
          onTap: onRedo,
        ),
        _ControlButton(
          icon: Icons.lightbulb_outline,
          label: 'Hint',
          onTap: onHint,
        ),
        _ControlButton(
          icon: Icons.refresh,
          label: 'Restart',
          onTap: onRestart,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled
                    ? Theme.of(context).textTheme.bodyMedium?.color
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

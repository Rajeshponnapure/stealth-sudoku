import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class NumberPad extends StatelessWidget {
  final Map<int, int> remainingNumbers;
  final bool isPencilMode;
  final Function(int) onNumberTap;
  final VoidCallback onPencilToggle;
  final VoidCallback onDelete;

  const NumberPad({
    super.key,
    required this.remainingNumbers,
    required this.isPencilMode,
    required this.onNumberTap,
    required this.onPencilToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Number buttons in a single row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(9, (index) {
              final number = index + 1;
              final remaining = remainingNumbers[number] ?? 0;
              final isDisabled = remaining == 0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _NumberButton(
                    number: number,
                    remaining: remaining,
                    isDisabled: isDisabled,
                    onTap: () => onNumberTap(number),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Pencil',
                  isActive: isPencilMode,
                  onTap: onPencilToggle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.backspace_outlined,
                  label: 'Delete',
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final int number;
  final int remaining;
  final bool isDisabled;
  final VoidCallback onTap;

  const _NumberButton({
    required this.number,
    required this.remaining,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDisabled
          ? (isDark ? Colors.grey[800] : Colors.grey[300])
          : (isDark ? AppTheme.primaryDark.withValues(alpha: 0.2) : AppTheme.primaryLight.withValues(alpha: 0.1)),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDisabled
                  ? Colors.transparent
                  : (isDark ? AppTheme.primaryDark : AppTheme.primaryLight),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  number.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDisabled
                        ? (isDark ? Colors.grey[600] : Colors.grey[400])
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              if (remaining < 9 && !isDisabled)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      remaining.toString(),
                      style: const TextStyle(
                        fontSize: 8,
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isActive
          ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
          : (isDark ? Colors.grey[800] : Colors.grey[200]),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

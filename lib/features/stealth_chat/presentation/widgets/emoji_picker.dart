import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;

class EmojiPickerWidget extends StatelessWidget {
  final TextEditingController controller;

  const EmojiPickerWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 280,
      child: EmojiPicker(
        textEditingController: controller,  // ✅ auto-inserts emoji into field
        config: Config(
          height: 280,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 28 *
                (foundation.defaultTargetPlatform == TargetPlatform.iOS
                    ? 1.20
                    : 1.0),
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            indicatorColor: Theme.of(context).primaryColor,
            iconColorSelected: Theme.of(context).primaryColor,
            iconColor: Colors.grey,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            buttonColor: Theme.of(context).primaryColor,
            buttonIconColor: Colors.white,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            buttonIconColor: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

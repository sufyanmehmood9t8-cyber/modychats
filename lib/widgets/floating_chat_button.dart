import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FloatingChatButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const FloatingChatButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.accentCoral,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCoral.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () {},
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      color: AppColors.accentCoral,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

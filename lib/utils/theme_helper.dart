import 'package:flutter/material.dart';

/// Helper class để dễ dàng truy cập theme colors và styles
/// Sử dụng: final colors = AppColors.of(context);
class AppColors {
  final BuildContext context;

  AppColors.of(this.context);

  // Color Scheme
  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  // Primary colors
  Color get primary => colorScheme.primary;
  Color get secondary => colorScheme.secondary;
  Color get tertiary => colorScheme.tertiary;

  // Surface colors
  Color get surface => colorScheme.surface;
  Color get surfaceVariant => colorScheme.surfaceContainerHighest;
  Color get background => Theme.of(context).scaffoldBackgroundColor;

  // Text colors
  Color get textPrimary => colorScheme.onSurface;
  Color get textSecondary => colorScheme.onSurfaceVariant;
  Color get textOnPrimary => colorScheme.onPrimary;

  // Border & Divider
  Color get border => colorScheme.outline;
  Color get divider => Theme.of(context).dividerColor;

  // Shadow
  Color get shadow => colorScheme.shadow;

  // Error
  Color get error => colorScheme.error;
  Color get onError => colorScheme.onError;

  // Check if dark mode
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
}

/// Extension for easier access to theme
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  AppColors get colors => AppColors.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Helper for creating cards with proper elevation and shadow
class ThemedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? elevation;
  final BorderRadius? borderRadius;

  const ThemedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
            blurRadius: elevation ?? (isDark ? 8 : 10),
            offset: Offset(0, elevation ?? (isDark ? 3 : 4)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

    return card;
  }
}

/// Helper for creating elevated buttons with proper styling
class ThemedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final bool isOutlined;

  const ThemedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor ?? context.colorScheme.primary,
          side: BorderSide(
            color: foregroundColor ?? context.colorScheme.primary,
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? context.colorScheme.primary,
          foregroundColor: foregroundColor ?? Colors.white,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: context.isDark ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? context.colorScheme.primary,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: context.isDark ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(text),
    );
  }
}


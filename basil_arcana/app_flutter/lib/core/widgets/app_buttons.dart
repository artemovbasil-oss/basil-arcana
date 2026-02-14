import 'package:flutter/material.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? ElevatedButton(
            onPressed: onPressed,
            style: _style(context),
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: _style(context),
          );
    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }

  ButtonStyle _style(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14),
      backgroundColor: backgroundColor ?? colorScheme.primary,
      foregroundColor: foregroundColor ?? Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}

class AppGhostButton extends StatelessWidget {
  const AppGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? OutlinedButton(
            onPressed: onPressed,
            style: _style(context),
            child: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: _style(context),
          );
    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }

  ButtonStyle _style(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14),
      foregroundColor: colorScheme.primary,
      side: BorderSide(color: colorScheme.primary.withOpacity(0.8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}

class AppSmallButton extends StatelessWidget {
  const AppSmallButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary.withOpacity(0.8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

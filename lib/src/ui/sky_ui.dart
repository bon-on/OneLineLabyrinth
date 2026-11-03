import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/sky_theme.dart';
import '../art/star_art.dart';

/// Translucent glass panel used by every HUD block and overlay card.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.highlight = false,
  });

  final SkyPalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Gold rim for celebratory cards.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            p.panel.withValues(alpha: 0.82),
            p.skyTop.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(
          color: highlight
              ? p.gold.withValues(alpha: 0.75)
              : p.panelBorder.withValues(alpha: 0.9),
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (highlight ? p.gold : p.accent).withValues(alpha: 0.14),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small uppercase caption above a panel section.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, required this.palette});

  final String text;
  final SkyPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        color: palette.muted,
      ),
    );
  }
}

/// Round HUD icon button (keeps IconButton semantics and tooltips).
class SkyIconButton extends StatelessWidget {
  const SkyIconButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
    this.active = false,
  });

  final SkyPalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// Accent ring, e.g. for a lit hint.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: size * 0.5,
        style: IconButton.styleFrom(
          backgroundColor: p.panel.withValues(alpha: 0.85),
          foregroundColor: p.text,
          disabledForegroundColor: p.muted.withValues(alpha: 0.4),
          side: BorderSide(
            color: active ? p.gold : p.panelBorder,
            width: active ? 1.6 : 1,
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

/// Pill button with an icon and a label. [primary] glows in the thread colour.
class SkyButton extends StatelessWidget {
  const SkyButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.height = 42,
  });

  final SkyPalette palette;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fg = primary ? const Color(0xFF1A1230) : p.text;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      backgroundColor: WidgetStatePropertyAll(
        primary ? p.thread : p.panel.withValues(alpha: 0.9),
      ),
      foregroundColor: WidgetStatePropertyAll(fg),
      overlayColor: WidgetStatePropertyAll(
        p.threadCore.withValues(alpha: 0.12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
          side: BorderSide(color: primary ? p.threadCore : p.panelBorder),
        ),
      ),
      shadowColor: WidgetStatePropertyAll(p.thread),
      elevation: WidgetStatePropertyAll(primary ? 6 : 0),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: text);
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: text,
    );
  }
}

/// Label over a value, e.g. "Level" / "3".
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    this.height = 46,
  });

  final SkyPalette palette;
  final String label;
  final String value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.skyTop.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.panelBorder.withValues(alpha: 0.6)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: p.muted,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sky level chip with an XP bar.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.palette,
    required this.level,
    required this.into,
    required this.needed,
    this.compact = false,
  });

  final SkyPalette palette;
  final int level;
  final int into;
  final int needed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fraction = needed <= 0 ? 0.0 : (into / needed).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: p.thread.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.thread.withValues(alpha: 0.7)),
          ),
          child: Text(
            'Sky Lv $level',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: p.threadCore,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: compact ? 7 : 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: p.skyTop.withValues(alpha: 0.8)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[p.accent, p.thread],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                Text(
                  '$into / $needed XP',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: p.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Theme swatches; locked ones show their required level.
class ThemePicker extends StatelessWidget {
  const ThemePicker({
    super.key,
    required this.palette,
    required this.selected,
    required this.skyLevel,
    required this.onSelected,
    this.swatch = 52,
  });

  final SkyPalette palette;
  final SkyTheme selected;
  final int skyLevel;
  final ValueChanged<SkyTheme> onSelected;
  final double swatch;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final theme in SkyTheme.values)
          _ThemeSwatch(
            theme: theme,
            palette: p,
            size: swatch,
            selected: theme == selected,
            locked: skyLevel < theme.requiredLevel,
            onTap: () => onSelected(theme),
          ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.palette,
    required this.size,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final SkyTheme theme;
  final SkyPalette palette;
  final double size;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Tooltip(
      message: locked
          ? '${theme.label} sky (Sky Lv ${theme.requiredLevel})'
          : '${theme.label} sky',
      child: Semantics(
        button: true,
        selected: selected,
        enabled: !locked,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size * 0.72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? p.gold : p.panelBorder,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: SkySwatchPainter(theme)),
                      if (locked)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: Icon(
                            Icons.lock_rounded,
                            size: size * 0.3,
                            color: p.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: size,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    locked ? 'Lv ${theme.requiredLevel}' : theme.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                      color: selected ? p.gold : p.muted,
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

/// Live star goals of the current level.
class StarGoals extends StatelessWidget {
  const StarGoals({
    super.key,
    required this.palette,
    required this.clean,
    required this.seconds,
    required this.parSeconds,
    required this.bestStars,
    this.compact = false,
  });

  final SkyPalette palette;
  final bool clean;
  final ValueListenable<int> seconds;
  final int parSeconds;
  final int bestStars;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    Widget goal(bool ok, String text, {Widget? trailing}) => Row(
      children: [
        CustomPaint(
          size: const Size.square(14),
          painter: _GoalStarPainter(ok, p),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ok ? p.text : p.muted,
              decoration: ok ? null : TextDecoration.lineThrough,
              decorationColor: p.muted,
            ),
          ),
        ),
        ?trailing,
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel('Star goals', palette: p)),
            Text('Best ', style: TextStyle(fontSize: 11, color: p.muted)),
            RatingStars(earned: bestStars, palette: p, size: 11),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        goal(true, 'Reach the ring'),
        SizedBox(height: compact ? 2 : 4),
        goal(clean, 'Clean line: no undo or hint'),
        SizedBox(height: compact ? 2 : 4),
        ValueListenableBuilder<int>(
          valueListenable: seconds,
          builder: (context, s, _) => goal(
            s <= parSeconds,
            'Swift: within ${parSeconds}s',
            trailing: Text(
              '${s}s',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: s <= parSeconds ? p.thread : p.danger,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalStarPainter extends CustomPainter {
  _GoalStarPainter(this.ok, this.palette);

  final bool ok;
  final SkyPalette palette;

  @override
  void paint(Canvas canvas, Size size) => paintRatingStar(
    canvas,
    size.center(Offset.zero),
    size.shortestSide / 2,
    ok,
    palette,
  );

  @override
  bool shouldRepaint(covariant _GoalStarPainter old) =>
      old.ok != ok || old.palette != palette;
}

/// Full-screen scrim for menus (level map, album). Blocks input underneath,
/// takes keyboard focus, and closes with Escape or Enter. Tab, F5 and
/// Ctrl/Cmd/Alt combos stay with the host like the tutorial overlay.
class SkyOverlay extends StatefulWidget {
  const SkyOverlay({
    super.key,
    required this.palette,
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle,
    this.maxWidth = 760,
  });

  final SkyPalette palette;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final Widget child;
  final double maxWidth;

  @override
  State<SkyOverlay> createState() => _SkyOverlayState();
}

class _SkyOverlayState extends State<SkyOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'sky-overlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.f5 ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final isActivate =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
    // A Tab-focused tile or button inside the card activates itself.
    if (isActivate && !_focus.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      widget.onClose();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          onPanStart: (_) {},
          child: ColoredBox(
            color: p.skyTop.withValues(alpha: 0.78),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: GestureDetector(
                      // Taps on the card do not close it.
                      onTap: () {},
                      child: GlassPanel(
                        palette: p,
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: p.text,
                                        ),
                                      ),
                                      if (widget.subtitle != null)
                                        Text(
                                          widget.subtitle!,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: p.muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SkyIconButton(
                                  palette: p,
                                  icon: Icons.close_rounded,
                                  tooltip: 'Close',
                                  onPressed: widget.onClose,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Flexible(child: widget.child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

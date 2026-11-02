import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/art/sky_theme.dart';
import 'src/ui/sky_ui.dart';

/// Remembers whether the first-run tutorial has been seen.
///
/// Storage failures are swallowed so gameplay never depends on local storage:
/// when reading fails the tutorial is shown, when writing fails it just closes.
class TutorialStore {
  const TutorialStore();

  static const String key = 'tutorial_seen_v1';

  Future<bool> isSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {
      // The tutorial is a convenience; ignore storage errors.
    }
  }
}

class HowToPlayStep {
  const HowToPlayStep(this.icon, this.text);

  final IconData icon;
  final String text;
}

const List<HowToPlayStep> howToPlaySteps = [
  HowToPlayStep(
    Icons.auto_awesome,
    'Start at the bright star, light every star once with one line, and end on the ringed star.',
  ),
  HowToPlayStep(
    Icons.touch_app,
    'Tap or click a linked star, or drag across them. Go back to the previous star to undo a step.',
  ),
  HowToPlayStep(
    Icons.star_rounded,
    'Earn 3 stars: solve it, keep a clean line (no undo or hint) and beat the par time. Stuck? Use a hint or reset.',
  ),
];

/// Full-screen scrim with a "How to play" card. Blocks all input underneath.
class HowToPlayOverlay extends StatefulWidget {
  const HowToPlayOverlay({
    super.key,
    required this.onClose,
    this.steps = howToPlaySteps,
    this.palette,
  });

  final VoidCallback onClose;
  final List<HowToPlayStep> steps;

  /// Sky palette of the card; defaults to the Twilight sky.
  final SkyPalette? palette;

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'how-to-play');
  int _step = 0;

  bool get _last => _step == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    // Take keyboard focus from any tapped button so keys stop at the overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onClose();
    } else {
      setState(() => _step++);
    }
  }

  void _previous() {
    if (_step > 0) setState(() => _step--);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    // Browser/OS shortcuts (Tab, F5, Ctrl/Cmd/Alt combos) stay with the host.
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.f5 ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.handled;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space) {
        _next();
      } else if (key == LogicalKeyboardKey.escape) {
        widget.onClose();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        if (!_last) _next();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _previous();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final p = widget.palette ?? SkyTheme.twilight.palette;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          onPanStart: (_) {},
          child: ColoredBox(
            color: p.skyTop.withValues(alpha: 0.8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    type: MaterialType.transparency,
                    child: GlassPanel(
                      palette: p,
                      highlight: true,
                      padding: EdgeInsets.zero,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'How to play',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    p.thread.withValues(alpha: 0.45),
                                    p.thread.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                              child: Icon(step.icon, size: 46, color: p.thread),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < widget.steps.length; i++)
                                  Container(
                                    width: i == _step ? 18 : 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: i == _step
                                          ? p.thread
                                          : p.panelBorder,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: widget.onClose,
                                  style: TextButton.styleFrom(
                                    foregroundColor: p.muted,
                                  ),
                                  child: const Text('Skip'),
                                ),
                                SkyButton(
                                  palette: p,
                                  label: _last ? 'Play' : 'Next',
                                  primary: true,
                                  onPressed: _next,
                                ),
                              ],
                            ),
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

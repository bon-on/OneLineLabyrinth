import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    Icons.timeline,
    'Start at the dark dot, visit every knot once, and end on the white ring.',
  ),
  HowToPlayStep(
    Icons.touch_app,
    'Tap or click a linked knot, or drag across them. Go back to the last knot to undo a step.',
  ),
  HowToPlayStep(
    Icons.undo,
    'Stuck? Reset the path or deal a new puzzle. Pick Easy, Normal or Hard for bigger mazes.',
  ),
];

/// Full-screen scrim with a "How to play" card. Blocks all input underneath.
class HowToPlayOverlay extends StatefulWidget {
  const HowToPlayOverlay({
    super.key,
    required this.onClose,
    this.steps = howToPlaySteps,
  });

  final VoidCallback onClose;
  final List<HowToPlayStep> steps;

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
            color: const Color(0xCC000000),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    color: const Color(0xFF24221C),
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'How to play',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE7DEC3),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Icon(
                            step.icon,
                            size: 48,
                            color: const Color(0xFFD6A936),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            step.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: Color(0xFFE7DEC3),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < widget.steps.length; i++)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _step
                                        ? const Color(0xFFD6A936)
                                        : const Color(0xFF5A5139),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: widget.onClose,
                                child: const Text('Skip'),
                              ),
                              FilledButton(
                                onPressed: _next,
                                child: Text(_last ? 'Play' : 'Next'),
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
    );
  }
}

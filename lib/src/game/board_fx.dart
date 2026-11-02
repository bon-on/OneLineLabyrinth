/// Short-lived board effects. Rules apply instantly in the screen; these only
/// record what happened and when (in clock seconds) so the board painter can
/// trail behind. Nothing here uses timers: lifetimes are checked against the
/// shared clock and expired events are pruned on the next tick.
library;

enum FxKind {
  /// A knot joined the line: ring burst and sparkles. Nodes: [node].
  visit(0.45),

  /// The last step was taken back. Nodes: [removed, previous].
  retract(0.32),

  /// The whole line was reset. Nodes: the old path.
  scatter(0.6),

  /// A tap on a knot that cannot be reached. Nodes: [node].
  invalid(0.42),

  /// A hint lit the next knot. Nodes: [node]. Ends early when the path moves.
  hint(2.6),

  /// The ring was reached. Nodes: the solved path.
  complete(4.0);

  const FxKind(this.lifetime);

  /// Seconds the effect stays visible.
  final double lifetime;
}

class FxEvent {
  const FxEvent(this.kind, this.start, this.nodes);

  final FxKind kind;
  final double start;
  final List<int> nodes;

  /// Progress 0..1 at [now].
  double progress(double now) =>
      ((now - start) / kind.lifetime).clamp(0.0, 1.0);

  bool expired(double now) => now - start >= kind.lifetime;
}

class BoardFx {
  final List<FxEvent> events = <FxEvent>[];

  /// Clock time each knot was visited, for the pop animation.
  final Map<int, double> visitedAt = <int, double>{};

  /// Clock time the puzzle was solved (null while unsolved).
  double? completedAt;

  void visit(int node, double now) {
    visitedAt[node] = now;
    events.add(FxEvent(FxKind.visit, now, <int>[node]));
  }

  void retract(int removed, int previous, double now) {
    visitedAt.remove(removed);
    _endHints();
    events.add(FxEvent(FxKind.retract, now, <int>[removed, previous]));
  }

  void scatter(List<int> oldPath, double now) {
    visitedAt.removeWhere((node, _) => node != oldPath.first);
    _endHints();
    events.add(FxEvent(FxKind.scatter, now, List<int>.of(oldPath)));
  }

  void invalid(int node, double now) =>
      events.add(FxEvent(FxKind.invalid, now, <int>[node]));

  void hint(int node, double now) {
    _endHints();
    events.add(FxEvent(FxKind.hint, now, <int>[node]));
  }

  void complete(List<int> path, double now) {
    completedAt = now;
    _endHints();
    events.add(FxEvent(FxKind.complete, now, List<int>.of(path)));
  }

  /// A hint stops showing once the player moves on.
  void _endHints() => events.removeWhere((e) => e.kind == FxKind.hint);

  void endHints() => _endHints();

  /// The node a live hint points at, if any.
  int? hintNode(double now) {
    for (final e in events.reversed) {
      if (e.kind == FxKind.hint && !e.expired(now)) return e.nodes.first;
    }
    return null;
  }

  /// Forgets everything (new puzzle).
  void clear() {
    events.clear();
    visitedAt.clear();
    completedAt = null;
  }

  /// Drops finished effects. The complete event is kept as long as the
  /// puzzle stays solved because the painter derives the glow from it.
  void prune(double now) {
    events.removeWhere((e) => e.kind != FxKind.complete && e.expired(now));
  }
}

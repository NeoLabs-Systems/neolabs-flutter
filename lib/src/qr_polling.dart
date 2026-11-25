import 'dart:async';

/// Schedules QR status checks with long-poll pacing and backoff. The host owns
/// challenge state, error reporting, and session creation.
class NeoQrPolling {
  NeoQrPolling({
    required this.poll,
    required this.serverHoldsPolls,
    required this.canPoll,
    this.interval = const Duration(seconds: 5),
    this.heldPollGap = const Duration(milliseconds: 300),
    this.maxInterval = const Duration(seconds: 60),
  }) : _delay = interval;

  /// A null result indicates that the status check was superseded.
  final Future<bool?> Function() poll;
  final bool Function() serverHoldsPolls;
  final bool Function() canPoll;
  final Duration interval, heldPollGap, maxInterval;
  Duration _delay;
  Timer? _timer;
  bool _active = false;
  final Set<int> _running = {};
  bool _disposed = false;
  int _generation = 0;

  /// Begin or resume polling. A fresh challenge starts with a short gap.
  void start({bool fresh = false}) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _generation++;
    _active = true;
    if (fresh) _delay = heldPollGap;
    _schedule();
  }

  void pause() {
    _generation++;
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    if (!_active ||
        _disposed ||
        _running.contains(_generation) ||
        _timer != null ||
        !canPoll())
      return;
    _timer = Timer(_delay, _run);
  }

  Future<void> _run() async {
    _timer = null;
    if (!_active || _disposed || !canPoll()) return;
    final generation = _generation;
    _running.add(generation);
    try {
      final success = await poll();
      if (_active && generation == _generation && success != null) {
        final doubled = _delay * 2;
        _delay = success
            ? (serverHoldsPolls() ? heldPollGap : interval)
            : (doubled > maxInterval ? maxInterval : doubled);
      }
    } finally {
      _running.remove(generation);
      _schedule();
    }
  }

  void dispose() {
    pause();
    _disposed = true;
  }
}

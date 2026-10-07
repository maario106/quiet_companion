import 'dart:async';

/// Temporizador controlado a mano: el test decide cuándo vence.
class ManualTimer implements Timer {
  ManualTimer(this.duration, this._onFire);

  final Duration duration;
  final void Function() _onFire;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _onFire();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

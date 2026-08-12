import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A global, persisted text-scale preference. Applied once at the
/// MaterialApp root (main.dart), via MediaQuery's textScaler, so it
/// affects every screen in the app consistently — the admin turns it up
/// once and every page they visit reads bigger, not just the one they
/// were on when they changed it. Persisted with shared_preferences,
/// which on web is backed by the browser's localStorage — a per-device
/// setting, same as it would be for any other browser preference.
class FontScaleController extends ChangeNotifier {
  FontScaleController._internal();
  static final FontScaleController _instance =
      FontScaleController._internal();
  factory FontScaleController() => _instance;

  static const _prefsKey = 'font_scale';
  static const List<double> steps = [0.85, 1.0, 1.15, 1.3, 1.45];
  static const int _defaultIndex = 1; // steps[1] == 1.0

  double _scale = steps[_defaultIndex];
  double get scale => _scale;

  /// A quick label for the current step, e.g. for a settings screen —
  /// "100%" reads more plainly than a raw multiplier to a non-technical
  /// admin.
  String get label => '${(_scale * 100).round()}%';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    if (saved != null && steps.contains(saved)) {
      _scale = saved;
      notifyListeners();
    }
  }

  Future<void> _setScale(double value) async {
    if (value == _scale) return;
    _scale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, value);
  }

  int get _currentIndex {
    final idx = steps.indexOf(_scale);
    return idx == -1 ? _defaultIndex : idx;
  }

  bool get canIncrease => _currentIndex < steps.length - 1;
  bool get canDecrease => _currentIndex > 0;

  Future<void> increase() async {
    if (!canIncrease) return;
    await _setScale(steps[_currentIndex + 1]);
  }

  Future<void> decrease() async {
    if (!canDecrease) return;
    await _setScale(steps[_currentIndex - 1]);
  }

  Future<void> reset() async => _setScale(steps[_defaultIndex]);
}

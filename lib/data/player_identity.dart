import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Who you are, locally.
///
/// Stands in for anonymous auth: the same shape — an opaque id you never type in — so swapping
/// in a real uid later changes one method, not every call site.
///
/// Loaded once via [load] so the rest of the app can read these synchronously; the values are
/// consulted on every claim and every leaderboard row.
class PlayerIdentity {
  PlayerIdentity._(this._prefs, this._id, this._name, this._colorHex);

  static const String _keyId = 'player_id';
  static const String _keyName = 'player_name';
  static const String _keyColor = 'player_color';
  static const String _keyMetric = 'units_metric';

  static const String defaultName = 'You';
  static const String playerColor = '#FF6B35';

  final SharedPreferences _prefs;
  final String _id;
  String _name;
  String _colorHex;

  static Future<PlayerIdentity> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();

    var id = store.getString(_keyId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await store.setString(_keyId, id);
    }

    var color = store.getString(_keyColor);
    if (color == null || color.isEmpty) {
      color = playerColor;
      await store.setString(_keyColor, color);
    }

    return PlayerIdentity._(
      store,
      id,
      store.getString(_keyName) ?? defaultName,
      color,
    );
  }

  String get id => _id;
  String get name => _name;
  String get colorHex => _colorHex;
  bool get unitsMetric => _prefs.getBool(_keyMetric) ?? true;

  Future<void> setName(String value) async {
    final trimmed = value.trim();
    _name = trimmed.isEmpty ? defaultName : trimmed;
    await _prefs.setString(_keyName, _name);
  }

  Future<void> setColorHex(String value) async {
    _colorHex = value;
    await _prefs.setString(_keyColor, value);
  }

  Future<void> setUnitsMetric(bool value) => _prefs.setBool(_keyMetric, value);
}

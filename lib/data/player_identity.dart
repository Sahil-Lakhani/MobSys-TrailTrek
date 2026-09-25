import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Who you are.
///
/// Signed out, that is an opaque local id generated on first launch — you never type it in, and
/// the game is fully playable under it. Signing in binds a Firebase uid over the top, and [id]
/// starts answering with that instead, so every claim and every leaderboard row files itself
/// under the real account without any call site learning a new shape.
///
/// The local id is kept rather than replaced: ground claimed before signing in is still filed
/// under it, and re-owning that ground needs somewhere to look.
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

  String? _uid;
  String? _displayName;
  String? _photoUrl;

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

  /// The Firebase uid when signed in, the local id otherwise.
  String get id => _uid ?? _id;

  /// Always the local id, whatever the sign-in state.
  String get localId => _id;

  bool get isSignedIn => _uid != null;

  /// A name you chose yourself wins, then the Google profile name, then the fallback.
  ///
  /// This order matters: with Google first, the name field on the profile screen would appear
  /// to do nothing while signed in. A Google account is also not obliged to carry a name at
  /// all, which is why the fallback stays.
  String get name => _hasChosenName ? _name : (_displayName ?? _name);

  bool get _hasChosenName => _name.isNotEmpty && _name != defaultName;

  /// True when the displayed name comes from Google rather than from a choice made here.
  bool get usesAccountName => !_hasChosenName && _displayName != null;

  String? get photoUrl => _photoUrl;

  String get colorHex => _colorHex;

  /// Binds a signed-in Firebase user over the local identity.
  void bindTo({required String uid, String? displayName, String? photoUrl}) {
    _uid = uid;
    final trimmed = (displayName ?? '').trim();
    _displayName = trimmed.isEmpty ? null : trimmed;
    _photoUrl = (photoUrl ?? '').isEmpty ? null : photoUrl;
  }

  /// Returns to the local identity. The ground claimed while signed in stays owned by the uid.
  void unbind() {
    _uid = null;
    _displayName = null;
    _photoUrl = null;
  }
  bool get unitsMetric => _prefs.getBool(_keyMetric) ?? true;

  /// Clearing it hands the display back to the Google name, or the fallback when signed out.
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

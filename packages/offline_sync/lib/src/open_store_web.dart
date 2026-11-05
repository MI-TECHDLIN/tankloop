import 'package:shared_preferences/shared_preferences.dart';
import 'storage.dart';

// The browser preview uses one atomic origin-local preference per scoped
// snapshot. Android uses Drift/SQLite. Do not treat browser storage as encrypted.
class _BrowserStore implements KeyValueStore {
  final _preferences = SharedPreferencesAsync();
  String _key(String key) => 'tankloop.v1.$key';
  @override
  Future<String?> read(String key) => _preferences.getString(_key(key));
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(_key(key), value);
  @override
  Future<void> remove(String key) => _preferences.remove(_key(key));
  @override
  Future<void> close() async {}
}

Future<KeyValueStore> openLocalStore() async => _BrowserStore();

import 'package:drift/drift.dart';
import 'storage.dart';

/// A versioned Drift/SQLite store for atomic draft+outbox snapshots. Raw SQL
/// keeps this small schema free of generated model code.
class SqliteKeyValueStore extends GeneratedDatabase implements KeyValueStore {
  SqliteKeyValueStore(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE local_state (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
      );
    },
  );
  @override
  Future<String?> read(String key) async {
    final row = await customSelect(
      'SELECT value FROM local_state WHERE key = ?',
      variables: [Variable<String>(key)],
    ).getSingleOrNull();
    return row?.read<String>('value');
  }

  @override
  Future<void> write(String key, String value) => transaction(
    () => customStatement(
      'INSERT INTO local_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    ),
  );
  @override
  Future<void> remove(String key) =>
      customStatement('DELETE FROM local_state WHERE key = ?', [key]);
}

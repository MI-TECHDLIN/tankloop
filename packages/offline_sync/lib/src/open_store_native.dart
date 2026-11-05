import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'sqlite_store.dart';
import 'storage.dart';

Future<KeyValueStore> openLocalStore() async {
  final directory = await getApplicationSupportDirectory();
  return SqliteKeyValueStore(
    NativeDatabase.createInBackground(
      File('${directory.path}/tankloop.sqlite'),
    ),
  );
}

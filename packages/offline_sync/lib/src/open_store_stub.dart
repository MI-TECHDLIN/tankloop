import 'storage.dart';

Future<KeyValueStore> openLocalStore() => throw UnsupportedError(
  'This platform does not provide durable local storage.',
);

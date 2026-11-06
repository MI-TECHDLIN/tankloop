import 'dart:convert';
import 'dart:typed_data';
import 'package:tankloop_domain/domain.dart';
import 'storage.dart';

/// Bytes live in the same account-scoped Drift database as the queue. Camera
/// cache files can disappear at any time and are never the source of truth.
class LocalPhotos {
  const LocalPhotos(this.store, this.namespace);
  final KeyValueStore store;
  final String namespace;
  String _key(String id) => 'photo:$namespace:$id';

  Future<InspectionEvidence> save({
    required String id,
    required Uint8List bytes,
    required DateTime capturedAt,
    String? questionId,
  }) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Photos must be nonempty and at most 10 MB.');
    }
    await store.write(_key(id), base64Encode(bytes));
    return InspectionEvidence(
      id: id,
      localPath: 'drift-photo:$id',
      capturedAt: capturedAt,
      questionId: questionId,
    );
  }

  Future<Uint8List?> read(InspectionEvidence evidence) async {
    final data = await store.read(_key(evidence.id));
    if (data == null && evidence.localPath.startsWith('drift-photo:')) {
      throw const FormatException(
        'Saved photo bytes are missing. Keep the draft for review.',
      );
    }
    return data == null ? null : base64Decode(data);
  }

  Future<void> remove(String id) => store.remove(_key(id));
}

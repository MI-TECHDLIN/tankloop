import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'package:uuid/uuid.dart';
import 'runtime.dart';

/// Persists the destination before launching Android's camera activity, which
/// may kill our process. retrieveLostData can then attach the returned image to
/// the original draft, never to whichever screen happens to open next.
class FieldPhotoCapture {
  FieldPhotoCapture(this.runtime);
  final FieldRuntime runtime;
  final picker = ImagePicker();
  String get key => 'camera:${runtime.identity}';
  Future<void> capture({
    required String id,
    required bool workOrder,
    String? questionId,
  }) async {
    await runtime.store.write(
      key,
      jsonEncode({
        'id': id,
        'work_order': workOrder,
        'question_id': questionId,
      }),
    );
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1800,
    );
    if (image == null) {
      await runtime.store.remove(key);
      return;
    }
    await _attach(image);
  }

  Future<void> recover() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        await runtime.store.read(key) == null) {
      return;
    }
    final response = await picker.retrieveLostData();
    if (response.exception != null) throw response.exception!;
    for (final image in response.files ?? <XFile>[]) {
      await _attach(image);
    }
  }

  Future<void> _attach(XFile image) async {
    final encoded = await runtime.store.read(key);
    if (encoded == null) return;
    final target = jsonDecode(encoded) as Map<String, dynamic>;
    final id = target['id'] as String;
    final photoId = const Uuid().v4();
    final photo = await runtime.outbox.photos.save(
      id: photoId,
      bytes: await image.readAsBytes(),
      capturedAt: DateTime.now().toUtc(),
      questionId: target['question_id'] as String?,
    );
    if (target['work_order'] == true) {
      final order = runtime.dashboard.workOrders.singleWhere((w) => w.id == id);
      final draft = runtime.workOutbox.forOrder(order);
      if (draft == null || draft.state != DraftState.draft) {
        throw StateError('Original work draft unavailable.');
      }
      await runtime.workOutbox.save(
        order: order,
        actorId: runtime.dashboard.actorId,
        notes: draft.command.notes,
        observedAt: draft.command.observedAt,
        evidence: [...draft.command.evidence, photo],
      );
    } else {
      final task = runtime.dashboard.inspections.singleWhere((t) => t.id == id);
      final draft = runtime.outbox.forTask(id);
      if (draft == null || draft.state != DraftState.draft) {
        throw StateError('Original inspection draft unavailable.');
      }
      await runtime.outbox.save(
        task: task,
        answers: draft.command.answers,
        notes: draft.command.notes,
        observedAt: draft.command.observedAt,
        evidence: [...draft.command.evidence, photo],
      );
    }
    await runtime.store.remove(key);
  }
}

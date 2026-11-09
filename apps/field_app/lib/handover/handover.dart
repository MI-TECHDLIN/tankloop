import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

typedef Json = Map<String, dynamic>;

class HandoverFailure implements Exception {
  const HandoverFailure(this.code, this.message);
  final String code;
  final String message;
}

class HandoverDraft {
  HandoverDraft(this.document);
  final Json document;
  String get originalText => document['original_text'] as String;
  String get actorId => document['actor_id'] as String;
  String get fingerprint => document['fingerprint'] as String;
  String get generatedAt => document['generated_at'] as String;
  String get model => document['model'] as String;
  Json get snapshot => document['snapshot'] as Json;
  List<Json> get sources => (snapshot['sources'] as List).cast<Json>();
  List<Json> get highlights => (document['highlights'] as List).cast<Json>();
  List<Json> get steps => (document['next_steps'] as List).cast<Json>();
  List<Json> get gaps => (document['gaps'] as List).cast<Json>();
  String get limitation => document['limitation'] as String;
}

abstract interface class HandoverService {
  Future<HandoverDraft> generate(String kind, String id);
  Future<Json> review(String kind, String id, HandoverDraft draft);
}

final handoverServiceProvider = Provider<HandoverService>(
  (ref) => SupabaseHandoverService(Supabase.instance.client),
);

class SupabaseHandoverService implements HandoverService {
  SupabaseHandoverService(this.client);
  final SupabaseClient client;

  Future<Json> _invoke(Json body) async {
    try {
      final response = await client.functions
          .invoke('prepare-handover', body: body)
          .timeout(const Duration(seconds: 50));
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map &&
          details['code'] is String &&
          details['message'] is String) {
        throw HandoverFailure(
          details['code'] as String,
          details['message'] as String,
        );
      }
      throw const HandoverFailure(
        'unavailable',
        'Handover assistance is unavailable. Check your connection and sign-in, then try again.',
      );
    } on TimeoutException {
      throw const HandoverFailure(
        'timeout',
        'The request timed out. Your wording is retained. Try again when connected.',
      );
    } catch (_) {
      throw const HandoverFailure(
        'offline',
        'Could not reach the assistant. Your wording is retained. Connect and try again.',
      );
    }
  }

  @override
  Future<HandoverDraft> generate(String kind, String id) async => HandoverDraft(
    await _invoke({'action': 'generate', 'kind': kind, 'id': id}),
  );

  @override
  Future<Json> review(String kind, String id, HandoverDraft draft) => _invoke({
    'action': 'review',
    'kind': kind,
    'id': id,
    'reviewed': true,
    'fingerprint': draft.fingerprint,
    'generated_at': draft.generatedAt,
  });
}

String handoverStorageKey(String identity, String facilityId) =>
    'reviewed-handovers:$identity:$facilityId';

/// A separate private draft store. This never writes to the inspection/work
/// outboxes and has no publish, attest, share or incident-transition operation.
class HandoverController extends ChangeNotifier {
  HandoverController({
    required this.service,
    required this.store,
    required this.storageKey,
    required this.actorId,
    required this.kind,
    required this.id,
    required this.canConnect,
    required this.hasAccess,
  });
  final HandoverService service;
  final KeyValueStore store;
  final String storageKey;
  final String actorId;
  final String kind;
  final String id;
  final bool Function() canConnect;
  final bool Function() hasAccess;
  HandoverDraft? draft;
  String wording = '';
  String? previousWording;
  String? savedAt;
  String? _savedWording;
  bool get hasUnsavedEdits => wording != _savedWording;
  HandoverFailure? failure;
  bool reviewed = false;
  bool busy = false;
  bool mustRegenerate = false;
  bool _disposed = false;
  String get _entryKey => '$kind:$id';
  bool get canSave =>
      draft != null &&
      reviewed &&
      !busy &&
      !mustRegenerate &&
      wording.trim().isNotEmpty &&
      wording.length <= 6000 &&
      hasAccess() &&
      canConnect();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      final raw = await store.read(storageKey);
      if (raw == null || !hasAccess() || _disposed) return;
      final saved = (jsonDecode(raw) as Json)[_entryKey] as Json?;
      if (saved == null || saved['reviewer_id'] != actorId) return;
      final restored = HandoverDraft(saved['generation'] as Json);
      if (restored.actorId != actorId ||
          restored.snapshot['kind'] != kind ||
          restored.snapshot['id'] != id) {
        return;
      }
      draft = restored;
      wording = saved['reviewed_text'] as String;
      savedAt = saved['reviewed_at'] as String;
      _savedWording = wording;
      reviewed = false;
      _notify();
    } catch (_) {
      failure = const HandoverFailure(
        'local_storage',
        'The saved draft could not be opened. It has been retained on this device.',
      );
      _notify();
    }
  }

  void edit(String text) {
    if (text == wording) return;
    wording = text;
    reviewed = false;
    _notify();
  }

  void confirmReview(bool value) {
    reviewed = value && !mustRegenerate;
    _notify();
  }

  void _checkConnection() {
    if (!hasAccess()) {
      throw const HandoverFailure(
        'forbidden',
        'Your access has changed. Return to your assignments.',
      );
    }
    if (!canConnect()) {
      throw const HandoverFailure(
        'offline',
        'Connect to prepare or save a reviewed draft. Your existing wording is retained.',
      );
    }
  }

  Future<void> generate() async {
    if (busy) return;
    busy = true;
    failure = null;
    _notify();
    try {
      _checkConnection();
      final generated = await service.generate(kind, id);
      _checkConnection();
      if (_disposed) return;
      if (generated.actorId != actorId ||
          generated.snapshot['kind'] != kind ||
          generated.snapshot['id'] != id) {
        throw const HandoverFailure(
          'forbidden',
          'The returned draft does not belong to this selection.',
        );
      }
      previousWording = wording.isEmpty ? null : wording;
      draft = generated;
      wording = generated.originalText;
      reviewed = false;
      savedAt = null;
      _savedWording = null;
      mustRegenerate = false;
    } on HandoverFailure catch (error) {
      failure = error;
    } catch (_) {
      failure = const HandoverFailure(
        'unavailable',
        'Could not prepare the draft. Your wording is retained.',
      );
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> save() async {
    if (busy) return;
    if (!reviewed ||
        draft == null ||
        mustRegenerate ||
        wording.trim().isEmpty ||
        wording.length > 6000) {
      failure = const HandoverFailure(
        'review_required',
        'Review the wording and sources before saving.',
      );
      _notify();
      return;
    }
    final reviewedText = wording;
    busy = true;
    failure = null;
    _notify();
    try {
      _checkConnection();
      final receipt = await service.review(kind, id, draft!);
      _checkConnection();
      if (_disposed) return;
      if (!reviewed ||
          wording != reviewedText ||
          receipt['reviewer_id'] != actorId ||
          receipt['fingerprint'] != draft!.fingerprint) {
        throw const HandoverFailure(
          'review_required',
          'The draft changed. Review it again before saving.',
        );
      }
      final raw = await store.read(storageKey);
      final saved = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Json;
      _checkConnection();
      if (_disposed) return;
      saved[_entryKey] = {
        'version': 1,
        'generation': draft!.document,
        'reviewed_text': reviewedText,
        'reviewer_id': actorId,
        'reviewed_at': receipt['reviewed_at'],
      };
      await store.write(storageKey, jsonEncode(saved));
      savedAt = receipt['reviewed_at'] as String;
      _savedWording = reviewedText;
      reviewed = false;
    } on HandoverFailure catch (error) {
      failure = error;
      reviewed = false;
      if (error.code == 'stale_sources') mustRegenerate = true;
    } catch (_) {
      failure = const HandoverFailure(
        'local_storage',
        'The draft could not be saved on this device. Your wording is still here.',
      );
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

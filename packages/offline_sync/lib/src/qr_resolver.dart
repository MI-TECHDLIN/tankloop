import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';

String parsePointToken(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  final route = uri != null && uri.fragment.startsWith('/')
      ? Uri.tryParse(uri.fragment)
      : uri;
  final token =
      route != null &&
          route.pathSegments.length >= 2 &&
          route.pathSegments[route.pathSegments.length - 2] == 'point'
      ? route.pathSegments.last
      : text;
  if (!RegExp(r'^[a-f0-9]{32,128}$').hasMatch(token)) {
    throw const FormatException(
      'Enter the opaque point code printed with the QR.',
    );
  }
  return token;
}

/// Online validation is deliberate: a cached QR cannot prove non-revocation.
/// Downloaded inspections remain available offline through Today and Water.
Future<SamplingPoint> resolveFieldQr(
  String raw, {
  required TankLoopRepository repository,
  required DashboardSnapshot dashboard,
  required bool online,
}) async {
  final token = parsePointToken(raw);
  if (!online) {
    throw const RepositoryFailure(
      FailureKind.transient,
      'Connect to verify this QR is still active. Open downloaded assignments from Today while offline.',
    );
  }
  final record = await repository.publicRecord(token);
  if (record == null) {
    throw const RepositoryFailure(
      FailureKind.invalid,
      'This QR is unknown or revoked. Check the printed point label.',
    );
  }
  final pointId = dashboard.publicTokens.entries
      .where((e) => e.value == token)
      .map((e) => e.key)
      .firstOrNull;
  final point = dashboard.points.where((p) => p.id == pointId).firstOrNull;
  if (point == null) {
    throw const RepositoryFailure(
      FailureKind.permission,
      'This point is not assigned to the signed-in field account.',
    );
  }
  return point;
}

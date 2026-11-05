import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'lab_navigation.dart';
import 'lab_portal.dart';

List<RouteBase> labRoutes(
  LabRepository repository, {
  SupabaseClient? authClient,
}) => [
  GoRoute(path: '/lab', redirect: (_, _) => '/lab/inbox'),
  GoRoute(
    path: '/lab/:section',
    redirect: (_, state) =>
        LabSection.values.any((s) => s.path == state.pathParameters['section'])
        ? null
        : '/lab/inbox',
    builder: (context, state) => LabPortal(
      repository: repository,
      authClient: authClient,
      section: LabSection.values.singleWhere(
        (s) => s.path == state.pathParameters['section'],
      ),
      recordId: state.uri.queryParameters['record'],
      onNavigate: (section, id) => context.go(
        Uri(
          path: '/lab/${section.path}',
          queryParameters: id == null ? null : {'record': id},
        ).toString(),
      ),
    ),
  ),
];

Uri publicPointLink({
  required Uri base,
  required String token,
  int? seed,
  int? day,
  bool textFirst = false,
}) {
  final query = {
    if (seed != null && day != null) ...{'seed': '$seed', 'day': '$day'},
    if (textFirst) 'view': 'text',
  };
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: base.path,
    fragment: Uri(
      path: '/point/$token',
      queryParameters: query.isEmpty ? null : query,
    ).toString(),
  );
}

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool get isOnline => web.window.navigator.onLine;

Stream<bool> get connectivityChanges {
  late final StreamController<bool> controller;
  final listener = ((web.Event _) => controller.add(isOnline)).toJS;
  controller = StreamController<bool>(
    onListen: () {
      web.window.addEventListener('online', listener);
      web.window.addEventListener('offline', listener);
    },
    onCancel: () {
      web.window.removeEventListener('online', listener);
      web.window.removeEventListener('offline', listener);
    },
  );
  return controller.stream;
}

void openPrintDocument(String document) {
  final blob = web.Blob(
    [document.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank', 'noopener');
  Timer(const Duration(minutes: 5), () => web.URL.revokeObjectURL(url));
}

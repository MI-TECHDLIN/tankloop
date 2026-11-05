bool get isOnline => true;
Stream<bool> get connectivityChanges => const Stream.empty();

void openPrintDocument(String document) {
  throw UnsupportedError('Open the public record in a browser to print it.');
}

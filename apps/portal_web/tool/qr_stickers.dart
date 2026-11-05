import 'dart:io';
import 'package:args/args.dart';
import 'src/qr_sticker_sheet.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'base-url',
      help:
          'Portal URL reachable from the phone, including any hosting subdirectory.',
    )
    ..addOption('seed', defaultsTo: '20261101')
    ..addOption('day', defaultsTo: '10')
    ..addOption(
      'mode',
      allowed: ['simulation', 'supabase'],
      defaultsTo: 'simulation',
    )
    ..addOption(
      'facility-index',
      help:
          'Optional zero-based facility index; defaults to all simulator points.',
    )
    ..addOption('output', defaultsTo: 'tankloop-qr-stickers.html')
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final options = parser.parse(arguments);
    if (options.flag('help')) {
      stdout.writeln(parser.usage);
      return;
    }
    if (options.rest.isNotEmpty || options.option('base-url') == null) {
      throw const FormatException(
        'Supply --base-url and named options only. Use --help for usage.',
      );
    }
    final output = File(options.option('output')!);
    final document = demoStickerSheet(
      base: Uri.parse(options.option('base-url')!),
      seed: int.parse(options.option('seed')!),
      day: int.parse(options.option('day')!),
      connected: options.option('mode') == 'supabase',
      facilityIndex: options.option('facility-index') == null
          ? null
          : int.parse(options.option('facility-index')!),
    );
    output.writeAsStringSync(document);
    stdout.writeln(
      'SIMULATED DEMO DATA: A4 sticker sheet written to ${output.absolute.path}',
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  }
}

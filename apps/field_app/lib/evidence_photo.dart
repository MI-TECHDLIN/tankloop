import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

class EvidencePhoto extends StatefulWidget {
  const EvidencePhoto({super.key, required this.photo, required this.photos});
  final InspectionEvidence photo;
  final LocalPhotos photos;
  @override
  State<EvidencePhoto> createState() => _EvidencePhotoState();
}

class _EvidencePhotoState extends State<EvidencePhoto> {
  late final Future<Uint8List?> bytes = widget.photos.read(widget.photo);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(
          width: 116,
          height: 92,
          child: Center(child: Text('Loading photo')),
        );
      }
      if (snapshot.data == null || snapshot.hasError) {
        return const SizedBox(
          width: 116,
          height: 92,
          child: Center(
            child: Text('Photo unavailable. Keep draft for review.'),
          ),
        );
      }
      return Image.memory(
        snapshot.data!,
        width: 116,
        height: 92,
        cacheWidth: 232,
        fit: BoxFit.cover,
        semanticLabel: 'Saved inspection photo',
        errorBuilder: (_, _, _) => const Icon(Symbols.broken_image_rounded),
      );
    },
  );
}

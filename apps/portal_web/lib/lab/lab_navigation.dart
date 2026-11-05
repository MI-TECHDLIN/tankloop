import 'package:flutter/material.dart';

enum LabSection {
  inbox('inbox', 'Inbox', Icons.inbox_outlined),
  intake('intake', 'Sample intake', Icons.inventory_2_outlined),
  results('results', 'Results', Icons.science_outlined),
  revisions('revisions', 'Revisions', Icons.history_rounded);

  const LabSection(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

typedef LabNavigate = void Function(LabSection section, String? recordId);

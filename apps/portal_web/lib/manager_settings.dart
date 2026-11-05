import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';

class ManagerSettingsScreen extends StatelessWidget {
  const ManagerSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading('Settings'),
      NoticeCard(
        title: 'Scoped access',
        message:
            'Manager actions are limited to the selected facility and require an authoritative receipt in production.',
        icon: Icons.lock_outline,
      ),
      NoticeCard(
        title: 'Offline and permission states',
        message:
            'When the service is offline, stale, or access is denied, drafts remain visible but authoritative transitions stay disabled.',
        icon: Icons.cloud_off_outlined,
      ),
    ],
  );
}

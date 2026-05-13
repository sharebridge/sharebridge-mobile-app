import 'package:flutter/material.dart';

import 'features/donor_setup/presentation/pages/donor_setup_page.dart';

void main() {
  runApp(const SharingBridgeApp());
}

class SharingBridgeApp extends StatelessWidget {
  const SharingBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: DonorSetupPage());
  }
}

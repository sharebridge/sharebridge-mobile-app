import 'package:flutter/material.dart';

import 'features/donor_setup/presentation/pages/donor_setup_page.dart';

void main() {
  runApp(const ShareBridgeApp());
}

class ShareBridgeApp extends StatelessWidget {
  const ShareBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: DonorSetupPage());
  }
}

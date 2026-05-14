import 'package:flutter/material.dart';

import 'presentation/app_home_page.dart';

void main() {
  runApp(const SharingBridgeApp());
}

class SharingBridgeApp extends StatelessWidget {
  const SharingBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: AppHomePage());
  }
}

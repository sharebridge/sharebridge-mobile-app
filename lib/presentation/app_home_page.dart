import 'package:flutter/material.dart';

import '../features/donor_seeker_interaction/presentation/pages/donor_seeker_interaction_page.dart';
import '../features/donor_setup/presentation/pages/donor_setup_page.dart';

/// Entry hub: donor setup (before field) vs donor–seeker field flow (BRD steps 2+).
class AppHomePage extends StatelessWidget {
  const AppHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SharingBridge')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: <Widget>[
          Text(
            'Choose how you are using the app right now.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const Key('nav_donor_setup'),
              leading: const Icon(Icons.tune),
              title: const Text('Donor setup'),
              subtitle: const Text(
                'Save vendor links and menu presets before you go out (BRD step 1).',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const DonorSetupPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('nav_field_flow'),
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Offer food help'),
              subtitle: const Text(
                'Someone is asking for help now — quick guidance, consent, and beneficiary details (BRD steps 2–5).',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        const DonorSeekerInteractionPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

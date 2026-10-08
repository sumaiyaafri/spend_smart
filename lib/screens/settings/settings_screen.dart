import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          const Text(
            'Settings',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 25),

          _section(
            context,
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.dark_mode_outlined),
                    SizedBox(width: 12),
                    Text(
                      'Theme',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                LayoutBuilder(
                  builder: (context, constraints) => SegmentedButton<ThemeMode>(
                    direction:
                        constraints.maxWidth <
                            360 * MediaQuery.textScalerOf(context).scale(1)
                        ? Axis.vertical
                        : Axis.horizontal,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.phone_android_rounded),
                        label: Text('System'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (value) {
                      settings.setThemeMode(value.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          _section(
            context,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _iconBox(context, Icons.payments_rounded),
              title: const Text(
                'Currency',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Bangladeshi Taka'),
              trailing: const Text(
                '৳ BDT',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 14),

          _section(
            context,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _iconBox(context, Icons.cloud_upload_outlined),
              title: const Text(
                'Backup & Restore',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Keep a local backup of your expenses'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                _comingSoon(context, 'Backup & Restore');
              },
            ),
          ),

          const SizedBox(height: 14),

          _section(
            context,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _iconBox(context, Icons.download_rounded),
              title: const Text(
                'Export Data',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Export expenses as CSV'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                _comingSoon(context, 'CSV Export');
              },
            ),
          ),

          const SizedBox(height: 14),

          _section(
            context,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _iconBox(context, Icons.info_outline),
              title: const Text(
                'About App',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Spend Smart\nVersion 1.0.0'),
            ),
          ),

          const SizedBox(height: 14),

          _section(
            context,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _iconBox(context, Icons.auto_stories_outlined),
              title: const Text(
                'View onboarding',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Explore the three introduction pages again',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: settings.resetOnboarding,
            ),
          ),

          const SizedBox(height: 30),

          const Center(
            child: Text(
              '100% Offline • Your data stays on your device',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, {required Widget child}) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _iconBox(BuildContext context, IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature will be added in the next phase.')),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';

/// Root widget. Theme (1.3), localization (1.4) and routing (1.5) plug in
/// here as their sub-phases land.
class App extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text(config.appName))),
    );
  }
}

/// Shown instead of the app when the build was misconfigured, so a broken
/// build fails loudly on first launch rather than misbehaving later.
class ConfigErrorApp extends StatelessWidget {
  const new({required this.problems, super.key});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'App configuration error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              for (final problem in problems) Text('• $problem'),
            ],
          ),
        ),
      ),
    );
  }
}

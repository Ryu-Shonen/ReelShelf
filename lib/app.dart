import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';

class UnstreamedApp extends StatefulWidget {
  const UnstreamedApp({
    super.key,
    required this.state,
  });

  final AppState state;

  @override
  State<UnstreamedApp> createState() =>
      _UnstreamedAppState();
}

class _UnstreamedAppState extends State<UnstreamedApp> {
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _prepareApp();
  }

  Future<void> _prepareApp() async {
    await Future.wait([
      widget.state.initialize(),
      Future<void>.delayed(
        const Duration(milliseconds: 1200),
      ),
    ]);
  }

  void _retry() {
    setState(() {
      _startup = _prepareApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: widget.state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Unstreamed',
        theme: AppTheme.dark(),
        home: FutureBuilder<void>(
          future: _startup,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StartupErrorScreen(
                error: snapshot.error,
                onRetry: _retry,
              );
            }

            if (snapshot.connectionState !=
                ConnectionState.done) {
              return const UnstreamedSplashScreen();
            }

            return const ShellScreen();
          },
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 42,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Unstreamed konnte nicht gestartet werden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

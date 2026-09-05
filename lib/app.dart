import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/shell_screen.dart';
import 'state/app_state.dart';

class ReelShelfApp extends StatelessWidget {
  const ReelShelfApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ReelShelf',
        theme: AppTheme.dark(),
        home: const ShellScreen(),
      ),
    );
  }
}

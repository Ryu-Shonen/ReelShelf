import 'package:flutter/material.dart';

import 'app.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final state = AppState();
  runApp(UnstreamedApp(state: state));
}

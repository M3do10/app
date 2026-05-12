import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "app.dart";
import "services/crash_monitor.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => CrashMonitor(),
      child: const CrashGuardApp(),
    ),
  );
}

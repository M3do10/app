import "package:flutter/material.dart";

import "screens/home_screen.dart";
import "theme/app_theme.dart";

class CrashGuardApp extends StatelessWidget {
  const CrashGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "CrashGuard",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

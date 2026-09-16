import 'package:flutter/material.dart';

import '../features/home/presentation/views/home_screen.dart';
import 'theme/app_theme.dart';

class AgriApp extends StatelessWidget {
  const AgriApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Agri Intelligence',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeScreen(),
      );
}

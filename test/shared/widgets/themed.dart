import 'package:flutter/material.dart';
import 'package:spor_takip/core/theme/app_theme.dart';

/// Bileşeni gerçek temayla, kaydırılabilir bir Scaffold içinde gösterir.
Widget themed(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    );

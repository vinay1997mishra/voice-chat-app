import 'package:flutter/material.dart';
import 'anamika_repair_page.dart';

void main() => runApp(
      MaterialApp(
        title: 'Anamika AI',
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        home: const AnamikaRepairPage(),
      ),
    );

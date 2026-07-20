import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/controllers/workspace_controller.dart';
import 'src/engine/azpdf_engine_client.dart';
import 'src/ui/workspace_page.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  runApp(
    AZpdfApp(
      initialPaths: arguments
          .where((path) => path.toLowerCase().endsWith('.pdf'))
          .toList(growable: false),
    ),
  );
}

class AZpdfApp extends StatelessWidget {
  const AZpdfApp({super.key, this.controller, this.initialPaths = const []});

  final WorkspaceController? controller;
  final List<String> initialPaths;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2554);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
      primary: navy,
      secondary: const Color(0xFF0078D4),
      surface: const Color(0xFFF8FAFD),
    );
    return MaterialApp(
      title: 'AZpdf',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
        scaffoldBackgroundColor: const Color(0xFFF0F3F8),
        tooltipTheme: const TooltipThemeData(
          waitDuration: Duration(milliseconds: 350),
        ),
        focusColor: const Color(0x330078D4),
        dividerColor: const Color(0xFFD9E0EA),
      ),
      home: WorkspacePage(
        controller: controller ?? WorkspaceController(AzpdfEngineClient()),
        ownsController: controller == null,
        initialPaths: initialPaths,
      ),
    );
  }
}

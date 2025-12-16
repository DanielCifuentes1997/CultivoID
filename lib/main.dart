import 'package:flutter/material.dart';
import 'src/services/locator.dart';
import 'src/navigation/app_router.dart';
import 'src/theme/app_theme.dart';
import 'src/screens/splash_screen.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print("Main: Iniciando ServiceLocator...");
    // Esperar a que los servicios estén listos ANTES de mostrar nada
    await ServiceLocator.init();
    print("Main: ServiceLocator inicializado correctamente.");
  } catch (e) {
    print("Main: ERROR CRÍTICO inicializando ServiceLocator: $e");
    // Considerar mostrar una pantalla de error aquí
  }
  runApp(const CultivoIDApp()); // <<< CAMBIO AQUÍ
}

class CultivoIDApp extends StatefulWidget { // <<< CAMBIO AQUÍ
  const CultivoIDApp({super.key});

  @override
  State<CultivoIDApp> createState() => _CultivoIDAppState(); // <<< CAMBIO AQUÍ
}

class _CultivoIDAppState extends State<CultivoIDApp> { 
  // Estado para controlar si se muestra el splash
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar SplashScreen o la MaterialApp principal según el estado
    if (_showSplash) {
      // Muestra el SplashScreen
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(onStart: () {
           // Si el usuario presiona "Comenzar" antes de que acabe el timer
           if (mounted) { setState(() => _showSplash = false); }
        }),
      );
    } else {
      // Muestra la app principal con el router
      return MaterialApp.router(
        title: 'CultivoID', // Este ya estaba correcto
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: buildRouter(), // Usar el router existente
      );
    }
  }
}
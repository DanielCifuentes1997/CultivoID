import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // Mantengo la importación si la usas en otro lado o por si acaso

class SplashScreen extends StatelessWidget {
  final VoidCallback onStart;

  const SplashScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth * 1.0; // Puedes ajustar 0.7 (ej. 0.6 o 0.8)

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de CultivoID
            Image.asset(
              'assets/images/CultivoID.png', // Asegúrate que el nombre sea correcto
              width: logoSize,
              height: logoSize, 
              fit: BoxFit.contain, // Asegura que la imagen quepa sin distorsionarse
            ),
            const SizedBox(height: 20), // Espacio entre logo y texto
            // Texto de bienvenida
            const Text(
              'Bienvenido',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
              const SizedBox(height: 8),
            // Subtítulo
            const Text(
              'by DCore Labs',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 50), // Espacio entre subtítulo y botón
            // Botón Comenzar
            ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color(0xFF0A6042),
                backgroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              child: const Text('Comenzar'),
            ),
          ],
        ),
      ),
    );
  }
}
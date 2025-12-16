import 'package:shared_preferences/shared_preferences.dart';

import 'attendance_service.dart';
import 'embedding_service.dart';
import 'face_detector_service.dart';
import 'recognition_service.dart';
import 'sync_service.dart';
import 'secure_key_service.dart';
import 'auth_service.dart';

class ServiceLocator {
  static SharedPreferences? _prefs;
  static FaceDetectorService? _faceDetectorService;
  static EmbeddingService? _embeddingService;
  static RecognitionService? _recognitionService;
  static AttendanceService? _attendanceService;
  static SyncService? _syncService;
  static SecureKeyService? _secureKeyService;
  static String? _dbKey;
  static AuthService? _authService;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    _secureKeyService ??= SecureKeyService();
    _dbKey = await _secureKeyService!.getOrCreateEncryptionKey();

    _faceDetectorService ??= FaceDetectorService();
    _embeddingService ??= EmbeddingService();
    _authService ??= AuthService();

    // Inicializar RecognitionService (con try-catch por seguridad)
    try {
      _recognitionService ??= RecognitionService(_prefs!, _dbKey!);
      print("ServiceLocator: Intentando inicializar RecognitionService...");
      await _recognitionService!.init();
      print("ServiceLocator: RecognitionService inicializado correctamente.");
    } catch (e, s) {
      print("ServiceLocator: !!!!!!!!!! ERROR GRAVE AL INICIALIZAR RecognitionService !!!!!!!!!!");
      print("Error: $e");
      print("Stack trace: $s");
    }

    // Inicializar otros servicios (con try-catch por seguridad)
    try {
      _attendanceService ??= AttendanceService(_prefs!);
      await _attendanceService!.init();
    } catch (e, s) {
       print("ServiceLocator: !!!!!!!!!! ERROR GRAVE AL INICIALIZAR AttendanceService !!!!!!!!!!");
       print("Error: $e");
       print("Stack trace: $s");
    }

    try {
      _syncService ??= SyncService();
      await _syncService!.init();
    } catch (e, s) {
      print("ServiceLocator: !!!!!!!!!! ERROR GRAVE AL INICIALIZAR SyncService !!!!!!!!!!");
      print("Error: $e");
      print("Stack trace: $s");
    }


    // <<< CAMBIO PRINCIPAL: Carga del NUEVO modelo TFLite >>>
    // Aseguramos que la carga del modelo TFLite vaya al final.
    if (!(_embeddingService?.isLoaded ?? false)) {
      final String? path = _prefs!.getString('custom_model_path');
      if (path != null && path.isNotEmpty) {
        print("ServiceLocator: Intentando cargar modelo TFLite personalizado desde: $path");
        await _embeddingService!.loadModelFromFile(path);
      }
    }

    // Intentar cargar el nuevo modelo ArcFace desde assets si no se cargó uno custom
    if (!(_embeddingService?.isLoaded ?? false)) {
      // <<< ESTA ES LA LÍNEA CLAVE ACTUALIZADA >>>
      const String modelAssetPath = 'assets/models/mobilenet_arcface_optimized.tflite';
      print("ServiceLocator: Intentando cargar modelo TFLite desde assets: $modelAssetPath");
      await _embeddingService!.loadModelFromAsset(modelAssetPath);
    }

    // Comprobar si el modelo (el nuevo) se cargó correctamente
    if (!(_embeddingService?.isLoaded ?? false)) {
        print("ServiceLocator: !!!!!!!!! ERROR CRÍTICO !!!!!!!!!");
        print("El modelo TFLite ('mobilenet_arcface_optimized.tflite') no pudo ser cargado.");
        print("Último error registrado: ${_embeddingService?.lastError}");
        print("Asegúrate de que el archivo existe en 'assets/models/' y está declarado en pubspec.yaml.");
    } else {
       print("ServiceLocator: Modelo TFLite cargado exitosamente.");
    }
  } // Fin de init()

  static Future<void> setCustomModelPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs!.remove('custom_model_path');
      return;
    }
    await _prefs!.setString('custom_model_path', path);
  }

  static SharedPreferences get prefs => _prefs!;
  static FaceDetectorService get faceDetector => _faceDetectorService!;
  static EmbeddingService get embedder => _embeddingService!;
  // Getters con comprobación de nulidad
  static RecognitionService get recognition {
    if (_recognitionService == null) throw StateError("RecognitionService no fue inicializado correctamente.");
    return _recognitionService!;
  }
  static AttendanceService get attendance {
     if (_attendanceService == null) throw StateError("AttendanceService no fue inicializado correctamente.");
    return _attendanceService!;
  }
  static SyncService get sync {
     if (_syncService == null) throw StateError("SyncService no fue inicializado correctamente.");
    return _syncService!;
  }
  static String get dbKey => _dbKey!;
  static AuthService get auth => _authService!;
}
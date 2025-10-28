import 'dart:typed_data';
import 'dart:io';
import 'dart:math'; // <<< AÑADIDO: Para sqrt >>>

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class EmbeddingService {
  EmbeddingService();

  tfl.Interpreter? _interpreter;
  bool _loaded = false;
  String? _lastError;
  String _source = 'none';

  Future<void> loadModelFromAsset(String assetPath) async {
    // ... (sin cambios) ...
      if (_interpreter != null) return;
      try {
        _interpreter = await tfl.Interpreter.fromAsset(assetPath);
        _loaded = true;
        _lastError = null;
        _source = 'asset';
      } catch (e) {
        _loaded = false;
        _lastError = e.toString();
      }
  }

  Future<void> loadModelFromFile(String filePath) async {
    // ... (sin cambios) ...
      try {
        await close();
        final tfl.InterpreterOptions options = tfl.InterpreterOptions();
        _interpreter = await tfl.Interpreter.fromFile(File(filePath), options: options);
        _loaded = true;
        _lastError = null;
        _source = 'file';
      } catch (e) {
        _loaded = false;
        _lastError = e.toString();
      }
  }

  // <<< CAMBIO: Añadida función para normalización L2 >>>
  List<double> _l2Normalize(List<double> vector) {
    if (vector.isEmpty) return vector; // Evitar división por cero

    double sumSquare = 0.0;
    for (double val in vector) {
      sumSquare += val * val;
    }
    // Calcular la norma (magnitud)
    double norm = sqrt(sumSquare);

    // Evitar división por cero si la norma es muy pequeña
    if (norm < 1e-6) { // Usamos un umbral pequeño (epsilon)
      // Si el vector es casi cero, devolverlo tal cual o un vector de ceros
      return List<double>.filled(vector.length, 0.0);
    }

    // Normalizar cada elemento dividiendo por la norma
    List<double> normalizedVector = List<double>.generate(
      vector.length,
      (index) => vector[index] / norm,
    );
    return normalizedVector;
  }

  List<double> runEmbedding(List<List<List<double>>> input) {
    final tfl.Interpreter? interpreter = _interpreter;
    if (interpreter == null || !_loaded) {
      throw StateError('Interpreter not loaded: ${_lastError ?? 'model not loaded'}');
    }
    try {
      final List<int> inputShape = interpreter.getInputTensor(0).shape;
      final bool expectsBatch = inputShape.length == 4;
      final dynamic modelInput = expectsBatch ? [input] : input;

      final List<int> outputShape = interpreter.getOutputTensor(0).shape;
      dynamic modelOutput;
      // Determinar el tamaño esperado del embedding (última dimensión)
      final int embeddingSize = outputShape.last;

      // Crear el buffer de salida correctamente para cualquier forma
      // Asumiendo que la salida relevante es siempre la última dimensión
       if (outputShape.length == 2 && outputShape[0] == 1) {
         // Forma [1, size]
         modelOutput = List.generate(1, (_) => List<double>.filled(embeddingSize, 0));
       } else if (outputShape.length == 4 && outputShape[0] == 1 && outputShape[1] == 1 && outputShape[2] == 1) {
         // Forma [1, 1, 1, size]
         modelOutput = List.generate(1, (_) => List.generate(1, (_) => List.generate(1, (_) => List<double>.filled(embeddingSize, 0))));
       } else if (outputShape.length == 1) {
          // Forma [size] (menos común para embeddings)
           modelOutput = List<double>.filled(embeddingSize, 0);
       }
       else {
         // Fallback genérico, asumiendo batch=1 y extrayendo el último vector
         // Esto podría necesitar ajustes si el modelo tiene una forma de salida muy inusual
         print("EmbeddingService: WARN - Forma de salida no estándar detectada: $outputShape. Intentando extraer vector de tamaño $embeddingSize.");
         // Crear una lista anidada que coincida con la forma, luego extraeremos
          dynamic createNestedList(List<int> shape) {
            if (shape.length == 1) return List<double>.filled(shape[0], 0.0);
            return List.generate(shape[0], (_) => createNestedList(shape.sublist(1)));
          }
          modelOutput = createNestedList(outputShape);
       }

      // Ejecutar la inferencia
      interpreter.run(modelInput, modelOutput);

      // Extraer el resultado como un List<double> plano
      List<double> rawEmbedding = [];
      if (modelOutput is List<double>) {
        rawEmbedding = modelOutput;
      } else if (modelOutput is List) {
        // Aplanar la lista resultante (maneja [1, size], [1,1,1,size], etc.)
        dynamic current = modelOutput;
        while (current is List && current.isNotEmpty && current.first is List) {
          current = current.first;
        }
        if (current is List<double>) {
          rawEmbedding = current;
        } else {
           // Si aún no es List<double>, intentar aplanar manualmente (fallback)
           rawEmbedding = List<double>.filled(embeddingSize, 0.0);
           int idx = 0;
           void flatten(dynamic v) {
             if (idx >= embeddingSize) return;
             if (v is List) { for (final e in v) flatten(e); }
             else if (v is num) { rawEmbedding[idx++] = v.toDouble(); }
           }
           flatten(modelOutput);
        }
      }

      // <<< CAMBIO: Aplicar Normalización L2 antes de devolver >>>
      if (rawEmbedding.isNotEmpty) {
        return _l2Normalize(rawEmbedding);
      } else {
         print("EmbeddingService: ERROR - No se pudo extraer el embedding del modelOutput.");
         return List<double>.filled(embeddingSize, 0.0); // Devolver vector de ceros en caso de error
      }

    } catch (e) {
      _lastError = e.toString();
      print("EmbeddingService: ERROR durante runEmbedding: $e"); // Imprimir error
      rethrow; // Relanzar para que sea capturado más arriba si es necesario
    }
  }

  Future<void> close() async {
    // ... (sin cambios) ...
      _interpreter?.close();
      _interpreter = null;
      _loaded = false;
      _lastError = null;
      _source = 'none';
  }

  bool get isLoaded => _loaded;
  String? get lastError => _lastError;
  String get source => _source;
}
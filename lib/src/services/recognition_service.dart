// ****** recognition_service.dart (CON GESTIÓN DE ÁREAS y EMBEDDING 512d) ******
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui'; // Para Endian

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sql;
import 'package:path/path.dart' as p;

import '../models/recognized_person.dart';

class Area {
  final int id;
  final String nombre;
  Area({required this.id, required this.nombre});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Area && runtimeType == other.runtimeType && id == other.id;
  @override
  int get hashCode => id.hashCode;
  @override
  String toString() => nombre;
}


class RecognitionService {
  RecognitionService(this._prefs, this._encryptionKey);

  final SharedPreferences _prefs;
  final String _encryptionKey;
  sql.Database? _db;
  sql.Database get database => _db!;

  static const String _dbName = 'reconocimiento_biometrico.sqlite';
  static const String _tableEmployees = 'empleados';
  static const String _tableBiometrics = 'datos_biometricos';
  static const String _tableAttendance = 'registros_asistencia';
  static const String _tableAreas = 'areas';

  List<_CacheEntry>? _cache;

  String get cacheStatus => _cache == null ? 'No inicializado' : '${_cache!.length} entradas';

  // <<< CAMBIO: Ajustado para 512 dimensiones >>>
  List<double>? _blobToVector(Uint8List blob, int empleadoId) {
      const int expectedBytes = 4096; // 512 doubles * 8 bytes/double
      const int vectorLength = 512;   // Nueva dimensión del embedding
      if (blob.lengthInBytes == expectedBytes) {
          try {
              ByteData byteData = blob.buffer.asByteData(blob.offsetInBytes, blob.lengthInBytes);
              List<double> vectorResult = List<double>.filled(vectorLength, 0.0);
              for (int i = 0; i < vectorLength; i++) {
                  // Asumimos que TFLite usa el Endian nativo del dispositivo
                  vectorResult[i] = byteData.getFloat64(i * 8, Endian.host);
              }
              return vectorResult;
          } catch (e) {
              print('RecognitionService: ERROR [LOAD BLOB 512d] Convirtiendo BLOB para ID $empleadoId: $e');
              return null;
          }
      } else {
         print('RecognitionService: WARN [LOAD BLOB 512d] - Se esperaba BLOB de $expectedBytes bytes pero se recibió ${blob.lengthInBytes} para ID $empleadoId.');
         return null;
      }
  }

  Future<void> init() async {
    // ... (sin cambios en init, _createAllTables, _migrateV2toV3) ...
      if (_db != null) return;
      final String dbDir = await sql.getDatabasesPath();
      final String path = p.join(dbDir, _dbName);
      _db = await sql.openDatabase(
        path, version: 3,
        onCreate: (db, version) async { await _createAllTables(db, version); },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('RecognitionService: Actualizando BD de v$oldVersion a v$newVersion');
          if (oldVersion < 2) {
             try { await db.execute('ALTER TABLE $_tableAttendance ADD COLUMN sincronizado INTEGER DEFAULT 0'); print('RecognitionService: Migración v1->v2 completada.'); } catch (e) { print('RecognitionService: WARN v1->v2: $e'); }
          }
          if (oldVersion < 3) { await _migrateV2toV3(db); }
        },
        password: _encryptionKey,
      );
      await _warmCache();
  }

  Future<void> _createAllTables(sql.Database db, int version) async {
       print('RecognitionService: Creando tablas (onCreate) para v$version...');
       await db.execute('CREATE TABLE $_tableAreas (id_area INTEGER PRIMARY KEY AUTOINCREMENT, nombre_area TEXT NOT NULL UNIQUE)');
       print('RecognitionService: Tabla $_tableAreas creada.');
       await db.execute('''CREATE TABLE $_tableEmployees (
            id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, documento TEXT UNIQUE,
            cargo TEXT, telefono TEXT, imagePath TEXT, eps TEXT, contacto_emergencia_nombre TEXT,
            contacto_emergencia_telefono TEXT, tipo_sangre TEXT, alergias TEXT, id_area INTEGER,
            FOREIGN KEY(id_area) REFERENCES $_tableAreas(id_area) ON DELETE SET NULL )''');
       print('RecognitionService: Tabla $_tableEmployees creada.');
       await db.execute('CREATE TABLE $_tableBiometrics (id_biometrico INTEGER PRIMARY KEY AUTOINCREMENT, id_empleado INTEGER NOT NULL, tipo_biometria TEXT NOT NULL DEFAULT \'rostro\', vector_biometrico BLOB, fecha_registro TEXT DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(id_empleado) REFERENCES $_tableEmployees(id) ON DELETE CASCADE)');
       await db.execute('CREATE TABLE $_tableAttendance (id_registro INTEGER PRIMARY KEY AUTOINCREMENT, id_empleado INTEGER NOT NULL, id_dispositivo TEXT NOT NULL, tipo_evento TEXT NOT NULL, fecha_hora TEXT DEFAULT CURRENT_TIMESTAMP, validado_biometricamente INTEGER DEFAULT 1, sincronizado INTEGER DEFAULT 0, observaciones TEXT)');
       print('RecognitionService: Tablas $_tableBiometrics y $_tableAttendance creadas.');
   }

  Future<void> _migrateV2toV3(sql.Database db) async {
       print('RecognitionService: Iniciando migración v2->v3...');
       try {
           await db.execute('CREATE TABLE $_tableAreas (id_area INTEGER PRIMARY KEY AUTOINCREMENT, nombre_area TEXT NOT NULL UNIQUE)');
           print('RecognitionService: v2->v3 - Tabla $_tableAreas creada.');
           final List<Map<String, Object?>> distinctAreas = await db.query(_tableEmployees, columns: ['area'], distinct: true, where: 'area IS NOT NULL AND area != ?', whereArgs: ['']);
           print('RecognitionService: v2->v3 - Se encontraron ${distinctAreas.length} áreas únicas.');
           final Map<String, int> areaNameToIdMap = {};
           for (final row in distinctAreas) {
               final String areaName = row['area'] as String;
               if (areaName.isNotEmpty) {
                   try { final int newAreaId = await db.insert(_tableAreas, {'nombre_area': areaName}, conflictAlgorithm: sql.ConflictAlgorithm.ignore); if (newAreaId > 0) areaNameToIdMap[areaName] = newAreaId; } catch (e) { print('RecognitionService: v2->v3 - Error insertando área "$areaName": $e');}
               }
           }
           await db.execute('ALTER TABLE $_tableEmployees ADD COLUMN id_area INTEGER');
           print('RecognitionService: v2->v3 - Columna id_area añadida.');
           for (final areaName in areaNameToIdMap.keys) {
               final int areaId = areaNameToIdMap[areaName]!;
               try { await db.update(_tableEmployees, {'id_area': areaId}, where: 'area = ?', whereArgs: [areaName]); } catch(e) { print('RecognitionService: v2->v3 - Error actualizando empleados para área "$areaName": $e');}
           }
           print('RecognitionService: v2->v3 - Columna "area" antigua no se eliminará.');
           print('RecognitionService: Migración v2->v3 completada.');
       } catch (e) { print('RecognitionService: ERROR CRÍTICO durante migración v2->v3: $e'); }
   }


  Future<void> _warmCache() async {
    // ... (sin cambios en _warmCache, ya usa _blobToVector que hemos modificado) ...
      print('RecognitionService: Iniciando _warmCache (v3)...');
      if (_db == null) { _cache = []; return; }
      final sql.Database useDb = _db!;
      final List<Map<String, Object?>> empRows = await useDb.rawQuery('SELECT e.*, a.nombre_area FROM $_tableEmployees e LEFT JOIN $_tableAreas a ON e.id_area = a.id_area');
      final List<Map<String, Object?>> bioRows = await useDb.query(_tableBiometrics);
      final Map<int, Map<String, Object?>> employeeMap = { for (var row in empRows) (row['id'] as int): row };
      final Map<int, List<List<double>>> groupedVectors = {};
      for (final r in bioRows) {
          final int empId = r['id_empleado'] as int;
          final dynamic vectorBlob = r['vector_biometrico'];
          if (vectorBlob is Uint8List) {
              List<double>? vector = _blobToVector(vectorBlob, empId);
              if (vector != null) { groupedVectors.putIfAbsent(empId, () => []).add(vector); }
          }
      }
      final List<_CacheEntry> list = <_CacheEntry>[];
      for (final empId in groupedVectors.keys) {
          final employeeData = employeeMap[empId];
          if (employeeData != null && groupedVectors[empId]!.isNotEmpty) {
               list.add( _CacheEntry(
                   idEmpleado: empId, vectors: groupedVectors[empId]!,
                   nombre: employeeData['nombre'] as String?, documento: employeeData['documento'] as String?,
                   cargo: employeeData['cargo'] as String?, telefono: employeeData['telefono'] as String?,
                   imagePath: employeeData['imagePath'] as String?, area: employeeData['nombre_area'] as String?,
                   eps: employeeData['eps'] as String?, contactoNombre: employeeData['contacto_emergencia_nombre'] as String?,
                   contactoTelefono: employeeData['contacto_emergencia_telefono'] as String?, tipoSangre: employeeData['tipo_sangre'] as String?,
                   alergias: employeeData['alergias'] as String?,
                 ),);
          }
      }
      _cache = list;
      print('RecognitionService: _warmCache (v3) completado. ${_cache?.length ?? 0} rostros cargados.');
  }


  Future<bool> checkIfDocumentExists(String document) async {
    // ... (sin cambios) ...
      final db = _db; if (db == null) return false;
      final rows = await db.query(_tableEmployees, columns: ['id'], where: 'documento = ?', whereArgs: [document], limit: 1);
      return rows.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getEmployeeDetailsByDocument(String document) async {
    // ... (sin cambios) ...
      final db = _db; if (db == null) return null;
      final rows = await db.rawQuery('SELECT e.*, a.nombre_area FROM $_tableEmployees e LEFT JOIN $_tableAreas a ON e.id_area = a.id_area WHERE e.documento = ? LIMIT 1', [document]);
      return rows.isNotEmpty ? rows.first.cast<String, dynamic>() : null;
  }

  Future<int?> getOrCreateArea(String areaName) async {
    // ... (sin cambios) ...
     if (areaName.trim().isEmpty) return null;
     final db = _db; if (db == null) await init();
     final sql.Database useDb = _db!;
     final List<Map<String, Object?>> existing = await useDb.query(_tableAreas, columns: ['id_area'], where: 'nombre_area = ?', whereArgs: [areaName.trim()], limit: 1);
     if (existing.isNotEmpty) { return existing.first['id_area'] as int; }
     else {
       try { final int newId = await useDb.insert(_tableAreas, {'nombre_area': areaName.trim()}, conflictAlgorithm: sql.ConflictAlgorithm.ignore); return newId > 0 ? newId : null; }
       catch (e) { print('RecognitionService: Error creando área "$areaName": $e'); final retryRead = await useDb.query(_tableAreas, columns: ['id_area'], where: 'nombre_area = ?', whereArgs: [areaName.trim()], limit: 1); if (retryRead.isNotEmpty) return retryRead.first['id_area'] as int; return null; }
     }
  }

  Future<List<Area>> getAllAreas() async {
    // ... (sin cambios) ...
      final db = _db; if (db == null) await init();
      final sql.Database useDb = _db!;
      final List<Map<String, Object?>> rows = await useDb.query(_tableAreas, orderBy: 'nombre_area ASC');
      return rows.map((row) => Area(id: row['id_area'] as int, nombre: row['nombre_area'] as String)).toList();
  }


  Future<int> upsertEmployee({
    required String nombre, required String documento,
    String? cargo, String? telefono, String? imagePath, String? areaName,
    String? eps, String? contactoNombre, String? contactoTelefono, String? tipoSangre, String? alergias,
  }) async {
    // ... (sin cambios) ...
      final db = _db; if (db == null) await init();
      final sql.Database useDb = _db!;
      int? areaId; if (areaName != null && areaName.isNotEmpty) areaId = await getOrCreateArea(areaName);
      final data = {'nombre': nombre, 'documento': documento, 'cargo': cargo, 'telefono': telefono, 'imagePath': imagePath, 'id_area': areaId, 'eps': eps, 'contacto_emergencia_nombre': contactoNombre, 'contacto_emergencia_telefono': contactoTelefono, 'tipo_sangre': tipoSangre, 'alergias': alergias, };
      data.removeWhere((key, value) => value == null);
      final rows = await useDb.query(_tableEmployees, columns: ['id'], where: 'documento = ?', whereArgs: [documento], limit: 1);
      if (rows.isNotEmpty) { final foundId = rows.first['id'] as int; await useDb.update(_tableEmployees, data, where: 'id = ?', whereArgs: [foundId]); return foundId; }
      else { try { final newId = await useDb.insert(_tableEmployees, data, conflictAlgorithm: sql.ConflictAlgorithm.fail); return newId; } catch (e) { print('RecognitionService: ERROR insertando empleado: $e'); final retryRead = await useDb.query(_tableEmployees, columns: ['id'], where: 'documento = ?', whereArgs: [documento], limit: 1); if (retryRead.isNotEmpty) return retryRead.first['id'] as int; return -1; } }
  }

  Future<void> saveIdentityWithDetails({
    required List<List<double>> embeddings,
    required String name, required String document,
    String? imagePath, String? cargo, String? telefono, String? areaName,
    String? eps, String? contactoNombre, String? contactoTelefono, String? tipoSangre, String? alergias,
  }) async {
    // ... (sin cambios) ...
      final int empId = await upsertEmployee( nombre: name, documento: document, cargo: cargo, telefono: telefono, imagePath: imagePath, areaName: areaName, eps: eps, contactoNombre: contactoNombre, contactoTelefono: contactoTelefono, tipoSangre: tipoSangre, alergias: alergias, );
      if (empId <= 0) throw Exception("Fallo al guardar/actualizar empleado.");
      await _db?.delete(_tableBiometrics, where: 'id_empleado = ?', whereArgs: [empId]);
      print('RecognitionService: Vectores biométricos antiguos eliminados para ID: $empId');
      for (final embedding in embeddings) { await _insertBiometricVector(empId, embedding); }
      await _updateCacheForEmployee(empId);
  }

  // <<< CAMBIO: Ajustado para 512 dimensiones >>>
  Future<void> _insertBiometricVector(int empleadoId, List<double> embedding) async {
      final db = _db; if (db == null) return;
      final sql.Database useDb = db;

      // Asegurar que el embedding tenga 512 dimensiones
      if (embedding.length != 512) {
           print('RecognitionService: ERROR CRÍTICO [SAVE 512d] - Embedding recibido con ${embedding.length} dimensiones. Se esperaban 512. Omitiendo guardado para ID $empleadoId.');
           return;
      }

      final Float64List vec64 = Float64List.fromList(embedding);
      final Uint8List blob = vec64.buffer.asUint8List(vec64.offsetInBytes, vec64.lengthInBytes);

      // Comprobar tamaño del BLOB (debe ser 4096 bytes)
      if (blob.lengthInBytes != 4096) {
          print('RecognitionService: ERROR CRÍTICO [SAVE 512d] - BLOB generado con ${blob.lengthInBytes} bytes. Se esperaban 4096. Omitiendo guardado para ID $empleadoId.');
          return;
      }

      await useDb.insert( _tableBiometrics, {'id_empleado': empleadoId, 'tipo_biometria': 'rostro', 'vector_biometrico': blob}, );
      // print('RecognitionService: Vector biométrico (512d) guardado para ID: $empleadoId.');
  }

  Future<void> _updateCacheForEmployee(int empleadoId) async {
    // ... (sin cambios, ya usa _blobToVector modificado) ...
      if (_db == null) return;
      final rows = await _db!.rawQuery('SELECT e.*, a.nombre_area FROM $_tableEmployees e LEFT JOIN $_tableAreas a ON e.id_area = a.id_area WHERE e.id = ? LIMIT 1', [empleadoId]);
      if (rows.isEmpty) return;
      final employeeData = rows.first;
      final bioRows = await _db!.query(_tableBiometrics, where: 'id_empleado = ?', whereArgs: [empleadoId]);
      final List<List<double>> vectors = [];
      for (final row in bioRows) {
          final dynamic vectorBlob = row['vector_biometrico'];
          if (vectorBlob is Uint8List) { List<double>? vector = _blobToVector(vectorBlob, empleadoId); if (vector != null) vectors.add(vector); }
      }
      if (vectors.isNotEmpty) {
         final entry = _CacheEntry( idEmpleado: empleadoId, vectors: vectors, nombre: employeeData['nombre'] as String?, documento: employeeData['documento'] as String?, cargo: employeeData['cargo'] as String?, telefono: employeeData['telefono'] as String?, imagePath: employeeData['imagePath'] as String?, area: employeeData['nombre_area'] as String?, eps: employeeData['eps'] as String?, contactoNombre: employeeData['contacto_emergencia_nombre'] as String?, contactoTelefono: employeeData['contacto_emergencia_telefono'] as String?, tipoSangre: employeeData['tipo_sangre'] as String?, alergias: employeeData['alergias'] as String?, );
         _cache ??= <_CacheEntry>[];
         final idx = _cache!.indexWhere((e) => e.idEmpleado == empleadoId);
         if (idx >= 0) { _cache![idx] = entry; } else { _cache!.add(entry); }
          print('RecognitionService: Cache actualizado para ID $empleadoId (Área: ${entry.area ?? "N/A"})');
      } else { print('RecognitionService: WARN - No se pudo actualizar caché para ID $empleadoId (sin vectores).'); }
  }


  Future<List<Map<String, dynamic>>> readAllEmployees() async {
    // ... (sin cambios) ...
      final db = _db; if (db == null) await init();
      final sql.Database useDb = _db!;
      final List<Map<String, Object?>> rows = await useDb.rawQuery('SELECT e.*, a.nombre_area FROM $_tableEmployees e LEFT JOIN $_tableAreas a ON e.id_area = a.id_area ORDER BY e.nombre ASC');
       return rows.map((row) { final map = Map<String, dynamic>.from(row); map['area'] = map.remove('nombre_area'); return map; }).toList();
  }

  Future<void> deleteEmployee(String personId, {bool deleteImage = true}) async {
    // ... (sin cambios) ...
      final db = _db; if (db == null) await init();
      final sql.Database useDb = _db!;
      final int id = int.tryParse(personId) ?? -1;
      if (id <= 0) return;
      String? imagePath;
      try { final rows = await useDb.query(_tableEmployees, where: 'id = ?', whereArgs: [id], limit: 1); if (rows.isNotEmpty) imagePath = rows.first['imagePath'] as String?; } catch (_) {}
      await useDb.delete(_tableBiometrics, where: 'id_empleado = ?', whereArgs: [id]);
      final deletedRows = await useDb.delete(_tableEmployees, where: 'id = ?', whereArgs: [id]);
      print('RecognitionService: Empleado ID $id eliminado ($deletedRows filas afectadas).');
      _cache?.removeWhere((e) => e.idEmpleado == id);
      if (deleteImage && imagePath != null && imagePath.isNotEmpty) { try { final File f = File(imagePath); if (await f.exists()) { await f.delete(); print('RecognitionService: Imagen eliminada: $imagePath'); } } catch (e) { print('RecognitionService: WARN - Error eliminando imagen $imagePath: $e'); } }
  }

  //Ajustado threshold inicial para 512d >>>
  Future<RecognizedPerson?> identify(List<double> embedding, {double threshold = 0.75}) async { 
      if (embedding.length != 512) {
           print('RecognitionService: ERROR [IDENTIFY 512d] - Se recibió embedding con ${embedding.length} dimensiones. Se esperaban 512.');
           return null; // No intentar comparar si la dimensión es incorrecta
      }

      if (_cache == null) { await _warmCache(); }
      if (_cache == null || _cache!.isEmpty) { print('RecognitionService: identify() - El caché está vacío.'); return null; }

      String? bestId; double bestDist = double.infinity; _CacheEntry? bestMatchEntry;

      for (final _CacheEntry entry in _cache!) {
         double employeeMinDist = double.infinity;

         for (final vector in entry.vectors) {
             // Comprobar longitud del vector cacheado también
             if (vector.length != 512) {
                 print('RecognitionService: WARN [IDENTIFY 512d] - Vector cacheado para ID ${entry.idEmpleado} tiene ${vector.length} dims.');
                 continue; // Saltar este vector si es inválido
             }
             final double dist = _euclidean(embedding, vector);
             if (dist < employeeMinDist) { employeeMinDist = dist; }
         }

         if (employeeMinDist < bestDist) {
            bestDist = employeeMinDist;
            bestId = entry.idEmpleado.toString();
            bestMatchEntry = entry;
         }
      }

      // Usar el nuevo threshold
      if (bestId != null && bestMatchEntry != null && bestDist <= threshold) {
          print('RecognitionService: Identificación exitosa (512d) - ID: $bestId (${bestMatchEntry.nombre ?? 'N/A'}), Dist: $bestDist (Umbral: $threshold)');
          return RecognizedPerson(
            id: bestId, name: bestMatchEntry.nombre, document: bestMatchEntry.documento, cargo: bestMatchEntry.cargo, telefono: bestMatchEntry.telefono,
            imagePath: bestMatchEntry.imagePath, distance: bestDist, area: bestMatchEntry.area,
            eps: bestMatchEntry.eps, contactoNombre: bestMatchEntry.contactoNombre, contactoTelefono: bestMatchEntry.contactoTelefono, tipoSangre: bestMatchEntry.tipoSangre,
            alergias: bestMatchEntry.alergias,
          );
      }
      else if (bestId != null) { print('RecognitionService: No reconocido (512d) - Mejor match ID: $bestId (${bestMatchEntry?.nombre ?? 'N/A'}), Dist: $bestDist (Umbral: $threshold)'); }
      else { print('RecognitionService: No se encontró ningún match (512d).'); }
      return null;
  }

  // <<< CAMBIO: _euclidean ahora verifica que ambas listas tengan 512 >>>
  double _euclidean(List<double> a, List<double> b) {
      // Doble verificación por seguridad
      if (a.length != 512 || b.length != 512) {
         print('RecognitionService: ERROR [EUCLIDEAN 512d] - Longitudes de vector no coinciden (${a.length} vs ${b.length}).');
         return double.infinity; // Devolver distancia infinita si las longitudes no coinciden
      }
      const int n = 512; // Usar la longitud fija
      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        final double d = a[i] - b[i];
        sum += d * d;
      }
      // La raíz cuadrada solo si sum es positivo, sino 0.0
      return sum > 0 ? sqrt(sum) : 0.0;
  }

} // Fin clase RecognitionService


// _CacheEntry no necesita cambios estructurales, ya usa List<double>
class _CacheEntry {
  _CacheEntry({
    required this.idEmpleado, required this.vectors,
    this.nombre, this.documento, this.cargo, this.telefono, this.imagePath,
    this.area, this.eps, this.contactoNombre, this.contactoTelefono, this.tipoSangre, this.alergias,
  });
   final int idEmpleado;
   final List<List<double>> vectors; // Ya es genérico
   final String? nombre; final String? documento; final String? cargo; final String? telefono; final String? imagePath;
   final String? area;
   final String? eps; final String? contactoNombre; final String? contactoTelefono; final String? tipoSangre; final String? alergias;
}
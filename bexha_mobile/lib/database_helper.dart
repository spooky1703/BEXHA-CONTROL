import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'bexha_matrix_v2.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Ejidatarios Table (Seeded from JSON)
    await db.execute('''
      CREATE TABLE ejidatarios (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        lote TEXT NOT NULL,
        barrio TEXT
      )
    ''');

    // 2. Ciclos Table (Tracks crop cycles per user)
    await db.execute('''
      CREATE TABLE ciclos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ejidatario_id INTEGER NOT NULL,
        cultivo TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (ejidatario_id) REFERENCES ejidatarios(id)
      )
    ''');

    // 3. Riegos Matrix Table (The grid)
    await db.execute('''
      CREATE TABLE riegos_matrix (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ciclo_id INTEGER NOT NULL,
        numero_riego INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        paraje TEXT NOT NULL,
        UNIQUE(ciclo_id, numero_riego),
        FOREIGN KEY (ciclo_id) REFERENCES ciclos(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE dias_sesiones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT,
        paraje TEXT NOT NULL,
        estado TEXT NOT NULL,
        total_escaneos INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE registros_escaneos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sesion_id INTEGER NOT NULL,
        paraje TEXT NOT NULL,
        lote TEXT NOT NULL,
        nombre TEXT NOT NULL,
        folio TEXT NOT NULL,
        cultivo TEXT NOT NULL,
        superficie TEXT NOT NULL,
        riego_numero TEXT NOT NULL,
        fecha_escaneo TEXT NOT NULL,
        FOREIGN KEY (sesion_id) REFERENCES dias_sesiones(id)
      )
    ''');
  }

  // --- Seeding ---
  Future<void> seedEjidatarios() async {
    final db = await database;
    
    // ALWAYS reload: delete existing data first
    await db.delete('ejidatarios');
    print('🗑️ Borrando ejidatarios antiguos...');
    
    // Load JSON from assets
    final String jsonString = await rootBundle.loadString('assets/ejidatarios.json');
    final List<dynamic> jsonData = json.decode(jsonString);
    
    print('📥 Cargando ${jsonData.length} ejidatarios desde JSON...');
    
    // Insert all
    for (var item in jsonData) {
      await db.insert('ejidatarios', {
        'id': item['id'],
        'nombre': item['nombre'],
        'lote': item['lote'],
        'barrio': item['barrio'],
      });
    }
    
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM ejidatarios');
    print('✅ ${count.first['count']} ejidatarios cargados en DB');
  }

  // --- Logic ---

  Future<Map<String, dynamic>?> getEjidatario(String nombre, String lote) async {
    final db = await database;
    
    // Normalize inputs
    final String cleanLote = lote.trim().toUpperCase();

    print('🔍 BUSCANDO: Lote="$cleanLote"');

    // Search ONLY by lote (most reliable)
    List<Map<String, dynamic>> res = await db.rawQuery(
      'SELECT * FROM ejidatarios WHERE TRIM(UPPER(lote)) = ?',
      [cleanLote]
    );
    
    if (res.isNotEmpty) {
      print('✅ ENCONTRADO: ${res.first['nombre']} (Lote: ${res.first['lote']})');
      return res.first;
    }

    // Debug: Show what we have in the database
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM ejidatarios');
    print('❌ NO ENCONTRADO. Total en DB: ${count.first['count']}');
    
    // Show first 5 lotes as sample
    final sample = await db.rawQuery('SELECT lote, nombre FROM ejidatarios LIMIT 5');
    print('📋 Muestra de lotes en DB:');
    for (var row in sample) {
      print('   - "${row['lote']}" -> ${row['nombre']}');
    }
    
    return null;
  }
  
  Future<List<Map<String, dynamic>>> getAllEjidatarios() async {
      final db = await database;
      return await db.query('ejidatarios', orderBy: 'nombre ASC');
  }

  Future<int> getOrCreateCiclo(int ejidatarioId, String cultivo) async {
    final db = await database;
    
    // Check for active cycle with SAME cultivo
    List<Map<String, dynamic>> active = await db.query(
      'ciclos',
      where: 'ejidatario_id = ? AND cultivo = ? AND activo = 1',
      whereArgs: [ejidatarioId, cultivo],
    );

    if (active.isNotEmpty) {
      // Same cultivo exists, return it
      return active.first['id'] as int;
    }

    // Create new cycle (even if other cultivos are active)
    return await db.insert('ciclos', {
      'ejidatario_id': ejidatarioId,
      'cultivo': cultivo,
      'fecha_inicio': DateTime.now().toIso8601String(),
      'activo': 1
    });
  }

  Future<List<Map<String, dynamic>>> getActiveCiclos(int ejidatarioId) async {
    final db = await database;
    return await db.query(
      'ciclos',
      where: 'ejidatario_id = ? AND activo = 1',
      whereArgs: [ejidatarioId],
    );
  }

  Future<void> registerRiego(int cicloId, int numeroRiego, String paraje) async {
    final db = await database;
    await db.insert(
      'riegos_matrix',
      {
        'ciclo_id': cicloId,
        'numero_riego': numeroRiego,
        'fecha': DateTime.now().toIso8601String(),
        'paraje': paraje
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Map<String, dynamic>>> getMatrixData() async {
    final db = await database;
    
    // Get ALL ejidatarios, ordered by lote (numeric)
    final ejidatarios = await db.rawQuery(
      'SELECT * FROM ejidatarios ORDER BY CAST(lote AS INTEGER) ASC'
    );
    
    List<Map<String, dynamic>> result = [];
    
    for (var ejidatario in ejidatarios) {
      final int ejidatarioId = ejidatario['id'] as int;
      
      // Get active cycles for this ejidatario
      final cycles = await db.query(
        'ciclos',
        where: 'ejidatario_id = ? AND activo = 1',
        whereArgs: [ejidatarioId],
        orderBy: 'fecha_inicio DESC',
        limit: 3, // Max 3 active cycles
      );
      
      if (cycles.isEmpty) {
        // No cycles yet, show empty row
        result.add({
          'nombre': ejidatario['nombre'],
          'lote': ejidatario['lote'],
          'barrio': ejidatario['barrio'] ?? '',
          'cultivo': '(Sin cultivo)',
          'riegos': <int, String>{}, // Empty map
          'isFirstRow': true, // Always first if single row
        });
      } else {
        // Show each cycle as a row, but only show ejidatario data on first
        bool isFirst = true;
        for (var cycle in cycles) {
          final int cicloId = cycle['id'] as int;
          
          // Get riegos for this cycle
          final riegosRows = await db.query(
            'riegos_matrix',
            where: 'ciclo_id = ?',
            whereArgs: [cicloId],
          );
          
          Map<int, String> riegosMap = {};
          for (var r in riegosRows) {
            riegosMap[r['numero_riego'] as int] = r['fecha'] as String;
          }
          
          result.add({
            'nombre': isFirst ? ejidatario['nombre'] : '',
            'lote': isFirst ? ejidatario['lote'] : '',
            'barrio': isFirst ? (ejidatario['barrio'] ?? '') : '',
            'cultivo': cycle['cultivo'],
            'riegos': riegosMap,
            'isFirstRow': isFirst,
          });
          
          isFirst = false; // Next rows won't be first
        }
      }
    }
    
    print('📊 Matriz generada con ${result.length} filas de ${ejidatarios.length} ejidatarios');
    return result;
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('riegos_matrix');
    await db.delete('ciclos');
    await db.delete('ejidatarios'); // Clear seeded data too
    // Seeding will happen on next app start or manual trigger
  }

  // --- Session Management ---

  Future<int> iniciarDia(String paraje) async {
    final db = await database;
    return await db.insert('dias_sesiones', {
      'fecha_inicio': DateTime.now().toIso8601String(),
      'paraje': paraje,
      'estado': 'activo',
      'total_escaneos': 0,
    });
  }

  Future<void> cerrarDia(int sesionId) async {
    final db = await database;
    await db.update(
      'dias_sesiones',
      {
        'fecha_fin': DateTime.now().toIso8601String(),
        'estado': 'cerrado',
      },
      where: 'id = ?',
      whereArgs: [sesionId],
    );
  }

  Future<Map<String, dynamic>?> getSesionActiva() async {
    final db = await database;
    final result = await db.query(
      'dias_sesiones',
      where: 'estado = ?',
      whereArgs: ['activo'],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getTodasLasSesiones() async {
    final db = await database;
    return await db.query(
      'dias_sesiones',
      orderBy: 'fecha_inicio DESC',
    );
  }

  Future<void> registrarEscaneo({
    required int sesionId,
    required String paraje,
    required String lote,
    required String nombre,
    required String folio,
    required String cultivo,
    required String superficie,
    required String riegoNumero,
  }) async {
    final db = await database;
    
    await db.insert('registros_escaneos', {
      'sesion_id': sesionId,
      'paraje': paraje,
      'lote': lote,
      'nombre': nombre,
      'folio': folio,
      'cultivo': cultivo,
      'superficie': superficie,
      'riego_numero': riegoNumero,
      'fecha_escaneo': DateTime.now().toIso8601String(),
    });

    // Increment total_escaneos counter
    await db.rawUpdate(
      'UPDATE dias_sesiones SET total_escaneos = total_escaneos + 1 WHERE id = ?',
      [sesionId],
    );
  }

  Future<List<Map<String, dynamic>>> getRegistrosPorSesion(int sesionId) async {
    final db = await database;
    return await db.query(
      'registros_escaneos',
      where: 'sesion_id = ?',
      whereArgs: [sesionId],
      orderBy: 'fecha_escaneo ASC',
    );
  }
}

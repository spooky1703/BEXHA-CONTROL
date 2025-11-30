import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for utf8
import 'database_helper.dart';

// List of Parajes extracted from DB
const List<String> parajes = ["0.10", "1 G. ACAY PAR.", "1ER. GIR ACAY", "1er G PTE QUE", "1er. GIR PARAISO", "1er. GIRON", "2 G. ACAY PAR.", "2o. G PTE QUE", "2o. GIRON ACAY", "2o. GIRON P", "ALTO", "ALTO CH", "ALTO CHI", "ALTO GDE", "ALTO H", "ALTO HUITEL", "BARRERA", "BORDO BCO", "BORDO BCO.", "BORDO BDO.", "C. CHAMBAS", "C. NUEVA", "C. NVA", "C.CHAMBAS", "CENTRO", "CHARQUITO", "EL ALTO", "EL ALTO GDE", "EL ARBOLITO", "EL LLANO", "EL MEZQUITE", "EL ZARAGOZA", "HUITEL", "HUITEL PROP", "LA CADENAS", "LA LOMA", "LA LOMA H", "LAS CADENAS", "LAS MINAS", "LLANO", "LOMA", "LOMA H", "MEZQUITE", "PANUAYA", "PARAISO", "PD", "PISILLO", "PROP. HUITEL", "PROPIEDAD HUITEL", "PTE QUEBRADO", "PTE. QUEBRADO", "Test Barrio", "VARIADO", "Z NOPAL", "el arbolito", "nan"];

void main() {
  runApp(const BexhaApp());
}

class BexhaApp extends StatelessWidget {
  const BexhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BEXHA Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF506e78), // Primary
          primary: const Color(0xFF506e78),
          secondary: const Color(0xFFbedcdc), // Secondary
          surface: const Color(0xFFbedcdc), // Surface
          background: const Color(0xFFbedcdc),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFbedcdc), // Light background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF506e78), // Dark header
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusMessage = "Seleccione un paraje para iniciar";
  String? _selectedParaje;
  bool _isDayStarted = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Cooldown prevention
  DateTime? _lastScanTime;
  String? _lastScannedCode;

  // Debug Mode
  bool _isDebugMode = false;

  // Matrix Data
  List<Map<String, dynamic>> _matrixData = [];
  bool _isLoadingMatrix = false;

  // Session Data
  int? _sesionActivaId;
  List<Map<String, dynamic>> _sesiones = [];

  // Search in Matrix
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMatrixData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_filterMatrix);
    _initApp();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _checkLicense(); // 🔒 SECURITY CHECK
    await _requestPermissions();
    await _dbHelper.seedEjidatarios();
    await _loadMatrixData();
    await _loadSesiones();
    await _restoreSesionActiva();
  }

  // 🔒 DEVICE LOCK IMPLEMENTATION
  Future<void> _checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final isLicensed = prefs.getBool('is_licensed') ?? false;

    if (isLicensed) return;

    // Get Device ID
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = "UNKNOWN";
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id; // Unique ID
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? "IOS_NO_ID";
    }

    if (!mounted) return;

    // Show Blocking Dialog
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing
      builder: (ctx) {
        final TextEditingController keyController = TextEditingController();
        String errorMsg = "";

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("🔒 Activación Requerida"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phonelink_lock, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  const Text("Este dispositivo no está autorizado."),
                  const SizedBox(height: 10),
                  SelectableText(
                    "ID: $deviceId",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  const Text("Envía este ID al administrador para obtener tu clave."),
                  const SizedBox(height: 10),
                  const Text(
                    "Para pedir la clave a distancia llame a:\n+52 8137006569\nó ryverz.alonso@gmail.com",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "🚫 Di no a la piratería",
                    style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: keyController,
                    decoration: InputDecoration(
                      labelText: "Clave de Activación",
                      border: const OutlineInputBorder(),
                      errorText: errorMsg.isEmpty ? null : errorMsg,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  final inputKey = keyController.text.trim().toUpperCase();
                  final expectedKey = _generateExpectedKey(deviceId);
                  
                  if (inputKey == expectedKey) {
                    prefs.setBool('is_licensed', true);
                    Navigator.of(ctx).pop(); // Unlock
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Dispositivo Autorizado")),
                    );
                  } else {
                    setState(() {
                      errorMsg = "Clave incorrecta";
                    });
                  }
                },
                child: const Text("ACTIVAR"),
              ),
            ],
          ),
        );
      },
    );
  }

  String _generateExpectedKey(String deviceId) {
    const secretKey = "BEXHA_SECURE_MASTER_KEY_2024"; // MUST MATCH PYTHON SCRIPT
    final keyBytes = utf8.encode(secretKey);
    final dataBytes = utf8.encode(deviceId);
    
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    
    return digest.toString().toUpperCase().substring(0, 8);
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
  }

  Future<void> _loadMatrixData() async {
    setState(() => _isLoadingMatrix = true);
    final data = await _dbHelper.getMatrixData();
    setState(() {
      _matrixData = data;
      _filteredMatrixData = data; // Initialize with all data
      _isLoadingMatrix = false;
    });
  }

  void _filterMatrix() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMatrixData = _matrixData;
      } else {
        _filteredMatrixData = _matrixData.where((row) {
          final nombre = (row['nombre'] ?? '').toString().toLowerCase();
          final lote = (row['lote'] ?? '').toString().toLowerCase();
          final barrio = (row['barrio'] ?? '').toString().toLowerCase();
          return nombre.contains(query) || lote.contains(query) || barrio.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadSesiones() async {
    final sesiones = await _dbHelper.getTodasLasSesiones();
    setState(() {
      _sesiones = sesiones;
    });
  }

  Future<void> _restoreSesionActiva() async {
    final prefs = await SharedPreferences.getInstance();
    final sesionId = prefs.getInt('sesion_activa_id');
    
    if (sesionId != null) {
      // Verify session exists in DB
      final sesion = await _dbHelper.getSesionActiva();
      if (sesion != null && sesion['id'] == sesionId) {
        setState(() {
          _sesionActivaId = sesionId;
          _selectedParaje = sesion['paraje'] as String?;
          _isDayStarted = true;
          _statusMessage = "Sesión restaurada\nParaje: $_selectedParaje\nListo para escanear";
        });
        print('✅ Sesión activa restaurada: ID=$sesionId, Paraje=$_selectedParaje');
      } else {
        // Session no longer active, clear preferences
        await prefs.remove('sesion_activa_id');
      }
    }
  }

  void _startDay() async {
    if (_selectedParaje == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debe seleccionar un paraje')),
      );
      return;
    }
    
    // Create session in database
    final sesionId = await _dbHelper.iniciarDia(_selectedParaje!);
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sesion_activa_id', sesionId);
    
    setState(() {
      _sesionActivaId = sesionId;
      _isDayStarted = true;
      _statusMessage = "Paraje: $_selectedParaje\nListo para escanear";
    });
    
    await _loadSesiones();
    print('📅 Nueva sesión iniciada: ID=$sesionId');
  }

  void _changeParaje() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cambiar Paraje"),
        content: DropdownButtonFormField<String>(
          value: _selectedParaje,
          isExpanded: true,
          items: parajes.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedParaje = newValue;
                _statusMessage = "Paraje: $_selectedParaje\nListo para escanear";
              });
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
  }

  void _endDay() async {
    if (_sesionActivaId == null) return;

    // Load session summary BEFORE showing dialog
    final registros = await _dbHelper.getRegistrosPorSesion(_sesionActivaId!);
    final sesion = _sesiones.firstWhere((s) => s['id'] == _sesionActivaId);
    
    // Calculate summary by cultivo
    Map<String, int> cultivoCount = {};
    for (var r in registros) {
      final cultivo = r['cultivo'] as String;
      cultivoCount[cultivo] = (cultivoCount[cultivo] ?? 0) + 1;
    }

    final totalEscaneos = registros.length;
    final paraje = sesion['paraje'];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("📊 Resumen del Día"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Paraje: $paraje",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                "Total de escaneos: $totalEscaneos",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 16),
              const Text(
                "Desglose por cultivo:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...cultivoCount.entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("• ${entry.key}:"),
                      Text(
                        "${entry.value} escaneos",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "¿Deseas cerrar el día?",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("❌ Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _exportarDiaAExcel(_sesionActivaId!);
            },
            child: const Text("📥 Previsualizar Excel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              // Close session in database
              await _dbHelper.cerrarDia(_sesionActivaId!);
              
              // Clear SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('sesion_activa_id');
              
              print('📅 Sesión cerrada: ID=$_sesionActivaId');
              
              setState(() {
                _isDayStarted = false;
                _selectedParaje = null;
                _sesionActivaId = null;
                _statusMessage = "Seleccione un paraje para iniciar";
              });
              
              await _loadSesiones();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Día cerrado: $totalEscaneos registros guardados'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("✅ Cerrar Día"),
          ),
        ],
      ),
    );
  }

  void _resetDatabase() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ BORRAR TODO"),
        content: const Text("¿Estás seguro de que quieres reiniciar la base de datos? Se perderá todo el historial de riegos."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _dbHelper.resetDatabase();
              await _dbHelper.seedEjidatarios(); // Re-seed immediately
              await _loadMatrixData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Base de datos reiniciada y actualizada')),
              );
            },
            child: const Text("BORRAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareExcel() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final String filePath = '${directory!.path}/bexha_registros.xlsx';
      final File file = File(filePath);

      if (await file.exists()) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(filePath)], 
          text: 'Reporte de Riegos BEXHA',
          sharePositionOrigin: box != null 
            ? box.localToGlobal(Offset.zero) & box.size 
            : null,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No hay archivo de registros para compartir')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al compartir: $e')),
      );
    }
  }

  Future<void> _saveToExcel(String paraje, String lote, String nombre, String folio, String cultivo, String superficie, String riegoInfo, String fecha) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) throw Exception("No se pudo acceder al almacenamiento");

      final String filePath = '${directory.path}/bexha_registros.xlsx';
      final File file = File(filePath);
      
      var excel;
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        excel = Excel.decodeBytes(bytes);
      } else {
        excel = Excel.createExcel();
      }

      final String sheetName = 'Registros';
      Sheet sheetObject = excel[sheetName];

      if (sheetObject.maxRows == 0) {
        sheetObject.appendRow([
            TextCellValue('Paraje'), 
            TextCellValue('Lote'), 
            TextCellValue('Nombre'), 
            TextCellValue('Folio'), 
            TextCellValue('Cultivo'), 
            TextCellValue('Superficie'), 
            TextCellValue('Riego'), 
            TextCellValue('Fecha')
        ]);
      }

      sheetObject.appendRow([
          TextCellValue(paraje), 
          TextCellValue(lote), 
          TextCellValue(nombre), 
          TextCellValue(folio), 
          TextCellValue(cultivo), 
          TextCellValue(superficie), 
          TextCellValue(riegoInfo), 
          TextCellValue(fecha)
      ]);

      final fileBytes = excel.save();
      if (fileBytes != null) {
          await file.create(recursive: true);
          await file.writeAsBytes(fileBytes);
      }
      
    } catch (e) {
      print("Error guardando Excel: $e");
      rethrow;
    }
  }

  void _showSuccessDialog(String nombre, String cultivo, int riego) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("✅ Riego Registrado"),
        content: Text(
          "Nombre: $nombre\nCultivo: $cultivo\n\nSe ha marcado el Riego #$riego en la Matriz.",
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  void _startScanning() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScannerScreen(onScan: _processScanResult),
      ),
    );
  }

  Future<void> _processScanResult(String rawData) async {
    final now = DateTime.now();
    if (_lastScanTime != null && 
        now.difference(_lastScanTime!) < const Duration(seconds: 3) &&
        _lastScannedCode == rawData) {
      return;
    }
    
    _lastScanTime = now;
    _lastScannedCode = rawData;

    try {
      if (_isDebugMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RAW QR: $rawData'), duration: const Duration(seconds: 5)),
        );
      }

      final parts = rawData.split('|');
      if (parts.length < 7) {
        throw FormatException("Formato inválido (Faltan campos).\nRecibido: $rawData");
      }

      final lote = parts[0].trim();
      final nombre = parts[1].trim();
      final folio = parts[2].trim();
      final cultivo = parts[3].trim();
      final superficie = parts[4].trim();
      final String listaRiegosStr = parts[5].trim();
      final qrParaje = parts[6].trim();

      // 1. Validate Paraje
      if (qrParaje.toUpperCase() != _selectedParaje?.trim().toUpperCase()) {
        throw Exception("❌ Paraje incorrecto.\nQR: $qrParaje\nActual: $_selectedParaje");
      }

      // 2. Identify Ejidatario & check for different cultivo
      final ejidatario = await _dbHelper.getEjidatario(nombre, lote);
      if (ejidatario == null) {
        throw Exception("❌ Ejidatario no encontrado.\nBuscando: $nombre (Lote $lote)\n\nIntenta reiniciar la base de datos si es reciente.");
      }
      
      // Check if this is a new cultivo (new siembra)
      final ciclosActivos = await _dbHelper.getActiveCiclos(ejidatario['id']);
      final bool esCultivoNuevo = ciclosActivos.isNotEmpty && 
                                   !ciclosActivos.any((c) => c['cultivo'] == cultivo);
      
      if (esCultivoNuevo && mounted) {
        final String cultivosExistentes = ciclosActivos.map((c) => c['cultivo']).join(', ');
        
        final confirmarNuevaSiembra = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("🌱 Nueva Siembra Detectada"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "El ejidatario $nombre tiene cultivos activos:",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("• Cultivos actuales: $cultivosExistentes"),
                Text("• Nuevo cultivo del QR: $cultivo", 
                     style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  "¿Deseas agregar este nuevo cultivo?\n\nSe creará una nueva fila en la Matriz General.",
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("❌ Cancelar", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF506e78),
                  foregroundColor: Colors.white,
                ),
                child: const Text("✅ Agregar Nueva Siembra"),
              ),
            ],
          ),
        );

        if (confirmarNuevaSiembra != true) {
          // User cancelled new crop - close scanner
          if (mounted) Navigator.pop(context);
          return;
        }
      }
      
      final int cicloId = await _dbHelper.getOrCreateCiclo(ejidatario['id'], cultivo);

      // 3. Determine Next Riego
      List<int> availableRiegos = [];
      try {
        availableRiegos = listaRiegosStr.split(',').map((e) => int.parse(e.trim())).toList();
        availableRiegos.sort();
      } catch (e) {
        throw FormatException("Error leyendo lista de riegos: $listaRiegosStr");
      }

      final db = await _dbHelper.database;
      final usedRows = await db.query('riegos_matrix', where: 'ciclo_id = ?', whereArgs: [cicloId]);
      List<int> usedRiegos = usedRows.map((r) => r['numero_riego'] as int).toList();

      int? nextRiego;
      for (int riego in availableRiegos) {
        if (!usedRiegos.contains(riego)) {
          nextRiego = riego;
          break;
        }
      }

      if (nextRiego == null) {
        throw Exception("❌ Ticket Agotado.\nRiegos comprados: $listaRiegosStr\nTodos han sido usados.");
      }

      // Show confirmation dialog BEFORE registering
      if (mounted) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("⚠️ Confirmar Registro"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "¿Registrar el siguiente riego?",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildConfirmRow("Ejidatario:", nombre),
                _buildConfirmRow("Lote:", lote),
                _buildConfirmRow("Cultivo:", cultivo),
                _buildConfirmRow("Superficie:", superficie),
                _buildConfirmRow("Riego:", "#$nextRiego", color: Colors.green),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("❌ Cancelar", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF506e78),
                  foregroundColor: Colors.white,
                ),
                child: const Text("✅ Confirmar"),
              ),
            ],
          ),
        );

        if (confirmar != true) {
          // User cancelled - close scanner
          if (mounted) Navigator.pop(context);
          return;
        }
      }

      // 4. Register Riego
      await _dbHelper.registerRiego(cicloId, nextRiego, _selectedParaje!);

      // 5. Register in active session
      if (_sesionActivaId != null) {
        await _dbHelper.registrarEscaneo(
          sesionId: _sesionActivaId!,
          paraje: _selectedParaje!,
          lote: lote,
          nombre: nombre,
          folio: folio,
          cultivo: cultivo,
          superficie: superficie,
          riegoNumero: nextRiego.toString(),
        );
      }

      // 6. Log to Excel (legacy support)
      final fechaEscaneo = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await _saveToExcel(
          _selectedParaje!, 
          lote, 
          nombre, 
          folio, 
          cultivo, 
          superficie, 
          nextRiego.toString(), 
          fechaEscaneo
      );

      // 7. Refresh Matrix and session count
      await _loadMatrixData();
      await _loadSesiones();

      if (mounted) {
        // Close scanner AFTER confirmation
        Navigator.pop(context);
        
        _showSuccessDialog(nombre, cultivo, nextRiego);
        setState(() {
          _statusMessage = "Último: $nombre\n✅ Riego $nextRiego ($cultivo)";
        });
      }
    } catch (e) {
      if (mounted) {
        // Close scanner on error too
        Navigator.pop(context);
        _showErrorDialog(e.toString(), rawData);
      }
    }
  }
  
  // ... (Keep existing _saveToExcel, _showSuccessDialog) ...

  void _showErrorDialog(String message, String? rawData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("❌ Error"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 16, color: Colors.red)),
              if (_isDebugMode && rawData != null) ...[
                const Divider(),
                const Text("DEBUG INFO:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(rawData, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            setState(() {
              _isDebugMode = !_isDebugMode;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isDebugMode ? "🔧 MODO DEBUG ACTIVADO" : "Modo Debug Desactivado")),
            );
          },
          child: const Text('BEXHA Scanner'),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // ... (Rest of AppBar) ...
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: "Escanear"),
            Tab(icon: Icon(Icons.grid_on), text: "Matriz General"),
            Tab(icon: Icon(Icons.calendar_today), text: "Días"),
          ],
        ),
        actions: [
          if (_isDayStarted) ...[
             IconButton(
              icon: const Icon(Icons.share),
              tooltip: "Compartir Excel",
              onPressed: _shareExcel,
            ),
            IconButton(
              icon: const Icon(Icons.edit_location_alt),
              tooltip: "Cambiar Paraje",
              onPressed: _changeParaje,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Terminar Día",
              onPressed: _endDay,
            ),
          ],
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Text('Reiniciar Base de Datos'),
              ),
            ],
            onSelected: (value) {
              if (value == 'reset') _resetDatabase();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Scanner UI
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: !_isDayStarted
                  ? _buildStartDayUI()
                  : _buildScanningUI(),
            ),
          ),
          // Tab 2: Matrix View
          _buildMatrixView(),
          // Tab 3: Days/Sessions View
          _buildDiasView(),
        ],
      ),
    );
  }

  Widget _buildStartDayUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, size: 80, color: Colors.blue),
        const SizedBox(height: 20),
        const Text(
          "Seleccione el Paraje para iniciar el día:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedParaje,
          hint: const Text("Seleccionar Paraje"),
          isExpanded: true,
          items: parajes.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedParaje = newValue;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _startDay,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text("INICIAR DÍA", style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }

  Widget _buildScanningUI() {
    // Get current session stats
    int totalEscaneos = 0;
    if (_sesionActivaId != null && _sesiones.isNotEmpty) {
      final sesionActual = _sesiones.firstWhere(
        (s) => s['id'] == _sesionActivaId,
        orElse: () => {},
      );
      totalEscaneos = sesionActual['total_escaneos'] ?? 0;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                const Text("Paraje Activo", style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(
                  _selectedParaje ?? "",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Dashboard Stats
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.check_circle, "Escaneos Hoy", totalEscaneos.toString()),
                _buildStatItem(Icons.qr_code_scanner, "Sesión", "#$_sesionActivaId"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: _startScanning,
          icon: const Icon(Icons.qr_code_scanner, size: 30),
          label: const Text("ESCANEAR TICKET"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            textStyle: const TextStyle(fontSize: 20),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMatrixView() {
    if (_isLoadingMatrix) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Define columns: Lote, Nombre, Paraje, Cultivo, 1..23
    List<DataColumn> columns = [
      const DataColumn2(label: Text('Lote'), size: ColumnSize.S, fixedWidth: 70),
      const DataColumn2(label: Text('Nombre'), size: ColumnSize.L, fixedWidth: 150),
      const DataColumn2(label: Text('Paraje'), size: ColumnSize.S, fixedWidth: 100),
      const DataColumn2(label: Text('Cultivo'), size: ColumnSize.S, fixedWidth: 80),
    ];
    for (int i = 1; i <= 23; i++) {
      columns.add(DataColumn2(label: Text('$i'), size: ColumnSize.S, fixedWidth: 60));
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, lote o paraje...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        // Results count
        if (_searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Mostrando ${_filteredMatrixData.length} de ${_matrixData.length} registros',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        // Data Table
        Expanded(
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 150 + 70 + 100 + 80 + (23 * 60),
            columns: columns,
            rows: _filteredMatrixData.map((row) {
              final bool isFirstRow = row['isFirstRow'] ?? false;
              
              List<DataCell> cells = [
                // Lote
                DataCell(Text(
                  row['lote'] ?? '',
                  style: TextStyle(
                    fontWeight: isFirstRow ? FontWeight.bold : FontWeight.normal,
                  ),
                )),
                // Nombre
                DataCell(Text(
                  row['nombre'] ?? '', 
                  style: TextStyle(
                    fontWeight: isFirstRow ? FontWeight.bold : FontWeight.normal,
                  ),
                )),
                // Paraje
                DataCell(Text(
                  row['barrio'] ?? '',
                  style: TextStyle(fontSize: 12),
                )),
                // Cultivo (with indent for secondary rows)
                DataCell(
                  Row(
                    children: [
                      if (!isFirstRow) const SizedBox(width: 16), // Indent
                      if (!isFirstRow) const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.grey),
                      if (!isFirstRow) const SizedBox(width: 4),
                      Text(
                        row['cultivo'] ?? '',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: isFirstRow ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
              
              Map<int, String> riegos = row['riegos'] ?? {};
              
              for (int i = 1; i <= 23; i++) {
                String cellText = "";
                Color? cellColor;
                
                if (riegos.containsKey(i)) {
                  DateTime date = DateTime.parse(riegos[i]!);
                  cellText = DateFormat('dd/MM').format(date);
                  cellColor = Colors.green.shade100;
                }
                
                cells.add(DataCell(
                  Container(
                    color: cellColor,
                    alignment: Alignment.center,
                    child: Text(cellText, style: const TextStyle(fontSize: 12)),
                  )
                ));
              }
              
              return DataRow(cells: cells);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDiasView() {
    if (_sesiones.isEmpty) {
      return const Center(
        child: Text(
          'No hay sesiones registradas.\n\nInicia un día para crear una sesión.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sesiones.length,
      itemBuilder: (context, index) {
        final sesion = _sesiones[index];
        final bool esActiva = sesion['estado'] == 'activo';
        final DateTime fechaInicio = DateTime.parse(sesion['fecha_inicio']);
        final String fechaInicioStr = DateFormat('dd/MM/yyyy HH:mm').format(fechaInicio);
        
        String fechaFinStr = '-';
        if (sesion['fecha_fin'] != null) {
          final DateTime fechaFin = DateTime.parse(sesion['fecha_fin']);
          fechaFinStr = DateFormat('dd/MM/yyyy HH:mm').format(fechaFin);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: esActiva ? 4 : 1,
          color: esActiva ? Colors.green.shade50 : null,
          child: ListTile(
            leading: Icon(
              esActiva ? Icons.circle : Icons.check_circle_outline,
              color: esActiva ? Colors.green : Colors.grey,
              size: 32,
            ),
            title: Text(
              'Sesión #${sesion['id']} - ${sesion['paraje']}',
              style: TextStyle(
                fontWeight: esActiva ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Inicio: $fechaInicioStr'),
                if (!esActiva) Text('Fin: $fechaFinStr'),
                Text('Total escaneos: ${sesion['total_escaneos'] ?? 0}'),
                if (esActiva)
                  const Text(
                    '✅ SESIÓN ACTIVA',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: !esActiva
                ? IconButton(
                    icon: const Icon(Icons.file_download, color: Colors.blue),
                    tooltip: 'Exportar Excel',
                    onPressed: () => _exportarDiaAExcel(sesion['id']),
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _exportarDiaAExcel(int sesionId) async {
    try {
      final registros = await _dbHelper.getRegistrosPorSesion(sesionId);
      
      if (registros.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Esta sesión no tiene registros para exportar')),
        );
        return;
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sesión $sesionId'];

      sheetObject.appendRow([
        TextCellValue('Paraje'), TextCellValue('Lote'), TextCellValue('Nombre'), 
        TextCellValue('Folio'), TextCellValue('Cultivo'), TextCellValue('Superficie'), 
        TextCellValue('Riego'), TextCellValue('Fecha'),
      ]);

      for (var r in registros) {
        final DateTime fecha = DateTime.parse(r['fecha_escaneo']);
        final String fechaStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha);
        
        sheetObject.appendRow([
          TextCellValue(r['paraje']), TextCellValue(r['lote']), TextCellValue(r['nombre']),
          TextCellValue(r['folio']), TextCellValue(r['cultivo']), TextCellValue(r['superficie']),
          TextCellValue(r['riego_numero']), TextCellValue(fechaStr),
        ]);
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final String fileName = 'sesion_${sesionId}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final String filePath = '${directory!.path}/$fileName';
      final File file = File(filePath);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        await file.create(recursive: true);
        await file.writeAsBytes(fileBytes);
        
        // Share with proper origin for iOS
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(filePath)], 
          text: 'Sesión #$sesionId',
          sharePositionOrigin: box != null 
            ? box.localToGlobal(Offset.zero) & box.size 
            : null,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Excel exportado: $fileName')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al exportar: $e')),
      );
    }
  }
}

class ScannerScreen extends StatelessWidget {
  final Function(String) onScan;

  const ScannerScreen({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escanear")),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              // Don't close scanner here - let _processScanResult handle it
              onScan(barcode.rawValue!);
              break; 
            }
          }
        },
      ),
    );
  }
}

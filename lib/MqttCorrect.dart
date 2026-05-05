import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_mobile_client/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';

// ===========================================================================
// FIX #1 — Renamed from ConnectionState → MqttConnectionStatus to avoid
//           collision with dart:async's ConnectionState used by StreamBuilder /
//           FutureBuilder internally.
// ===========================================================================
enum MqttConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum CertificateType { caSigned, caOnly, selfSigned, mutualTls, none }

// ===========================================================================
// ConnectionProfile
// ===========================================================================
class ConnectionProfile {
  final String id;
  final String name;
  final String brokerUrl;
  final String clientId;
  final String username;
  final String password;
  final bool enableAuth;
  final bool cleanSession;
  final int keepAlive;
  final int defaultQos;
  final bool enableWill;
  final String willTopic;
  final String willPayload;
  final int willQos;
  final bool willRetain;
  final DateTime createdAt;
  final CertificateType certificateType;
  final String? caCertificatePath;
  final String? clientCertificatePath;
  final String? clientPrivateKeyPath;
  final String? clientKeyPassword;
  final bool verifyCertificate;

  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.brokerUrl,
    required this.clientId,
    required this.username,
    required this.password,
    required this.enableAuth,
    required this.cleanSession,
    required this.keepAlive,
    required this.defaultQos,
    required this.enableWill,
    required this.willTopic,
    required this.willPayload,
    required this.willQos,
    required this.willRetain,
    required this.createdAt,
    this.certificateType = CertificateType.none,
    this.caCertificatePath,
    this.clientCertificatePath,
    this.clientPrivateKeyPath,
    this.clientKeyPassword,
    this.verifyCertificate = true,
  });

  // FIX: Added copyWith — eliminates error-prone 18-field manual reconstruction
  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? brokerUrl,
    String? clientId,
    String? username,
    String? password,
    bool? enableAuth,
    bool? cleanSession,
    int? keepAlive,
    int? defaultQos,
    bool? enableWill,
    String? willTopic,
    String? willPayload,
    int? willQos,
    bool? willRetain,
    DateTime? createdAt,
    CertificateType? certificateType,
    String? caCertificatePath,
    String? clientCertificatePath,
    String? clientPrivateKeyPath,
    String? clientKeyPassword,
    bool? verifyCertificate,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      brokerUrl: brokerUrl ?? this.brokerUrl,
      clientId: clientId ?? this.clientId,
      username: username ?? this.username,
      password: password ?? this.password,
      enableAuth: enableAuth ?? this.enableAuth,
      cleanSession: cleanSession ?? this.cleanSession,
      keepAlive: keepAlive ?? this.keepAlive,
      defaultQos: defaultQos ?? this.defaultQos,
      enableWill: enableWill ?? this.enableWill,
      willTopic: willTopic ?? this.willTopic,
      willPayload: willPayload ?? this.willPayload,
      willQos: willQos ?? this.willQos,
      willRetain: willRetain ?? this.willRetain,
      createdAt: createdAt ?? this.createdAt,
      certificateType: certificateType ?? this.certificateType,
      caCertificatePath: caCertificatePath ?? this.caCertificatePath,
      clientCertificatePath:
          clientCertificatePath ?? this.clientCertificatePath,
      clientPrivateKeyPath: clientPrivateKeyPath ?? this.clientPrivateKeyPath,
      clientKeyPassword: clientKeyPassword ?? this.clientKeyPassword,
      verifyCertificate: verifyCertificate ?? this.verifyCertificate,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brokerUrl': brokerUrl,
        'clientId': clientId,
        'username': username,
        'password': password,
        'enableAuth': enableAuth ? 1 : 0,
        'cleanSession': cleanSession ? 1 : 0,
        'keepAlive': keepAlive,
        'defaultQos': defaultQos,
        'enableWill': enableWill ? 1 : 0,
        'willTopic': willTopic,
        'willPayload': willPayload,
        'willQos': willQos,
        'willRetain': willRetain ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'certificateType': certificateType.index,
        'caCertificatePath': caCertificatePath,
        'clientCertificatePath': clientCertificatePath,
        'clientPrivateKeyPath': clientPrivateKeyPath,
        'clientKeyPassword': clientKeyPassword,
        // FIX: default to 1 so older backup files without this field
        // never silently disable cert verification on import.
        'verifyCertificate': verifyCertificate ? 1 : 0,
      };

  factory ConnectionProfile.fromMap(Map<String, dynamic> map) {
    final rawIndex =
        (map['certificateType'] as int?) ?? CertificateType.none.index;
    final certType = CertificateType
        .values[rawIndex.clamp(0, CertificateType.values.length - 1)];
    return ConnectionProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      brokerUrl: map['brokerUrl'] as String,
      clientId: map['clientId'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      enableAuth: (map['enableAuth'] as int?) == 1,
      cleanSession: (map['cleanSession'] as int? ?? 1) == 1,
      keepAlive: (map['keepAlive'] as int?) ?? 60,
      defaultQos: (map['defaultQos'] as int?) ?? 0,
      enableWill: (map['enableWill'] as int?) == 1,
      willTopic: map['willTopic'] as String? ?? 'device/status',
      willPayload: map['willPayload'] as String? ?? 'offline',
      willQos: (map['willQos'] as int?) ?? 0,
      willRetain: (map['willRetain'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as int?) ?? 0),
      certificateType: certType,
      caCertificatePath: map['caCertificatePath'] as String?,
      clientCertificatePath: map['clientCertificatePath'] as String?,
      clientPrivateKeyPath: map['clientPrivateKeyPath'] as String?,
      clientKeyPassword: map['clientKeyPassword'] as String?,
      // FIX: default TRUE when field missing (older backups)
      verifyCertificate: (map['verifyCertificate'] as int? ?? 1) == 1,
    );
  }
}

// ===========================================================================
// MessageTemplate
// ===========================================================================
class MessageTemplate {
  final String id;
  final String name;
  final String topic;
  final String payload;
  final int qos;
  final bool retain;
  final DateTime createdAt;

  const MessageTemplate({
    required this.id,
    required this.name,
    required this.topic,
    required this.payload,
    required this.qos,
    required this.retain,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'topic': topic,
        'payload': payload,
        'qos': qos,
        'retain': retain ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory MessageTemplate.fromMap(Map<String, dynamic> map) =>
      MessageTemplate(
        id: map['id'] as String,
        name: map['name'] as String,
        topic: map['topic'] as String,
        payload: map['payload'] as String,
        qos: (map['qos'] as int?) ?? 0,
        retain: (map['retain'] as int?) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (map['createdAt'] as int?) ?? 0),
      );
}

// ===========================================================================
// ProfileHelper — FIX #4: Completer-based init lock prevents double-open race
// ===========================================================================
class ProfileHelper {
  static Database? _database;
  static Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      final db = await _initDatabase();
      _database = db;
      _initCompleter!.complete(db);
    } catch (e) {
      _initCompleter = null;
      rethrow;
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      path.join(dbPath, 'mqtt_profiles.db'),
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE profiles(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            brokerUrl TEXT NOT NULL,
            clientId TEXT,
            username TEXT,
            password TEXT,
            enableAuth INTEGER,
            cleanSession INTEGER,
            keepAlive INTEGER,
            defaultQos INTEGER,
            enableWill INTEGER,
            willTopic TEXT,
            willPayload TEXT,
            willQos INTEGER,
            willRetain INTEGER,
            createdAt INTEGER,
            certificateType INTEGER DEFAULT 4,
            caCertificatePath TEXT,
            clientCertificatePath TEXT,
            clientPrivateKeyPath TEXT,
            clientKeyPassword TEXT,
            verifyCertificate INTEGER DEFAULT 1
          )
        ''');
      },
      // FIX #4: all ALTER TABLE calls are awaited
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE profiles ADD COLUMN certificateType INTEGER DEFAULT 4');
          await db.execute(
              'ALTER TABLE profiles ADD COLUMN caCertificatePath TEXT');
          await db.execute(
              'ALTER TABLE profiles ADD COLUMN clientCertificatePath TEXT');
          await db.execute(
              'ALTER TABLE profiles ADD COLUMN clientPrivateKeyPath TEXT');
          await db.execute(
              'ALTER TABLE profiles ADD COLUMN clientKeyPassword TEXT');
          await db.execute(
              'ALTER TABLE profiles ADD COLUMN verifyCertificate INTEGER DEFAULT 1');
        }
      },
    );
  }

  Future<void> seedDefaults() async {
    if ((await getAllProfiles()).isNotEmpty) return;
    await insertProfile(ConnectionProfile(
      id: 'default_mosquitto',
      name: 'Mosquitto Test',
      brokerUrl: 'tcp://test.mosquitto.org:1883',
      clientId: '',
      username: '',
      password: '',
      enableAuth: false,
      cleanSession: true,
      keepAlive: 60,
      defaultQos: 0,
      enableWill: false,
      willTopic: 'device/status',
      willPayload: 'offline',
      willQos: 0,
      willRetain: false,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> insertProfile(ConnectionProfile p) async =>
      (await database).insert('profiles', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<ConnectionProfile>> getAllProfiles() async {
    final maps = await (await database).query('profiles');
    return maps.map(ConnectionProfile.fromMap).toList();
  }

  Future<void> updateProfile(ConnectionProfile p) async =>
      (await database).update('profiles', p.toMap(),
          where: 'id = ?', whereArgs: [p.id]);

  Future<void> deleteProfile(String id) async =>
      (await database).delete('profiles', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteAll() async =>
      (await database).delete('profiles');
}

// ===========================================================================
// TemplateHelper — FIX #4: same Completer-based lock
// ===========================================================================
class TemplateHelper {
  static Database? _database;
  static Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      final db = await _initDatabase();
      _database = db;
      _initCompleter!.complete(db);
    } catch (e) {
      _initCompleter = null;
      rethrow;
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      path.join(dbPath, 'mqtt_templates.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE templates(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            topic TEXT NOT NULL,
            payload TEXT NOT NULL,
            qos INTEGER,
            retain INTEGER,
            createdAt INTEGER
          )
        ''');
      },
    );
  }

  Future<void> seedDefaults() async {
    if ((await getAllTemplates()).isNotEmpty) return;
    final defaults = [
      MessageTemplate(
          id: 'tpl_1',
          name: 'Sensor Data',
          topic: 'sensor/temperature',
          payload: '{"temperature":25.5,"humidity":60}',
          qos: 0,
          retain: false,
          createdAt: DateTime.now()),
      MessageTemplate(
          id: 'tpl_2',
          name: 'Device Status',
          topic: 'device/status',
          payload: 'online',
          qos: 1,
          retain: true,
          createdAt: DateTime.now()),
      MessageTemplate(
          id: 'tpl_3',
          name: 'JSON Command',
          topic: 'device/command',
          payload: '{"command":"restart","delay":5}',
          qos: 0,
          retain: false,
          createdAt: DateTime.now()),
    ];
    for (final t in defaults) {
      await insertTemplate(t);
    }
  }

  Future<void> insertTemplate(MessageTemplate t) async =>
      (await database).insert('templates', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<MessageTemplate>> getAllTemplates() async {
    final maps = await (await database).query('templates');
    return maps.map(MessageTemplate.fromMap).toList();
  }

  Future<void> updateTemplate(MessageTemplate t) async =>
      (await database).update('templates', t.toMap(),
          where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTemplate(String id) async =>
      (await database).delete('templates', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteAll() async =>
      (await database).delete('templates');
}

// ===========================================================================
// Data models
// ===========================================================================
class Message {
  final int? id;
  final String topic;
  final String payload;
  final bool isIncoming;
  final DateTime timestamp;
  final int qos;

  const Message({
    this.id,
    required this.topic,
    required this.payload,
    required this.isIncoming,
    required this.timestamp,
    required this.qos,
  });

  MessageHistory toMessageHistory() => MessageHistory(
        topic: topic,
        payload: payload,
        isIncoming: isIncoming,
        qos: qos,
        timestamp: timestamp,
      );

  factory Message.fromHistory(MessageHistory h) => Message(
        id: h.id,
        topic: h.topic,
        payload: h.payload,
        isIncoming: h.isIncoming,
        timestamp: h.timestamp,
        qos: h.qos,
      );
}

class Subscription {
  final String topic;
  final MqttQos qos;
  const Subscription({required this.topic, required this.qos});
}

// ===========================================================================
// MessageItem widget
// ===========================================================================
class MessageItem extends StatelessWidget {
  final Message message;
  const MessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isIn = message.isIncoming;
    final bg = isIn
        ? (dark ? Colors.blue.shade900 : Colors.blue.shade50)
        : (dark ? Colors.green.shade900 : Colors.green.shade50);
    final border = isIn
        ? (dark ? Colors.blue.shade700 : Colors.blue.shade200)
        : (dark ? Colors.green.shade700 : Colors.green.shade200);
    final labelColor = isIn
        ? (dark ? Colors.blue.shade200 : Colors.blue.shade800)
        : (dark ? Colors.green.shade200 : Colors.green.shade800);
    final ts = message.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              size: 14,
              color: labelColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message.topic,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'QoS ${message.qos}  $timeStr',
              style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ]),
          const SizedBox(height: 6),
          SelectableText(
            message.payload,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: dark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// App entry point
// ===========================================================================
void main() => runApp(const MqttApp());

class MqttApp extends StatelessWidget {
  const MqttApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MqttCorrect(),
      );
}

// ===========================================================================
// Main widget
// ===========================================================================
class MqttCorrect extends StatefulWidget {
  const MqttCorrect({super.key});
  @override
  State<MqttCorrect> createState() => _MqttCorrectState();
}

class _MqttCorrectState extends State<MqttCorrect> {
  // ── TextControllers ────────────────────────────────────────────────────────
  final _urlCtrl =
      TextEditingController(text: 'tcp://test.mosquitto.org:1883');
  final _clientIdCtrl = TextEditingController();
  final _subTopicCtrl = TextEditingController(text: 'test/topic');
  final _pubTopicCtrl = TextEditingController(text: 'test/topic');
  final _payloadCtrl =
      TextEditingController(text: '{"message":"flutter_mqtt"}');
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _keepAliveCtrl = TextEditingController(text: '60');
  final _willTopicCtrl = TextEditingController(text: 'device/status');
  final _willPayloadCtrl = TextEditingController(text: 'offline');
  final _searchCtrl = TextEditingController();
  final _keyPasswordCtrl = TextEditingController();
  final _scrollController = ScrollController();

  // ── Helpers ────────────────────────────────────────────────────────────────
  final _dbHelper = DatabaseHelper();
  final _profileHelper = ProfileHelper();
  final _templateHelper = TemplateHelper();

  // ── MQTT ───────────────────────────────────────────────────────────────────
  MqttServerClient? _client;
  StreamSubscription? _updatesSub;

  // FIX #1 — renamed enum; no more collision with dart:async ConnectionState
  MqttConnectionStatus _connectionStatus = MqttConnectionStatus.disconnected;

  // ── Message lists — FIX #6: separate live vs history lists ────────────────
  final List<Message> _liveMessages = [];
  List<Message> _historyMessages = [];
  bool _showHistory = false;
  List<Message> get _messages =>
      _showHistory ? _historyMessages : _liveMessages;

  // ── Subscriptions / Profiles / Templates ──────────────────────────────────
  final List<Subscription> _subscriptions = [];
  List<ConnectionProfile> _profiles = [];
  ConnectionProfile? _currentProfile;
  bool _showProfiles = true;
  List<MessageTemplate> _templates = [];
  MessageTemplate? _currentTemplate;
  bool _showTemplates = false;

  // ── Authentication ─────────────────────────────────────────────────────────
  bool _enableAuth = false;
  bool _hidePassword = true;

  // ── TLS ────────────────────────────────────────────────────────────────────
  bool _enableTLS = false;
  CertificateType _certificateType = CertificateType.none;
  String? _caCertPath;
  String? _clientCertPath;
  String? _clientKeyPath;
  String? _clientKeyPassword;
  bool _verifyCertificate = true;
  bool _disableCertVerification = false;
  String _certInfo = '';
  bool _showCertInfo = false;

  // ── Connection settings ────────────────────────────────────────────────────
  bool _cleanSession = true;
  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  bool _shouldRestoreSubs = false;

  // ── Health check — FIX #2: only health check; keep-alive done by library ──
  Timer? _healthTimer;
  int _missedPings = 0;
  static const int _maxMissedPings = 3;

  // ── Uptime ─────────────────────────────────────────────────────────────────
  DateTime? _connectedAt;
  Timer? _uptimeTimer;
  Duration _uptime = Duration.zero;

  // ── Will ───────────────────────────────────────────────────────────────────
  bool _enableWill = false;
  MqttQos _willQos = MqttQos.atMostOnce;
  bool _willRetain = false;

  // ── Publish ────────────────────────────────────────────────────────────────
  MqttQos _qos = MqttQos.atMostOnce;
  bool _retain = false;

  // ── Search ─────────────────────────────────────────────────────────────────
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ── UI ─────────────────────────────────────────────────────────────────────
  bool _isDark = false;

  // ── Batched rebuild — FIX #5 ──────────────────────────────────────────────
  bool _pendingRebuild = false;

  static const int _maxMessages = 1000;

  // ──────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _clientIdCtrl.text =
        'flutter_${DateTime.now().millisecondsSinceEpoch}_${_rndStr(4)}';
    _loadSavedMessages();
    _initProfiles();
    _initTemplates();
  }

  // FIX #7 — ALL timers, subscriptions, and controllers disposed
  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _healthTimer?.cancel();
    _uptimeTimer?.cancel();
    _searchDebounce?.cancel();
    _updatesSub?.cancel();
    if (_connectionStatus == MqttConnectionStatus.connected) {
      _client?.disconnect();
    }
    for (final c in [
      _urlCtrl, _clientIdCtrl, _subTopicCtrl, _pubTopicCtrl,
      _payloadCtrl, _usernameCtrl, _passwordCtrl, _keepAliveCtrl,
      _willTopicCtrl, _willPayloadCtrl, _searchCtrl, _keyPasswordCtrl,
    ]) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ──────────────────────────────────────────────────────────────────────────
  String _rndStr(int n) {
    const c = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return String.fromCharCodes(
        Iterable.generate(n, (_) => c.codeUnitAt(r.nextInt(c.length))));
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MESSAGE LOGGING — FIX #5: batched setState via post-frame callback.
  //   At any rate of incoming messages, the UI rebuilds at most once per frame.
  // ──────────────────────────────────────────────────────────────────────────
  void _log(String topic, String message,
      {bool isIncoming = true, int qos = 0}) async {
    final msg = Message(
      topic: topic,
      payload: message,
      isIncoming: isIncoming,
      timestamp: DateTime.now(),
      qos: qos,
    );

    _liveMessages.insert(0, msg);
    if (_liveMessages.length > _maxMessages) {
      _liveMessages.removeRange(_maxMessages, _liveMessages.length);
    }

    if (!_pendingRebuild) {
      _pendingRebuild = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _pendingRebuild = false);
          if (_scrollController.hasClients && !_showHistory) {
            _scrollController.animateTo(0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        }
      });
    }

    try {
      await _dbHelper.insertMessage(msg.toMessageHistory());
    } catch (e) {
      debugPrint('DB insert error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HISTORY — FIX #6: history toggle never truncates live messages
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _loadSavedMessages() async {
    try {
      final saved = await _dbHelper.getAllMessages();
      if (mounted) {
        setState(() {
          _liveMessages
            ..clear()
            ..addAll(saved.map(Message.fromHistory));
        });
      }
    } catch (e) {
      _log('Database', 'Error loading messages: $e', isIncoming: false);
    }
  }

  void _toggleHistory() async {
    if (_showHistory) {
      // Just switch list — live messages are untouched
      setState(() => _showHistory = false);
    } else {
      try {
        final all = await _dbHelper.getAllMessages();
        if (mounted) {
          setState(() {
            _historyMessages = all.map(Message.fromHistory).toList();
            _showHistory = true;
          });
        }
      } catch (e) {
        _log('System', 'Error loading full history: $e', isIncoming: false);
      }
    }
  }

  void _clearMessages() async {
    try {
      await _dbHelper.clearAllMessages();
      setState(() {
        _liveMessages.clear();
        _historyMessages.clear();
      });
    } catch (e) {
      _log('System', 'Clear error: $e', isIncoming: false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SEARCH
  // ──────────────────────────────────────────────────────────────────────────
  List<Message> get _filtered {
    if (_searchQuery.isEmpty) return _messages;
    final q = _searchQuery.toLowerCase();
    return _messages
        .where((m) =>
            m.topic.toLowerCase().contains(q) ||
            m.payload.toLowerCase().contains(q))
        .toList();
  }

  void _onSearch(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = v);
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WILDCARD VALIDATION — FIX #8: fixed logic; '+' must occupy its entire level
  // ──────────────────────────────────────────────────────────────────────────
  bool _validTopic(String topic) {
    if (topic.isEmpty) return false;
    final parts = topic.split('/');
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.contains('#')) {
        // '#' must be alone and the last segment
        if (i != parts.length - 1 || part != '#') return false;
      }
      if (part.contains('+') && part != '+') return false;
    }
    return true;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UPTIME
  // ──────────────────────────────────────────────────────────────────────────
  void _startUptime() {
    _connectedAt = DateTime.now();
    _uptimeTimer?.cancel();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null && mounted) {
        setState(() => _uptime = DateTime.now().difference(_connectedAt!));
      }
    });
  }

  void _stopUptime() {
    _uptimeTimer?.cancel();
    _connectedAt = null;
    _uptime = Duration.zero;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HEALTH CHECK — FIX #2: No custom publish to $SYS. We only increment
  //   _missedPings on each interval; _onPong() resets when PINGRES arrives.
  // ──────────────────────────────────────────────────────────────────────────
  void _startHealth() {
    _healthTimer?.cancel();
    final interval = int.tryParse(_keepAliveCtrl.text) ?? 60;
    _healthTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (_connectionStatus == MqttConnectionStatus.connected) {
        _missedPings++;
        if (_missedPings >= _maxMissedPings) {
          _log('Health', 'No PING response for $_missedPings intervals — reconnecting',
              isIncoming: false);
          _client?.disconnect();
          _onDisconnectedWithReconnect();
        }
      }
    });
  }

  void _stopHealth() => _healthTimer?.cancel();

  // ──────────────────────────────────────────────────────────────────────────
  // AUTO-RECONNECT
  // ──────────────────────────────────────────────────────────────────────────
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    if (!_autoReconnect) return;
    _cancelReconnect();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('Connection',
          'Max reconnect attempts reached ($_maxReconnectAttempts). Tap Reconnect to retry.',
          isIncoming: false);
      if (mounted) {
        setState(() => _connectionStatus = MqttConnectionStatus.error);
      }
      return;
    }
    _reconnectAttempts++;
    if (mounted) {
      setState(() => _connectionStatus = MqttConnectionStatus.reconnecting);
    }
    final delay = Duration(seconds: _reconnectAttempts * 2);
    _log('Connection',
        'Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s',
        isIncoming: false);
    _reconnectTimer = Timer(delay, _connect);
  }

  void _forceReconnect() {
    _cancelReconnect();
    _reconnectAttempts = 0;
    if (_connectionStatus == MqttConnectionStatus.connected) {
      _client?.disconnect();
    } else {
      _connect();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MQTT CALLBACKS
  // ──────────────────────────────────────────────────────────────────────────
  void _onConnected() {
    _log('Connection', 'Connected!', isIncoming: false);
    if (mounted) {
      setState(() {
        _connectionStatus = MqttConnectionStatus.connected;
        _reconnectAttempts = 0;
        _missedPings = 0;
      });
    }
    _startUptime();
    _startHealth();

    // Re-subscribe to Will topic if not already subscribed
    if (_enableWill && _willTopicCtrl.text.trim().isNotEmpty) {
      final wt = _willTopicCtrl.text.trim();
      if (!_subscriptions.any((s) => s.topic == wt)) {
        try {
          _client!.subscribe(wt, MqttQos.atLeastOnce);
          setState(() => _subscriptions
              .add(Subscription(topic: wt, qos: MqttQos.atLeastOnce)));
          _log('Will', 'Subscribed to Will topic: $wt', isIncoming: false);
        } catch (_) {}
      }
    }

    if (_shouldRestoreSubs) {
      _shouldRestoreSubs = false;
      Future.delayed(const Duration(milliseconds: 800), _resubscribeAll);
    }
  }

  void _onDisconnected() {
    if (mounted) {
      setState(() => _connectionStatus = MqttConnectionStatus.disconnected);
    }
    _stopUptime();
    _stopHealth();
    _log('Connection', 'Disconnected', isIncoming: false);
  }

  void _onDisconnectedWithReconnect() {
    _log('Connection', 'Connection lost', isIncoming: false);
    if (mounted) {
      setState(() => _connectionStatus = MqttConnectionStatus.disconnected);
    }
    _cancelReconnect();
    _stopHealth();
    _stopUptime();
    _shouldRestoreSubs = true;
    _scheduleReconnect();
  }

  void _onSubscribed(String topic) =>
      _log('Subscription', 'Subscribed: $topic', isIncoming: false);

  // FIX #2 — resets missed pings when PINGRES arrives
  void _onPong() {
    _missedPings = 0;
  }

  void _setupMessageListener() {
    _updatesSub?.cancel();
    _updatesSub = _client?.updates
        ?.listen((List<MqttReceivedMessage<MqttMessage?>>? events) {
      if (events == null) return;
      for (final event in events) {
        try {
          final msg = event.payload;
          if (msg is MqttPublishMessage) {
            final payload =
                MqttPublishPayload.bytesToStringAsString(msg.payload.message);
            final qos = msg.payload.header?.qos.index ?? 0;
            _log(event.topic, payload, isIncoming: true, qos: qos);
          }
        } catch (e) {
          _log('Error', 'Message parse error: $e', isIncoming: false);
        }
      }
    }, onError: (e) {
      _log('Error', 'Stream error: $e', isIncoming: false);
    });
  }

  void _resubscribeAll() {
    if (_client == null ||
        _connectionStatus != MqttConnectionStatus.connected ||
        _subscriptions.isEmpty) return;
    _log('System',
        'Restoring ${_subscriptions.length} subscription(s)',
        isIncoming: false);
    for (final sub in _subscriptions) {
      try {
        _client!.subscribe(sub.topic, sub.qos);
      } catch (e) {
        _log('Subscription', 'Re-subscribe failed (${sub.topic}): $e',
            isIncoming: false);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SECURITY CONTEXT — FIX #1 in switch: removed the duplicate caSigned case
  // ──────────────────────────────────────────────────────────────────────────
  Future<SecurityContext> _buildSecCtx() async {
    final ctx = SecurityContext.defaultContext;
    switch (_certificateType) {
      case CertificateType.caSigned:
      case CertificateType.caOnly:
        if (_caCertPath != null) {
          try {
            ctx.setTrustedCertificatesBytes(
                await File(_caCertPath!).readAsBytes());
            _log('Security', 'CA cert loaded', isIncoming: false);
          } catch (e) {
            _log('Security', 'CA cert load error: $e', isIncoming: false);
          }
        }
        break;
      case CertificateType.mutualTls:
        if (_caCertPath != null) {
          try {
            ctx.setTrustedCertificatesBytes(
                await File(_caCertPath!).readAsBytes());
          } catch (_) {}
        }
        if (_clientCertPath != null && _clientKeyPath != null) {
          try {
            ctx.useCertificateChainBytes(
                await File(_clientCertPath!).readAsBytes());
            ctx.usePrivateKeyBytes(await File(_clientKeyPath!).readAsBytes(),
                password: _clientKeyPassword);
            _log('Security', 'Mutual TLS configured', isIncoming: false);
          } catch (e) {
            _log('Security', 'mTLS setup error: $e', isIncoming: false);
          }
        } else {
          _log('Security', 'Client cert or key missing for mTLS',
              isIncoming: false);
        }
        break;
      case CertificateType.selfSigned:
        _log('Security', 'Self-signed certs accepted', isIncoming: false);
        break;
      case CertificateType.none:
        break;
    }
    return ctx;
  }

  String _certTypeName() {
    switch (_certificateType) {
      case CertificateType.caSigned:
        return 'CA Signed';
      case CertificateType.caOnly:
        return 'CA Only';
      case CertificateType.selfSigned:
        return 'Self-Signed';
      case CertificateType.mutualTls:
        return 'Mutual TLS';
      case CertificateType.none:
        return 'Standard SSL/TLS';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONNECT / DISCONNECT
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _connect() async {
    if (_connectionStatus == MqttConnectionStatus.connected ||
        _connectionStatus == MqttConnectionStatus.connecting) return;

    _cancelReconnect();
    if (mounted) setState(() => _connectionStatus = MqttConnectionStatus.connecting);

    final raw = _urlCtrl.text.trim();
    _log('Connection', 'Connecting to: $raw', isIncoming: false);

    try {
      final uri = Uri.parse(raw);
      final host = uri.host;
      if (host.isEmpty) throw const FormatException('No host in URL');

      final scheme = uri.scheme.toLowerCase();
      final useWS = scheme == 'ws' || scheme == 'wss';
      final useSSL =
          scheme == 'ssl' || scheme == 'wss' || _enableTLS;

      int port = uri.port;
      if (port == 0) {
        port = useWS ? (useSSL ? 443 : 80) : (useSSL ? 8883 : 1883);
      }

      // Validate Will before connecting
      if (_enableWill) {
        final wt = _willTopicCtrl.text.trim();
        if (wt.isEmpty) {
          _log('Connection', 'Will topic is empty — aborting',
              isIncoming: false);
          setState(
              () => _connectionStatus = MqttConnectionStatus.disconnected);
          return;
        }
        if (wt.contains('#') || wt.contains('+')) {
          _log('Connection', 'Will topic cannot contain wildcards',
              isIncoming: false);
          setState(
              () => _connectionStatus = MqttConnectionStatus.disconnected);
          return;
        }
      }

      String clientId = _clientIdCtrl.text.trim();
      if (clientId.isEmpty) {
        clientId =
            'flutter_${DateTime.now().millisecondsSinceEpoch}_${_rndStr(6)}';
        _clientIdCtrl.text = clientId;
      }

      final client = MqttServerClient.withPort(host, clientId, port);
      client.logging(on: false);

      if (useSSL) {
        client.secure = true;
        client.securityContext = await _buildSecCtx();
        client.onBadCertificate = (dynamic cert) {
          if (_certificateType == CertificateType.selfSigned) return true;
          if (_disableCertVerification || !_verifyCertificate) return true;
          _log('Security', 'Certificate rejected', isIncoming: false);
          return false;
        };
      }

      if (useWS) {
        client.useWebSocket = true;
        client.websocketProtocols = ['mqtt', 'mqttv3.1', 'mqttv3.1.1'];
      }

      client.keepAlivePeriod = int.tryParse(_keepAliveCtrl.text) ?? 60;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnectedWithReconnect;
      client.onSubscribed = _onSubscribed;
      client.pongCallback = _onPong;

      var conn = MqttConnectMessage().withClientIdentifier(clientId);

      if (_enableWill && _willTopicCtrl.text.trim().isNotEmpty) {
        conn = conn
            .withWillTopic(_willTopicCtrl.text.trim())
            .withWillMessage(_willPayloadCtrl.text.trim())
            .withWillQos(_willQos);
        if (_willRetain) conn = conn.withWillRetain();
      }

      if (_cleanSession) conn = conn.startClean();

      if (_enableAuth && _usernameCtrl.text.trim().isNotEmpty) {
        conn = conn.authenticateAs(
            _usernameCtrl.text.trim(), _passwordCtrl.text.trim());
      }

      client.connectionMessage = conn;

      final result = await client.connect();

      if (result?.state == MqttConnectionState.connected) {
        _client = client;
        _setupMessageListener();
      } else {
        _log('Connection', 'Connection rejected: ${result?.state}',
            isIncoming: false);
        client.disconnect();
        if (mounted) {
          setState(
              () => _connectionStatus = MqttConnectionStatus.disconnected);
        }
        _scheduleReconnect();
      }
    } on SocketException catch (e) {
      _log('Connection', 'Network error: ${e.message}', isIncoming: false);
      if (mounted) {
        setState(() => _connectionStatus = MqttConnectionStatus.disconnected);
      }
      _scheduleReconnect();
    } on HandshakeException catch (e) {
      _log('Connection', 'TLS handshake failed: ${e.message}',
          isIncoming: false);
      if (mounted) {
        setState(() => _connectionStatus = MqttConnectionStatus.disconnected);
      }
      _scheduleReconnect();
    } on TimeoutException {
      _log('Connection', 'Connection timed out', isIncoming: false);
      if (mounted) {
        setState(() => _connectionStatus = MqttConnectionStatus.disconnected);
      }
      _scheduleReconnect();
    } on FormatException catch (e) {
      _log('Connection', 'Invalid URL: $e', isIncoming: false);
      if (mounted) {
        setState(() => _connectionStatus = MqttConnectionStatus.error);
      }
    } catch (e) {
      _log('Connection', 'Unexpected error: $e', isIncoming: false);
      if (mounted) {
        setState(() => _connectionStatus = MqttConnectionStatus.disconnected);
      }
      _scheduleReconnect();
    }
  }

  void _disconnect() {
    _cancelReconnect();
    _stopHealth();
    _stopUptime();
    _client?.disconnect();
    if (mounted) {
      setState(() => _connectionStatus = MqttConnectionStatus.disconnected);
    }
    _log('Connection', 'Disconnected by user', isIncoming: false);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SUBSCRIBE / UNSUBSCRIBE / PUBLISH
  // ──────────────────────────────────────────────────────────────────────────
  void _subscribe() {
    if (_connectionStatus != MqttConnectionStatus.connected ||
        _client == null) {
      _log('Subscription', 'Not connected', isIncoming: false);
      return;
    }
    final topic = _subTopicCtrl.text.trim();
    if (topic.isEmpty) return;
    if (!_validTopic(topic)) {
      _log('Subscription',
          'Invalid topic. Use + for single-level and # (last only) for multi-level',
          isIncoming: false);
      return;
    }
    if (_subscriptions.any((s) => s.topic == topic)) {
      _log('Subscription', 'Already subscribed to: $topic',
          isIncoming: false);
      return;
    }
    try {
      _client!.subscribe(topic, _qos);
      setState(
          () => _subscriptions.add(Subscription(topic: topic, qos: _qos)));
      _subTopicCtrl.clear();
    } catch (e) {
      _log('Subscription', 'Error: $e', isIncoming: false);
    }
  }

  void _unsubscribe(String topic) {
    if (_connectionStatus != MqttConnectionStatus.connected ||
        _client == null) return;
    try {
      _client!.unsubscribe(topic);
      setState(
          () => _subscriptions.removeWhere((s) => s.topic == topic));
      _log('Subscription', 'Unsubscribed: $topic', isIncoming: false);
    } catch (e) {
      _log('Subscription', 'Unsubscribe error: $e', isIncoming: false);
    }
  }

  void _publish() {
    if (_connectionStatus != MqttConnectionStatus.connected ||
        _client == null) {
      _log('Publish', 'Not connected', isIncoming: false);
      return;
    }
    final topic = _pubTopicCtrl.text.trim();
    final payload = _payloadCtrl.text.trim();
    if (topic.isEmpty || payload.isEmpty) return;
    try {
      final builder = MqttClientPayloadBuilder()..addString(payload);
      _client!.publishMessage(topic, _qos, builder.payload!,
          retain: _retain);
      _log(topic,
          'TX: $payload${_retain ? " [RETAINED]" : ""}',
          isIncoming: false,
          qos: _qos.index);
    } catch (e) {
      _log('Publish', 'Error: $e', isIncoming: false);
    }
  }

  void _clearRetained() {
    if (_connectionStatus != MqttConnectionStatus.connected ||
        _client == null) return;
    final topic = _pubTopicCtrl.text.trim();
    if (topic.isEmpty) {
      _log('System', 'Enter a topic first', isIncoming: false);
      return;
    }
    try {
      final builder = MqttClientPayloadBuilder()..addString('');
      _client!
          .publishMessage(topic, MqttQos.atLeastOnce, builder.payload!,
              retain: true);
      _log('System', 'Cleared retained message for: $topic',
          isIncoming: false);
    } catch (e) {
      _log('System', 'Clear retained error: $e', isIncoming: false);
    }
  }

  void _clearWillRetained() {
    if (_connectionStatus != MqttConnectionStatus.connected ||
        _client == null) return;
    final topic = _willTopicCtrl.text.trim();
    if (topic.isEmpty) {
      _log('System', 'Enter a Will topic first', isIncoming: false);
      return;
    }
    try {
      final builder = MqttClientPayloadBuilder()..addString('');
      _client!
          .publishMessage(topic, MqttQos.atLeastOnce, builder.payload!,
              retain: true);
      _log('System', 'Cleared retained Will message for: $topic',
          isIncoming: false);
    } catch (e) {
      _log('System', 'Error: $e', isIncoming: false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CERTIFICATE PICKERS
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _pickCaCert() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'crt', 'cer', 'der']);
    if (r != null && r.files.single.path != null) {
      setState(() => _caCertPath = r.files.single.path!);
      _loadCertInfo(_caCertPath!);
    }
  }

  Future<void> _pickClientCert() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'crt', 'cer', 'der']);
    if (r != null && r.files.single.path != null) {
      setState(() => _clientCertPath = r.files.single.path!);
    }
  }

  Future<void> _pickPrivateKey() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['key', 'pem', 'der']);
    if (r != null && r.files.single.path != null) {
      setState(() => _clientKeyPath = r.files.single.path!);
    }
  }

  Future<void> _loadCertInfo(String certPath) async {
    try {
      final file = File(certPath);
      final bytes = await file.length();
      final content = await file.readAsString();
      String info =
          'File: ${path.basename(certPath)}\nSize: $bytes bytes\n';
      if (content.contains('-----BEGIN CERTIFICATE-----')) {
        info += 'Type: X.509 Certificate (PEM)';
        final base64Lines = content
            .split('\n')
            .where((l) =>
                l.isNotEmpty &&
                !l.contains('---') &&
                RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(l.trim()))
            .length;
        info +=
            base64Lines > 1 ? '\nValid PEM structure' : '\nWarning: possibly empty/invalid';
      } else if (content.contains('-----BEGIN PRIVATE KEY-----') ||
          content.contains('-----BEGIN RSA PRIVATE KEY-----')) {
        info += 'Type: Private Key — keep secure!';
      } else {
        info += 'Type: Unknown format';
      }
      if (mounted) {
        setState(() {
          _certInfo = info;
          _showCertInfo = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _certInfo = 'Error reading cert: $e';
          _showCertInfo = true;
        });
      }
    }
  }

  void _clearCerts() {
    setState(() {
      _caCertPath = null;
      _clientCertPath = null;
      _clientKeyPath = null;
      _clientKeyPassword = null;
      _keyPasswordCtrl.clear();
      _certInfo = '';
      _showCertInfo = false;
    });
  }

  Future<void> _testCertConnection() async {
    _log('Security', 'Testing TLS connection...', isIncoming: false);
    try {
      final uri = Uri.parse(_urlCtrl.text.trim());
      if (uri.host.isEmpty) throw const FormatException('No host');
      final ctx = await _buildSecCtx();
      final port = uri.port == 0 ? 8883 : uri.port;
      final socket = await SecureSocket.connect(uri.host, port,
          context: ctx,
          onBadCertificate: (_) =>
              _certificateType == CertificateType.selfSigned ||
              _disableCertVerification ||
              !_verifyCertificate);
      _log('Security', 'TLS test successful!', isIncoming: false);
      await socket.close();
    } catch (e) {
      _log('Security', 'TLS test failed: $e', isIncoming: false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PROFILE MANAGEMENT
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _initProfiles() async {
    try {
      await _profileHelper.seedDefaults();
      final p = await _profileHelper.getAllProfiles();
      if (mounted) setState(() => _profiles = p);
    } catch (e) {
      _log('Profiles', 'Load error: $e', isIncoming: false);
    }
  }

  void _loadProfile(ConnectionProfile p) {
    setState(() {
      _currentProfile = p;
      _urlCtrl.text = p.brokerUrl;
      _clientIdCtrl.text = p.clientId.isEmpty
          ? 'flutter_${DateTime.now().millisecondsSinceEpoch}_${_rndStr(4)}'
          : p.clientId;
      _usernameCtrl.text = p.username;
      _passwordCtrl.text = p.password;
      _enableAuth = p.enableAuth;
      _cleanSession = p.cleanSession;
      _keepAliveCtrl.text = p.keepAlive.toString();
      _qos = MqttQos.values[p.defaultQos.clamp(0, 2)];
      _enableWill = p.enableWill;
      _willTopicCtrl.text = p.willTopic;
      _willPayloadCtrl.text = p.willPayload;
      _willQos = MqttQos.values[p.willQos.clamp(0, 2)];
      _willRetain = p.willRetain;
      _certificateType = p.certificateType;
      _caCertPath = p.caCertificatePath;
      _clientCertPath = p.clientCertificatePath;
      _clientKeyPath = p.clientPrivateKeyPath;
      _clientKeyPassword = p.clientKeyPassword;
      _verifyCertificate = p.verifyCertificate;
      _enableTLS = p.brokerUrl.startsWith('ssl://') ||
          p.brokerUrl.startsWith('wss://') ||
          p.certificateType != CertificateType.none;
      if (_clientKeyPassword != null) {
        _keyPasswordCtrl.text = _clientKeyPassword!;
      }
    });
    _log('Profiles', 'Loaded: ${p.name}', isIncoming: false);
  }

  Future<void> _saveAsProfile() async {
    String url = _urlCtrl.text.trim();
    if (_enableTLS) {
      if (url.startsWith('tcp://')) url = url.replaceFirst('tcp://', 'ssl://');
      if (url.startsWith('ws://')) url = url.replaceFirst('ws://', 'wss://');
    }
    final p = ConnectionProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _inferProfileName(url),
      brokerUrl: url,
      clientId: _clientIdCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      enableAuth: _enableAuth,
      cleanSession: _cleanSession,
      keepAlive: int.tryParse(_keepAliveCtrl.text) ?? 60,
      defaultQos: _qos.index,
      enableWill: _enableWill,
      willTopic: _willTopicCtrl.text.trim(),
      willPayload: _willPayloadCtrl.text.trim(),
      willQos: _willQos.index,
      willRetain: _willRetain,
      createdAt: DateTime.now(),
      certificateType: _certificateType,
      caCertificatePath: _caCertPath,
      clientCertificatePath: _clientCertPath,
      clientPrivateKeyPath: _clientKeyPath,
      clientKeyPassword: _keyPasswordCtrl.text.trim().isNotEmpty
          ? _keyPasswordCtrl.text.trim()
          : null,
      verifyCertificate: _verifyCertificate,
    );
    try {
      await _profileHelper.insertProfile(p);
      final profiles = await _profileHelper.getAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _currentProfile = p;
        });
      }
      _log('Profiles', 'Saved: ${p.name}', isIncoming: false);
    } catch (e) {
      _log('Profiles', 'Save error: $e', isIncoming: false);
    }
  }

  String _inferProfileName(String url) {
    if (url.contains('mosquitto')) return 'Mosquitto ${_profiles.length + 1}';
    if (url.contains('emqx')) return 'EMQX ${_profiles.length + 1}';
    if (url.contains('hivemq')) return 'HiveMQ ${_profiles.length + 1}';
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      return 'Local ${_profiles.length + 1}';
    }
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isNotEmpty ? '$host ${_profiles.length + 1}' : 'Profile ${_profiles.length + 1}';
  }

  Future<void> _updateCurrentProfile() async {
    if (_currentProfile == null) return;
    try {
      final updated = _currentProfile!.copyWith(
        brokerUrl: _urlCtrl.text.trim(),
        clientId: _clientIdCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        enableAuth: _enableAuth,
        cleanSession: _cleanSession,
        keepAlive: int.tryParse(_keepAliveCtrl.text) ?? 60,
        defaultQos: _qos.index,
        enableWill: _enableWill,
        willTopic: _willTopicCtrl.text.trim(),
        willPayload: _willPayloadCtrl.text.trim(),
        willQos: _willQos.index,
        willRetain: _willRetain,
        certificateType: _certificateType,
        caCertificatePath: _caCertPath,
        clientCertificatePath: _clientCertPath,
        clientPrivateKeyPath: _clientKeyPath,
        clientKeyPassword: _keyPasswordCtrl.text.trim().isNotEmpty
            ? _keyPasswordCtrl.text.trim()
            : null,
        verifyCertificate: _verifyCertificate,
      );
      await _profileHelper.updateProfile(updated);
      final profiles = await _profileHelper.getAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _currentProfile = updated;
        });
      }
      _log('Profiles', 'Updated: ${updated.name}', isIncoming: false);
    } catch (e) {
      _log('Profiles', 'Update error: $e', isIncoming: false);
    }
  }

  Future<void> _deleteProfile(ConnectionProfile p) async {
    try {
      await _profileHelper.deleteProfile(p.id);
      final profiles = await _profileHelper.getAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          if (_currentProfile?.id == p.id) _currentProfile = null;
        });
      }
    } catch (e) {
      _log('Profiles', 'Delete error: $e', isIncoming: false);
    }
  }

  Future<void> _renameProfile(ConnectionProfile p, String newName) async {
    try {
      final updated = p.copyWith(name: newName);
      await _profileHelper.updateProfile(updated);
      final profiles = await _profileHelper.getAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          if (_currentProfile?.id == p.id) _currentProfile = updated;
        });
      }
    } catch (e) {
      _log('Profiles', 'Rename error: $e', isIncoming: false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TEMPLATE MANAGEMENT
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _initTemplates() async {
    try {
      await _templateHelper.seedDefaults();
      final t = await _templateHelper.getAllTemplates();
      if (mounted) setState(() => _templates = t);
    } catch (e) {
      _log('Templates', 'Load error: $e', isIncoming: false);
    }
  }

  void _loadTemplate(MessageTemplate t) {
    setState(() {
      _currentTemplate = t;
      _pubTopicCtrl.text = t.topic;
      _payloadCtrl.text = t.payload;
      _qos = MqttQos.values[t.qos.clamp(0, 2)];
      _retain = t.retain;
    });
  }

  Future<void> _saveAsTemplate() async {
    final t = MessageTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Template ${_templates.length + 1}',
      topic: _pubTopicCtrl.text.trim(),
      payload: _payloadCtrl.text.trim(),
      qos: _qos.index,
      retain: _retain,
      createdAt: DateTime.now(),
    );
    try {
      await _templateHelper.insertTemplate(t);
      final templates = await _templateHelper.getAllTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _currentTemplate = t;
        });
      }
      _log('Templates', 'Saved: ${t.name}', isIncoming: false);
    } catch (e) {
      _log('Templates', 'Save error: $e', isIncoming: false);
    }
  }

  Future<void> _deleteTemplate(MessageTemplate t) async {
    try {
      await _templateHelper.deleteTemplate(t.id);
      final templates = await _templateHelper.getAllTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          if (_currentTemplate?.id == t.id) _currentTemplate = null;
        });
      }
    } catch (e) {
      _log('Templates', 'Delete error: $e', isIncoming: false);
    }
  }

  Future<void> _renameTemplate(MessageTemplate t, String newName) async {
    try {
      final updated = MessageTemplate(
          id: t.id,
          name: newName,
          topic: t.topic,
          payload: t.payload,
          qos: t.qos,
          retain: t.retain,
          createdAt: t.createdAt);
      await _templateHelper.updateTemplate(updated);
      final templates = await _templateHelper.getAllTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          if (_currentTemplate?.id == t.id) _currentTemplate = updated;
        });
      }
    } catch (e) {
      _log('Templates', 'Rename error: $e', isIncoming: false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EXPORT / IMPORT
  // ──────────────────────────────────────────────────────────────────────────
  void _exportDb() async {
    try {
      final dbPath = await getDatabasesPath();
      final src = File(path.join(dbPath, 'mqtt_messages.db'));
      if (!await src.exists()) {
        _log('System', 'No messages database to export', isIncoming: false);
        return;
      }
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        _log('System', 'Cannot access downloads', isIncoming: false);
        return;
      }
      final dest = path.join(dir.path,
          'mqtt_messages_${DateTime.now().millisecondsSinceEpoch}.db');
      await src.copy(dest);
      final count = await _dbHelper.getMessageCount();
      _log('System',
          'Exported $count messages → ${path.basename(dest)}',
          isIncoming: false);
    } catch (e) {
      _log('System', 'Export error: $e', isIncoming: false);
    }
  }

  Future<void> _exportBackup() async {
    try {
      final profiles = await _profileHelper.getAllProfiles();
      final templates = await _templateHelper.getAllTemplates();
      final json = jsonEncode({
        'profiles': profiles.map((p) => p.toMap()).toList(),
        'templates': templates.map((t) => t.toMap()).toList(),
        'exportDate': DateTime.now().toIso8601String(),
      });
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        _log('System', 'Cannot access downloads', isIncoming: false);
        return;
      }
      final name =
          'mqtt_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      await File(path.join(dir.path, name)).writeAsString(json);
      _log('System',
          'Backup saved: $name (${profiles.length} profiles, ${templates.length} templates)',
          isIncoming: false);
    } catch (e) {
      _log('System', 'Backup error: $e', isIncoming: false);
    }
  }

  Future<void> _importBackup() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      if (r == null) return;
      final content = await File(r.files.single.path!).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final pList = (data['profiles'] as List?) ?? [];
      final tList = (data['templates'] as List?) ?? [];

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Backup'),
          content: Text(
              'Import ${pList.length} profiles and ${tList.length} templates?\n\nThis replaces all existing data.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import')),
          ],
        ),
      );
      if (ok != true) return;

      // FIX: clear through repository layer, never bypass it
      await _profileHelper.deleteAll();
      await _templateHelper.deleteAll();

      int pc = 0, tc = 0;
      for (final d in pList) {
        try {
          await _profileHelper.insertProfile(
              ConnectionProfile.fromMap(Map<String, dynamic>.from(d)));
          pc++;
        } catch (_) {}
      }
      for (final d in tList) {
        try {
          await _templateHelper.insertTemplate(
              MessageTemplate.fromMap(Map<String, dynamic>.from(d)));
          tc++;
        } catch (_) {}
      }
      await _initProfiles();
      await _initTemplates();
      _log('System', 'Import complete: $pc profiles, $tc templates',
          isIncoming: false);
    } catch (e) {
      _log('System', 'Import error: $e', isIncoming: false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ──────────────────────────────────────────────────────────────────────────
  void _showDeleteProfileDialog(ConnectionProfile p) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Profile'),
          content: Text('Delete "${p.name}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                _deleteProfile(p);
                Navigator.pop(ctx);
              },
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

  void _showRenameProfileDialog(ConnectionProfile p) {
    final ctrl = TextEditingController(text: p.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Profile'),
        content: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(labelText: 'Profile Name'),
            autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _renameProfile(p, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showRenameTemplateDialog(MessageTemplate t) {
    final ctrl = TextEditingController(text: t.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Template'),
        content: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(labelText: 'Template Name'),
            autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _renameTemplate(t, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showHelp() => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('MQTT Help'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('URL Schemes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('• tcp:// — plaintext MQTT (port 1883)'),
                Text('• ssl:// — TLS-encrypted MQTT (port 8883)'),
                Text('• ws://  — WebSocket MQTT (port 8083)'),
                Text('• wss:// — WebSocket + TLS (port 8084)'),
                SizedBox(height: 12),
                Text('Public Test Brokers:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• test.mosquitto.org — no auth required'),
                Text('• broker.emqx.io — no auth required'),
                Text('• broker.hivemq.com — no auth required'),
                SizedBox(height: 12),
                Text('Wildcards:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• +  single level: sensor/+/temp'),
                Text('• #  multi-level (must be last): home/#'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it')),
          ],
        ),
      );

  // ──────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ──────────────────────────────────────────────────────────────────────────
  Color get _statusColor {
    switch (_connectionStatus) {
      case MqttConnectionStatus.disconnected:
        return Colors.grey;
      case MqttConnectionStatus.connecting:
      case MqttConnectionStatus.reconnecting:
        return Colors.orange;
      case MqttConnectionStatus.connected:
        return Colors.green;
      case MqttConnectionStatus.error:
        return Colors.red;
    }
  }

  String get _statusText {
    switch (_connectionStatus) {
      case MqttConnectionStatus.disconnected:
        return 'DISCONNECTED';
      case MqttConnectionStatus.connecting:
        return 'CONNECTING…';
      case MqttConnectionStatus.connected:
        return 'CONNECTED  •  ${_fmtDuration(_uptime)}';
      case MqttConnectionStatus.reconnecting:
        return 'RECONNECTING… ($_reconnectAttempts/$_maxReconnectAttempts)';
      case MqttConnectionStatus.error:
        return 'CONNECTION ERROR';
    }
  }

  Widget _chip(String label, Color bg, Color fg, VoidCallback onTap) =>
      ActionChip(
        label: Text(label, style: TextStyle(color: fg, fontSize: 12)),
        backgroundColor: bg,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
      );

  Widget _certRow({
    required IconData icon,
    required Color color,
    required String label,
    required String? filePath,
    required VoidCallback onPick,
    required VoidCallback onClear,
    InputDecoration? inputDec,
  }) {
    final dark = _isDark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[800] : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text(
                filePath != null
                    ? path.basename(filePath)
                    : 'Not selected',
                style: TextStyle(
                    fontSize: 11,
                    color: filePath != null
                        ? null
                        : Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file, size: 20),
          onPressed: onPick,
          padding: const EdgeInsets.all(4),
          tooltip: 'Browse',
        ),
        if (filePath != null)
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            onPressed: onClear,
            padding: const EdgeInsets.all(4),
          ),
      ]),
    );
  }

  Widget _statsCard() {
    final rx = _liveMessages.where((m) => m.isIncoming).length;
    final tx = _liveMessages.where((m) => !m.isIncoming).length;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          _statPill('RX', '$rx', Colors.blue),
          const SizedBox(width: 12),
          _statPill('TX', '$tx', Colors.green),
          const SizedBox(width: 12),
          _statPill('SUB', '${_subscriptions.length}', Colors.orange),
          const SizedBox(width: 12),
          _statPill('RECONNECT',
              '$_reconnectAttempts/$_maxReconnectAttempts', Colors.grey),
        ]),
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: color.withOpacity(0.7),
                    letterSpacing: 0.5)),
          ],
        ),
      );

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = _isDark ? ThemeData.dark() : ThemeData.light();
    final id = InputDecoration(
      border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8))),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      fillColor: _isDark ? Colors.grey[800] : Colors.white,
      filled: true,
    );
    final connected =
        _connectionStatus == MqttConnectionStatus.connected;

    return MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        // ── AppBar ─────────────────────────────────────────────────────
        appBar: AppBar(
          title: const Text('MQTT Client'),
          backgroundColor: _isDark ? Colors.grey[850] : Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _showHelp,
                tooltip: 'Help'),
            IconButton(
                icon: Icon(
                    _isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => setState(() => _isDark = !_isDark),
                tooltip: _isDark ? 'Light mode' : 'Dark mode'),
          ],
        ),

        // ── BottomBar ──────────────────────────────────────────────────
        bottomNavigationBar: BottomAppBar(
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: _exportDb,
                    tooltip: 'Export message DB'),
                IconButton(
                    icon: const Icon(Icons.delete_forever),
                    onPressed: _clearMessages,
                    tooltip: 'Clear messages'),
                if (_connectionStatus == MqttConnectionStatus.error ||
                    _connectionStatus ==
                        MqttConnectionStatus.disconnected)
                  IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _forceReconnect,
                      tooltip: 'Reconnect'),
                IconButton(
                  icon: const Icon(Icons.bug_report),
                  tooltip: 'Debug info',
                  onPressed: () => _log(
                    'Debug',
                    'Status: $_connectionStatus\n'
                    'Will: $_enableWill\n'
                    'Cert: ${_certTypeName()}\n'
                    'Clean: $_cleanSession\n'
                    'KeepAlive: ${_keepAliveCtrl.text}\n'
                    'Subs: ${_subscriptions.length}\n'
                    'Client: ${_clientIdCtrl.text}',
                    isIncoming: false,
                  ),
                ),
              ]),
        ),

        // ── Body ───────────────────────────────────────────────────────
        body: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(children: [
                const SizedBox(height: 8),

                // ── Status banner ──────────────────────────────────
                GestureDetector(
                  onTap: connected ? _disconnect : _connect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _statusColor),
                    ),
                    child: Row(children: [
                      Icon(
                        connected ? Icons.wifi : Icons.wifi_off,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_statusText,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _statusColor)),
                      ),
                      if (!connected)
                        Icon(Icons.touch_app,
                            size: 16,
                            color: _statusColor.withOpacity(0.6)),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),
                _statsCard(),
                const SizedBox(height: 16),

                // ── Quick Test ─────────────────────────────────────
                _section(
                  icon: Icons.bolt,
                  iconColor: Colors.amber,
                  title: 'Quick Test Brokers',
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip('Mosquitto TCP', Colors.amber.shade100,
                        Colors.amber.shade800, () {
                      _urlCtrl.text = 'tcp://test.mosquitto.org:1883';
                      setState(() {
                        _enableTLS = false;
                        _certificateType = CertificateType.none;
                      });
                    }),
                    _chip('Mosquitto WS', Colors.amber.shade100,
                        Colors.amber.shade800, () {
                      _urlCtrl.text = 'ws://test.mosquitto.org:8080';
                      setState(() {
                        _enableTLS = false;
                        _certificateType = CertificateType.none;
                      });
                    }),
                    _chip('EMQX TCP', Colors.amber.shade100,
                        Colors.amber.shade800, () {
                      _urlCtrl.text = 'tcp://broker.emqx.io:1883';
                      setState(() {
                        _enableTLS = false;
                        _certificateType = CertificateType.none;
                      });
                    }),
                    _chip('EMQX WS', Colors.amber.shade100,
                        Colors.amber.shade800, () {
                      _urlCtrl.text = 'ws://broker.emqx.io:8083';
                      setState(() {
                        _enableTLS = false;
                        _certificateType = CertificateType.none;
                      });
                    }),
                    _chip('SSL Test', Colors.amber.shade100,
                        Colors.amber.shade800, () {
                      _urlCtrl.text = 'ssl://broker.emqx.io:8883';
                      setState(() {
                        _enableTLS = true;
                        _certificateType = CertificateType.selfSigned;
                      });
                    }),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Message Templates ──────────────────────────────
                _collapsibleSection(
                  icon: Icons.content_copy,
                  iconColor: Colors.purple,
                  title: 'Message Templates',
                  expanded: _showTemplates,
                  onToggle: () =>
                      setState(() => _showTemplates = !_showTemplates),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_templates.isEmpty)
                        const Text('No templates yet.',
                            style: TextStyle(color: Colors.grey))
                      else ...[
                        const Text('Quick Load:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _templates
                              .map((t) => GestureDetector(
                                    onLongPress: () =>
                                        _showRenameTemplateDialog(t),
                                    child: ActionChip(
                                      avatar: _currentTemplate?.id == t.id
                                          ? const Icon(Icons.check,
                                              size: 14, color: Colors.white)
                                          : const Icon(Icons.description,
                                              size: 14),
                                      label: Text(t.name,
                                          style: const TextStyle(
                                              fontSize: 12)),
                                      backgroundColor:
                                          _currentTemplate?.id == t.id
                                              ? Colors.purple
                                              : Colors.purple.shade100,
                                      labelStyle: TextStyle(
                                        color: _currentTemplate?.id == t.id
                                            ? Colors.white
                                            : Colors.purple,
                                      ),
                                      onPressed: () => _loadTemplate(t),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveAsTemplate,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white),
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Save as Template'),
                          ),
                        ),
                        if (_currentTemplate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.blue, size: 20),
                            onPressed: () => _showRenameTemplateDialog(
                                _currentTemplate!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () =>
                                _deleteTemplate(_currentTemplate!),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Connection Profiles ────────────────────────────
                _collapsibleSection(
                  icon: Icons.bookmark,
                  iconColor: Colors.purple,
                  title: 'Connection Profiles',
                  expanded: _showProfiles,
                  onToggle: () =>
                      setState(() => _showProfiles = !_showProfiles),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_profiles.isEmpty)
                        const Text('No profiles yet.',
                            style: TextStyle(color: Colors.grey))
                      else ...[
                        const Text('Quick Connect:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _profiles
                              .map((p) => GestureDetector(
                                    onLongPress: () =>
                                        _showRenameProfileDialog(p),
                                    child: ActionChip(
                                      avatar: _currentProfile?.id == p.id
                                          ? const Icon(Icons.check,
                                              size: 14, color: Colors.white)
                                          : const Icon(Icons.play_arrow,
                                              size: 14),
                                      label: Text(p.name,
                                          style: const TextStyle(
                                              fontSize: 12)),
                                      backgroundColor:
                                          _currentProfile?.id == p.id
                                              ? Colors.purple
                                              : Colors.purple.shade100,
                                      labelStyle: TextStyle(
                                        color: _currentProfile?.id == p.id
                                            ? Colors.white
                                            : Colors.purple,
                                      ),
                                      onPressed: () => _loadProfile(p),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveAsProfile,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12)),
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Save as Profile'),
                          ),
                        ),
                        if (_currentProfile != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.blue, size: 20),
                            onPressed: () => _showRenameProfileDialog(
                                _currentProfile!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () => _showDeleteProfileDialog(
                                _currentProfile!),
                          ),
                        ],
                      ]),
                      if (_currentProfile != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _updateCurrentProfile,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(
                                    color: Colors.blue)),
                            child: Text(
                                'Update "${_currentProfile!.name}" with current settings'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            const Text('Backup & Restore',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _exportBackup,
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(
                                          color: Colors.green)),
                                  icon: const Icon(Icons.backup,
                                      size: 14),
                                  label: const Text('EXPORT',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _importBackup,
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(
                                          color: Colors.blue)),
                                  icon: const Icon(Icons.restore,
                                      size: 14),
                                  label: const Text('IMPORT',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              '${_profiles.length} profile(s)  •  ${_templates.length} template(s)',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── SSL/TLS ────────────────────────────────────────
                _section(
                  icon: Icons.lock,
                  iconColor: Colors.red,
                  title: 'SSL/TLS',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          title: const Text('Enable SSL/TLS'),
                          subtitle: const Text(
                              'Use ssl:// or wss:// scheme'),
                          value: _enableTLS,
                          onChanged: (v) => setState(() {
                            _enableTLS = v ?? false;
                            if (!_enableTLS) {
                              _certificateType = CertificateType.none;
                              _verifyCertificate = true;
                              _disableCertVerification = false;
                              _clearCerts();
                            }
                          }),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                        ),
                        if (_enableTLS) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<CertificateType>(
                            value: _certificateType,
                            decoration: id.copyWith(
                                labelText: 'Certificate Type'),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                  value: CertificateType.none,
                                  child: Text(
                                      'Standard SSL/TLS (System Trust)')),
                              DropdownMenuItem(
                                  value: CertificateType.selfSigned,
                                  child:
                                      Text('Self-Signed Certificate')),
                              DropdownMenuItem(
                                  value: CertificateType.caOnly,
                                  child: Text('CA Certificate Only')),
                              DropdownMenuItem(
                                  value: CertificateType.mutualTls,
                                  child: Text('Mutual TLS')),
                            ],
                            onChanged: (v) => setState(() {
                              _certificateType =
                                  v ?? CertificateType.none;
                              _verifyCertificate = true;
                              _disableCertVerification = false;
                              if (_certificateType !=
                                      CertificateType.caOnly &&
                                  _certificateType !=
                                      CertificateType.mutualTls) {
                                _caCertPath = null;
                              }
                              if (_certificateType !=
                                  CertificateType.mutualTls) {
                                _clientCertPath = null;
                                _clientKeyPath = null;
                                _clientKeyPassword = null;
                                _keyPasswordCtrl.clear();
                              }
                            }),
                          ),
                          const SizedBox(height: 8),
                          if (_certificateType == CertificateType.none)
                            CheckboxListTile(
                              title: const Text(
                                  'Disable cert verification (dev only)'),
                              subtitle: const Text(
                                  'Accepts invalid/self-signed — NOT for production'),
                              value: _disableCertVerification,
                              onChanged: (v) => setState(() {
                                _disableCertVerification = v ?? false;
                                if (_disableCertVerification) {
                                  _verifyCertificate = false;
                                }
                              }),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            ),
                          if (_certificateType ==
                                  CertificateType.caOnly ||
                              _certificateType ==
                                  CertificateType.mutualTls)
                            _certRow(
                              icon: Icons.security,
                              color: Colors.blue,
                              label: 'CA Certificate',
                              filePath: _caCertPath,
                              onPick: _pickCaCert,
                              onClear: () =>
                                  setState(() => _caCertPath = null),
                            ),
                          if (_certificateType ==
                              CertificateType.mutualTls) ...[
                            _certRow(
                              icon: Icons.badge,
                              color: Colors.green,
                              label: 'Client Certificate',
                              filePath: _clientCertPath,
                              onPick: _pickClientCert,
                              onClear: () => setState(
                                  () => _clientCertPath = null),
                            ),
                            _certRow(
                              icon: Icons.key,
                              color: Colors.orange,
                              label: 'Private Key',
                              filePath: _clientKeyPath,
                              onPick: _pickPrivateKey,
                              onClear: () =>
                                  setState(() => _clientKeyPath = null),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _keyPasswordCtrl,
                              obscureText: true,
                              decoration: id.copyWith(
                                  labelText:
                                      'Key Password (optional)'),
                              onChanged: (v) => _clientKeyPassword =
                                  v.isNotEmpty ? v : null,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            OutlinedButton.icon(
                              onPressed: _testCertConnection,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(
                                      color: Colors.green),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8)),
                              icon: const Icon(
                                  Icons.wifi_tethering,
                                  size: 14),
                              label: const Text('TEST',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _clearCerts,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(
                                      color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8)),
                              icon: const Icon(
                                  Icons.cleaning_services,
                                  size: 14),
                              label: const Text('CLEAR',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ]),
                          if (_showCertInfo &&
                              _certInfo.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.shade200),
                              ),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Certificate Info:',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(_certInfo,
                                        style: const TextStyle(
                                            fontSize: 11)),
                                  ]),
                            ),
                          ],
                        ],
                      ]),
                ),

                const SizedBox(height: 16),

                // ── Broker Connection ──────────────────────────────
                _section(
                  icon: Icons.link,
                  iconColor: Colors.blue,
                  title: 'Broker Connection',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _urlCtrl,
                          decoration: id.copyWith(
                            labelText:
                                'Broker URL (tcp://, ws://, ssl://, wss://)',
                            hintText:
                                'tcp://test.mosquitto.org:1883',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _clientIdCtrl,
                              decoration: id.copyWith(
                                  labelText: 'Client ID',
                                  hintText: 'Leave empty to auto-generate'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => setState(() {
                              _clientIdCtrl.text =
                                  'flutter_${DateTime.now().millisecondsSinceEpoch}_${_rndStr(6)}';
                            }),
                            tooltip: 'Generate new ID',
                          ),
                        ]),
                        CheckboxListTile(
                          title: const Text('Auto-reconnect'),
                          subtitle: const Text(
                              'Reconnect automatically if connection drops'),
                          value: _autoReconnect,
                          onChanged: (v) =>
                              setState(() => _autoReconnect = v ?? true),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_reconnectAttempts > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_reconnectAttempts >=
                                          _maxReconnectAttempts
                                      ? Colors.red
                                      : Colors.orange)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _reconnectAttempts >=
                                        _maxReconnectAttempts
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                            child: Text(
                              'Reconnect: $_reconnectAttempts/$_maxReconnectAttempts',
                              style: TextStyle(
                                fontSize: 12,
                                color: _reconnectAttempts >=
                                        _maxReconnectAttempts
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        LayoutBuilder(builder: (ctx, box) {
                          final wide = box.maxWidth > 400;
                          final qosDrop =
                              DropdownButtonFormField<MqttQos>(
                            value: _qos,
                            items: const [
                              DropdownMenuItem(
                                  value: MqttQos.atMostOnce,
                                  child:
                                      Text('QoS 0 — At Most Once')),
                              DropdownMenuItem(
                                  value: MqttQos.atLeastOnce,
                                  child:
                                      Text('QoS 1 — At Least Once')),
                              DropdownMenuItem(
                                  value: MqttQos.exactlyOnce,
                                  child:
                                      Text('QoS 2 — Exactly Once')),
                            ],
                            onChanged: connected
                                ? null
                                : (v) => setState(() =>
                                    _qos = v ?? MqttQos.atMostOnce),
                            decoration:
                                id.copyWith(labelText: 'Default QoS'),
                          );
                          final btn = ElevatedButton(
                            onPressed:
                                connected ? _disconnect : _connect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  connected ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            child: Text(
                                connected ? 'DISCONNECT' : 'CONNECT'),
                          );
                          if (wide) {
                            return Row(children: [
                              Expanded(flex: 2, child: qosDrop),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: btn),
                            ]);
                          }
                          return Column(children: [
                            qosDrop,
                            const SizedBox(height: 12),
                            SizedBox(
                                width: double.infinity, child: btn),
                          ]);
                        }),
                      ]),
                ),

                const SizedBox(height: 16),

                // ── Authentication ─────────────────────────────────
                _section(
                  icon: Icons.security,
                  iconColor: Colors.purple,
                  title: 'Authentication',
                  child: Column(children: [
                    CheckboxListTile(
                      title: const Text('Enable Authentication'),
                      subtitle: const Text('Username / Password'),
                      value: _enableAuth,
                      onChanged: (v) =>
                          setState(() => _enableAuth = v ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_enableAuth) ...[
                      const SizedBox(height: 12),
                      TextField(
                          controller: _usernameCtrl,
                          decoration:
                              id.copyWith(labelText: 'Username')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _hidePassword,
                        decoration: id.copyWith(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(_hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                                () => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Connection Settings ────────────────────────────
                _section(
                  icon: Icons.settings,
                  iconColor: Colors.brown,
                  title: 'Connection Settings',
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Clean Session'),
                          subtitle: const Text(
                              'TRUE: fresh start / FALSE: persist'),
                          value: _cleanSession,
                          onChanged: (v) =>
                              setState(() => _cleanSession = v ?? true),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _keepAliveCtrl,
                          decoration: id.copyWith(
                              labelText: 'Keep Alive (s)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Will Message ───────────────────────────────────
                _section(
                  icon: Icons.emergency,
                  iconColor: Colors.orange,
                  title: 'Will Message',
                  child: Column(children: [
                    CheckboxListTile(
                      title: const Text('Enable Will Message'),
                      subtitle: const Text(
                          'Published on unexpected disconnect'),
                      value: _enableWill,
                      onChanged: (v) =>
                          setState(() => _enableWill = v ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_enableWill) ...[
                      const SizedBox(height: 12),
                      TextField(
                          controller: _willTopicCtrl,
                          decoration: id.copyWith(
                              labelText: 'Will Topic',
                              hintText: 'e.g., device/status')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _willPayloadCtrl,
                          decoration: id.copyWith(
                              labelText: 'Will Payload',
                              hintText: 'e.g., offline')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<MqttQos>(
                            value: _willQos,
                            items: const [
                              DropdownMenuItem(
                                  value: MqttQos.atMostOnce,
                                  child: Text('QoS 0')),
                              DropdownMenuItem(
                                  value: MqttQos.atLeastOnce,
                                  child: Text('QoS 1')),
                              DropdownMenuItem(
                                  value: MqttQos.exactlyOnce,
                                  child: Text('QoS 2')),
                            ],
                            onChanged: (v) => setState(() =>
                                _willQos = v ?? MqttQos.atMostOnce),
                            decoration: id.copyWith(
                                labelText: 'Will QoS'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Retain Will'),
                            value: _willRetain,
                            onChanged: (v) =>
                                setState(() => _willRetain = v ?? false),
                            dense: true,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _clearWillRetained,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(
                                  color: Colors.orange),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12)),
                          icon: const Icon(Icons.cleaning_services,
                              size: 16),
                          label: const Text(
                              'CLEAR RETAINED WILL MESSAGE'),
                        ),
                      ),
                    ],
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Subscribe ──────────────────────────────────────
                _section(
                  icon: Icons.rss_feed,
                  iconColor: Colors.green,
                  title: 'Subscribe to Topics',
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _subTopicCtrl,
                          decoration: id.copyWith(
                            labelText: 'Topic (supports + and #)',
                            hintText:
                                'e.g., sensor/+/temp, home/#',
                          ),
                          onSubmitted: (_) => _subscribe(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _subscribe,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                        ),
                        child: const Text('SUBSCRIBE',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                    if (_subscriptions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Active Subscriptions:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            IconButton(
                              icon: const Icon(Icons.refresh,
                                  size: 18),
                              onPressed: connected
                                  ? _resubscribeAll
                                  : null,
                              tooltip: 'Re-subscribe all',
                            ),
                          ]),
                      const Divider(),
                      ..._subscriptions.map((s) => ListTile(
                            dense: true,
                            title: Text(
                              s.topic,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: s.topic.contains('+') ||
                                        s.topic.contains('#')
                                    ? Colors.orange
                                    : null,
                                fontWeight: s.topic.contains('+') ||
                                        s.topic.contains('#')
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                                'QoS ${s.qos.index}${s.topic.contains('+') || s.topic.contains('#') ? '  •  Wildcard' : ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red, size: 18),
                              onPressed: () =>
                                  _unsubscribe(s.topic),
                            ),
                          )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Subscriptions are automatically restored after reconnect',
                          style: TextStyle(
                              fontSize: 11, color: Colors.green),
                        ),
                      ),
                    ],
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Publish ────────────────────────────────────────
                _section(
                  icon: Icons.send,
                  iconColor: Colors.purple,
                  title: 'Publish Message',
                  child: Column(children: [
                    if (_subscriptions.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Quick-select topic:',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _subscriptions
                            .map((s) => FilterChip(
                                  label: Text(s.topic,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _pubTopicCtrl.text ==
                                                s.topic
                                            ? Colors.white
                                            : null,
                                      )),
                                  selected:
                                      _pubTopicCtrl.text == s.topic,
                                  onSelected: (_) => setState(
                                      () =>
                                          _pubTopicCtrl.text =
                                              s.topic),
                                  backgroundColor: Colors.grey[200],
                                  selectedColor: Colors.purple,
                                  checkmarkColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                        controller: _pubTopicCtrl,
                        decoration: id.copyWith(
                            labelText: 'Topic to publish')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _payloadCtrl,
                      decoration:
                          id.copyWith(labelText: 'Payload'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Retain Message'),
                      subtitle: const Text(
                          'Broker keeps last message for new subscribers'),
                      value: _retain,
                      onChanged: (v) =>
                          setState(() => _retain = v ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.purple,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _publish,
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('PUBLISH'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _clearRetained,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(
                                color: Colors.orange),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12)),
                        child: const Text('CLEAR RETAINED MESSAGE'),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Message Log ────────────────────────────────────
                _section(
                  icon: Icons.message,
                  iconColor: Colors.teal,
                  title: 'Message Log',
                  trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showHistory
                                ? Icons.live_tv
                                : Icons.history,
                            color: _showHistory
                                ? Colors.blue
                                : Colors.grey,
                            size: 20,
                          ),
                          onPressed: _toggleHistory,
                          tooltip: _showHistory
                              ? 'Live view'
                              : 'Full history',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '${_filtered.length}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ]),
                  child: Column(children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: id.copyWith(
                        labelText: 'Search…',
                        prefixIcon:
                            const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                })
                            : null,
                      ),
                      onChanged: _onSearch,
                    ),
                    if (_searchQuery.isNotEmpty ||
                        _showHistory) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _showHistory
                              ? 'Full history — ${_filtered.length} message(s)'
                              : '${_filtered.length} matching "$_searchQuery"',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.blue),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: _isDark
                            ? Colors.grey[850]
                            : Colors.grey.shade50,
                      ),
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox,
                                      size: 44,
                                      color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No results for "$_searchQuery"'
                                        : 'No messages yet.\nConnect & subscribe to see data here.',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => MessageItem(
                                  message: _filtered[i]),
                            ),
                    ),
                  ]),
                ),

                const SizedBox(height: 80),
              ]),
            ),
          ),

          // ── Scroll-to-top FAB ──────────────────────────────────────
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.small(
              onPressed: () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut);
                }
              },
              tooltip: 'Scroll to top',
              child: const Icon(Icons.arrow_upward),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Layout helpers ─────────────────────────────────────────────────────────
  Widget _section({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _collapsibleSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              IconButton(
                icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: iconColor),
                onPressed: onToggle,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ]),
            if (expanded) ...[
              const SizedBox(height: 14),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_mobile_client/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

// Connection state enum for better state management
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error
}

// Connection Profile Class
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

  ConnectionProfile({
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
  });

  Map<String, dynamic> toMap() {
    return {
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
    };
  }

  factory ConnectionProfile.fromMap(Map<String, dynamic> map) {
    return ConnectionProfile(
      id: map['id'],
      name: map['name'],
      brokerUrl: map['brokerUrl'],
      clientId: map['clientId'],
      username: map['username'],
      password: map['password'],
      enableAuth: map['enableAuth'] == 1,
      cleanSession: map['cleanSession'] == 1,
      keepAlive: map['keepAlive'],
      defaultQos: map['defaultQos'],
      enableWill: map['enableWill'] == 1,
      willTopic: map['willTopic'],
      willPayload: map['willPayload'],
      willQos: map['willQos'],
      willRetain: map['willRetain'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

// Message Template Class
class MessageTemplate {
  final String id;
  final String name;
  final String topic;
  final String payload;
  final int qos;
  final bool retain;
  final DateTime createdAt;

  MessageTemplate({
    required this.id,
    required this.name,
    required this.topic,
    required this.payload,
    required this.qos,
    required this.retain,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'topic': topic,
      'payload': payload,
      'qos': qos,
      'retain': retain ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory MessageTemplate.fromMap(Map<String, dynamic> map) {
    return MessageTemplate(
      id: map['id'],
      name: map['name'],
      topic: map['topic'],
      payload: map['payload'],
      qos: map['qos'],
      retain: map['retain'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

class ProfileHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFile = path.join(dbPath, 'mqtt_profiles.db');
    
    return await openDatabase(
      dbFile,
      version: 2,
      onCreate: (db, version) {
        return db.execute('''
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
            createdAt INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          // Add any schema upgrades here
        }
      },
    );
  }

  Future<void> createDefaultProfiles() async {
    final profiles = await getAllProfiles();
    if (profiles.isEmpty) {
      final defaultProfile = ConnectionProfile(
        id: 'default_1',
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
      );
      await insertProfile(defaultProfile);
    }
  }

  Future<int> insertProfile(ConnectionProfile profile) async {
    final db = await database;
    return await db.insert('profiles', profile.toMap());
  }

  Future<List<ConnectionProfile>> getAllProfiles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('profiles');
    return List.generate(maps.length, (i) => ConnectionProfile.fromMap(maps[i]));
  }

  Future<int> deleteProfile(String id) async {
    final db = await database;
    return await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProfile(ConnectionProfile profile) async {
    final db = await database;
    return await db.update(
      'profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  // Export profiles to JSON
  Future<String> exportProfilesToJson() async {
    final profiles = await getAllProfiles();
    final exportData = {
      'profiles': profiles.map((p) => p.toMap()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
    return jsonEncode(exportData);
  }

  // Import profiles from JSON
  Future<int> importProfilesFromJson(String jsonData) async {
    final data = jsonDecode(jsonData);
    final List<dynamic> profilesData = data['profiles'];
    int count = 0;
    
    for (final profileData in profilesData) {
      final profile = ConnectionProfile.fromMap(Map<String, dynamic>.from(profileData));
      await insertProfile(profile);
      count++;
    }
    
    return count;
  }
}

// Template Helper
class TemplateHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFile = path.join(dbPath, 'mqtt_templates.db');
    
    return await openDatabase(
      dbFile,
      version: 2,
      onCreate: (db, version) {
        return db.execute('''
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
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          // Add any schema upgrades here
        }
      },
    );
  }

  Future<void> createDefaultTemplates() async {
    final templates = await getAllTemplates();
    if (templates.isEmpty) {
      final defaultTemplates = [
        MessageTemplate(
          id: 'template_1',
          name: 'Sensor Data',
          topic: 'sensor/temperature',
          payload: '{"temperature": 25.5, "humidity": 60}',
          qos: 0,
          retain: false,
          createdAt: DateTime.now(),
        ),
        MessageTemplate(
          id: 'template_2',
          name: 'Device Status',
          topic: 'device/status',
          payload: 'online',
          qos: 1,
          retain: true,
          createdAt: DateTime.now(),
        ),
        MessageTemplate(
          id: 'template_3',
          name: 'JSON Command',
          topic: 'device/command',
          payload: '{"command": "restart", "delay": 5}',
          qos: 0,
          retain: false,
          createdAt: DateTime.now(),
        ),
      ];
      
      for (final template in defaultTemplates) {
        await insertTemplate(template);
      }
    }
  }

  Future<int> insertTemplate(MessageTemplate template) async {
    final db = await database;
    return await db.insert('templates', template.toMap());
  }

  Future<List<MessageTemplate>> getAllTemplates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('templates');
    return List.generate(maps.length, (i) => MessageTemplate.fromMap(maps[i]));
  }

  Future<int> deleteTemplate(String id) async {
    final db = await database;
    return await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTemplate(MessageTemplate template) async {
    final db = await database;
    return await db.update(
      'templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  // Export templates to JSON
  Future<String> exportTemplatesToJson() async {
    final templates = await getAllTemplates();
    final exportData = {
      'templates': templates.map((t) => t.toMap()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
    return jsonEncode(exportData);
  }

  // Import templates from JSON
  Future<int> importTemplatesFromJson(String jsonData) async {
    final data = jsonDecode(jsonData);
    final List<dynamic> templatesData = data['templates'];
    int count = 0;
    
    for (final templateData in templatesData) {
      final template = MessageTemplate.fromMap(Map<String, dynamic>.from(templateData));
      await insertTemplate(template);
      count++;
    }
    
    return count;
  }
}

class MqttCorrect extends StatefulWidget {
  const MqttCorrect({super.key});
  @override
  State<MqttCorrect> createState() => _MqttCorrectState();
}

class _MqttCorrectState extends State<MqttCorrect> {
  // Text editing controllers for user input fields
  final urlCtrl = TextEditingController(text: 'tcp://test.mosquitto.org:1883');
  final clientIdCtrl = TextEditingController();
  final subTopicCtrl = TextEditingController(text: 'test/topic');
  final pubTopicCtrl = TextEditingController(text: 'test/topic');
  final payloadCtrl = TextEditingController(text: '{"message":"flutter mqtt"}');

  // PROFILE MANAGEMENT VARIABLES
  final ProfileHelper _profileHelper = ProfileHelper();
  List<ConnectionProfile> _profiles = [];
  ConnectionProfile? _currentProfile;
  bool _showProfiles = false;

  // AUTHENTICATION VARIABLES
  bool _enableAuth = false;
  final usernameCtrl = TextEditingController(text: '');
  final passwordCtrl = TextEditingController(text: '');
  bool _hidePassword = true;

  // SSL/TLS VARIABLES
  bool _enableTLS = false;
  bool _allowSelfSigned = true;

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _showHistory = false;

  bool _cleanSession = true; // Changed to true by default for better reconnection
  final keepAliveCtrl = TextEditingController(text: '60');

  // AUTO-RECONNECT VARIABLES
  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  
  // CONNECTION HEALTH MONITORING
  Timer? _connectionHealthTimer;
  int _missedPings = 0;
  final int _maxMissedPings = 3;
  
  // Connection uptime tracking
  DateTime? _connectionStartTime;
  Timer? _uptimeTimer;
  Duration _connectionUptime = Duration.zero;
  
  // Keep-alive timer
  Timer? _keepAliveTimer;

  // retain message
  bool _retainMessage = false; 

  // WILL MESSAGE VARIABLES
  bool _enableWillMessage = false;
  final willTopicCtrl = TextEditingController(text: 'device/status');
  final willPayloadCtrl = TextEditingController(text: 'offline');
  MqttQos _willQos = MqttQos.atMostOnce;
  bool _willRetain = false;

  // MQTT client and connection state variables
  MqttServerClient? _client;
  MqttQos _qos = MqttQos.atMostOnce;
  
  // Use ConnectionState enum instead of boolean
  ConnectionState _connectionState = ConnectionState.disconnected;
  
  StreamSubscription? _updatesSub;
  
  // Data structures to track messages and subscriptions
  List<Message> _messages = [];
  final List<Subscription> _subscriptions = [];

  // MESSAGE SEARCH VARIABLES
  String _searchQuery = '';
  final searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  // THEME VARIABLES
  bool _isDarkMode = false;

  // TEMPLATE VARIABLES
  final TemplateHelper _templateHelper = TemplateHelper();
  List<MessageTemplate> _templates = [];
  bool _showTemplates = false;
  MessageTemplate? _currentTemplate;

  // Message limit to prevent memory issues
  static const int _maxMessages = 1000;
  
  // NEW: Track if we need to restore subscriptions
  bool _shouldRestoreSubscriptions = false;

  @override
  void initState() {
    super.initState();
    _loadMessageHistory();
    _initializeProfiles();
    _initializeTemplates();
    // Generate a unique client ID on startup
    clientIdCtrl.text = 'flutter_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(4)}';
  }

  // Generate random string for client ID
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  // FORMAT DURATION FOR UPTIME DISPLAY
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // START UPTIME TRACKER
  void _startUptimeTracker() {
    _connectionStartTime = DateTime.now();
    _uptimeTimer?.cancel();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_connectionStartTime != null) {
        setState(() {
          _connectionUptime = DateTime.now().difference(_connectionStartTime!);
        });
      }
    });
  }

  // STOP UPTIME TRACKER
  void _stopUptimeTracker() {
    _uptimeTimer?.cancel();
    _connectionStartTime = null;
    _connectionUptime = Duration.zero;
  }

  // KEEP-ALIVE PING SYSTEM - IMPROVED VERSION


// KEEP-ALIVE SYSTEM - FIXED VERSION
void _startKeepAlive() {
  _keepAliveTimer?.cancel();
  
  // Use the keep-alive period from the connection settings
  final keepAliveSeconds = int.tryParse(keepAliveCtrl.text) ?? 60;
  
  // Send keep-alive messages at half the keep-alive interval
  final intervalSeconds = (keepAliveSeconds / 2).clamp(10, 30).toInt();
  
  _logMessage('KeepAlive', '⏱️ Starting keep-alive every $intervalSeconds seconds', isIncoming: false);
  
  _keepAliveTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
    if (_connectionState == ConnectionState.connected && _client != null) {
      try {
        // Send a small keep-alive message to maintain connection
        final builder = MqttClientPayloadBuilder()
          ..addString('{"type":"keepalive","timestamp":${DateTime.now().millisecondsSinceEpoch},"client":"${clientIdCtrl.text}"}');
        
        // Use QoS 0 for keep-alive to avoid overhead
        _client!.publishMessage(
          '\$SYS/${clientIdCtrl.text}/keepalive',
          MqttQos.atMostOnce,
          builder.payload!
        );
        
        _logMessage('KeepAlive', '💓 Keep-alive sent', isIncoming: false);
        
        // Update missed pings counter
        _missedPings = (_missedPings - 1).clamp(0, _maxMissedPings);
        
      } catch (e) {
        _logMessage('KeepAlive', '❌ Keep-alive failed: $e', isIncoming: false);
        _missedPings++;
        
        // If we've missed too many pings, try to reconnect
        if (_missedPings >= _maxMissedPings && _autoReconnect) {
          _logMessage('Connection', '🔄 Too many missed keep-alives, attempting reconnect', isIncoming: false);
          _forceReconnect();
        }
      }
    }
  });
}

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
  }

  // INITIALIZE TEMPLATES
  Future<void> _initializeTemplates() async {
    try {
      await _templateHelper.createDefaultTemplates();
      final templates = await _templateHelper.getAllTemplates();
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      _logMessage('Templates', 'Error loading templates: $e', isIncoming: false);
    }
  }

  // LOAD TEMPLATE
  void _loadTemplate(MessageTemplate template) {
    setState(() {
      _currentTemplate = template;
      pubTopicCtrl.text = template.topic;
      payloadCtrl.text = template.payload;
      _qos = MqttQos.values[template.qos.clamp(0, 2)];
      _retainMessage = template.retain;
    });
    _logMessage('Templates', '✅ Loaded template: ${template.name}', isIncoming: false);
  }

  // SAVE CURRENT AS TEMPLATE
  Future<void> _saveCurrentAsTemplate() async {
    final template = MessageTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Template ${_templates.length + 1}',
      topic: pubTopicCtrl.text.trim(),
      payload: payloadCtrl.text.trim(),
      qos: _qos.index,
      retain: _retainMessage,
      createdAt: DateTime.now(),
    );
    
    try {
      await _templateHelper.insertTemplate(template);
      final templates = await _templateHelper.getAllTemplates();
      setState(() {
        _templates = templates;
        _currentTemplate = template;
      });
      _logMessage('Templates', '✅ Template saved: ${template.name}', isIncoming: false);
    } catch (e) {
      _logMessage('Templates', '❌ Error saving template: $e', isIncoming: false);
    }
  }

  // DELETE TEMPLATE
  void _deleteTemplate(MessageTemplate template) async {
    try {
      await _templateHelper.deleteTemplate(template.id);
      final templates = await _templateHelper.getAllTemplates();
      setState(() {
        _templates = templates;
        if (_currentTemplate?.id == template.id) {
          _currentTemplate = null;
        }
      });
      _logMessage('Templates', '🗑️ Deleted template: ${template.name}', isIncoming: false);
    } catch (e) {
      _logMessage('Templates', '❌ Error deleting template: $e', isIncoming: false);
    }
  }

  // MESSAGE SEARCH FUNCTIONALITY WITH DEBOUNCE
  List<Message> get _filteredMessages {
    if (_searchQuery.isEmpty) return _messages;
    
    final query = _searchQuery.toLowerCase();
    return _messages.where((message) {
      return message.topic.toLowerCase().contains(query) ||
             message.payload.toLowerCase().contains(query);
    }).toList();
  }

  // DEBOUNCED SEARCH HANDLER
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value);
    });
  }

  // WILDCARD SUBSCRIPTION VALIDATION
  bool _isValidWildcardTopic(String topic) {
    if (topic.contains('#') && topic.indexOf('#') != topic.length - 1) {
      return false;
    }
    if (topic.contains('+') && topic.split('+').length > 1) {
      final parts = topic.split('/');
      for (final part in parts) {
        if (part.contains('+') && part != '+') {
          return false;
        }
      }
    }
    return true;
  }

  // CONNECTION HEALTH MONITORING
  void _startConnectionHealthCheck() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_connectionState == ConnectionState.connected && _client != null) {
        _missedPings++;
        if (_missedPings >= _maxMissedPings) {
          _logMessage('Connection', '🫀 Connection seems dead, forcing reconnect', isIncoming: false);
          _client?.disconnect();
          _onDisconnectedWithReconnect();
        }
      }
    });
  }

  // AUTO-RECONNECT FUNCTIONALITY
  void _setupAutoReconnect() {
    _client?.onDisconnected = _onDisconnectedWithReconnect;
  }

  void _onDisconnectedWithReconnect() {
    _logMessage('Connection', '🔌 Connection lost', isIncoming: false);
    setState(() => _connectionState = ConnectionState.disconnected);
    
    _connectionHealthTimer?.cancel();
    _stopUptimeTracker();
    _stopKeepAlive();
    
    // IMPORTANT: Mark that we need to restore subscriptions
    _shouldRestoreSubscriptions = true;
    
    if (_autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      setState(() => _connectionState = ConnectionState.reconnecting);
      
      final delaySeconds = _reconnectAttempts * 2;
      _logMessage('Connection', 
          '🔄 Auto-reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delaySeconds}s', 
          isIncoming: false);
      
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        _logMessage('Connection', '🔗 Attempting to reconnect...', isIncoming: false);
        _connect();
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logMessage('Connection', 
          '❌ Max reconnect attempts ($_maxReconnectAttempts) reached. Giving up.', 
          isIncoming: false);
      setState(() => _connectionState = ConnectionState.error);
    }
  }

  // MANUAL RECONNECT TRIGGER
  void _forceReconnect() {
    _logMessage('Connection', '🔄 Manual reconnect triggered', isIncoming: false);
    _cancelAutoReconnect();
    _reconnectAttempts = 0;
    if (_connectionState == ConnectionState.connected) {
      _client?.disconnect();
    } else {
      _connect();
    }
  }

  void _cancelAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }

  // PROFILE MANAGEMENT METHODS
  void _showDeleteDialog(ConnectionProfile profile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Profile'),
          content: Text('Are you sure you want to delete "${profile.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteProfile(profile);
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(ConnectionProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Profile'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Profile Name',
              hintText: 'Enter profile name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _renameProfile(profile, nameController.text.trim());
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameProfile(ConnectionProfile profile, String newName) async {
    try {
      final updatedProfile = ConnectionProfile(
        id: profile.id,
        name: newName,
        brokerUrl: profile.brokerUrl,
        clientId: profile.clientId,
        username: profile.username,
        password: profile.password,
        enableAuth: profile.enableAuth,
        cleanSession: profile.cleanSession,
        keepAlive: profile.keepAlive,
        defaultQos: profile.defaultQos,
        enableWill: profile.enableWill,
        willTopic: profile.willTopic,
        willPayload: profile.willPayload,
        willQos: profile.willQos,
        willRetain: profile.willRetain,
        createdAt: profile.createdAt,
      );
      
      await _profileHelper.updateProfile(updatedProfile);
      final profiles = await _profileHelper.getAllProfiles();
      setState(() {
        _profiles = profiles;
        if (_currentProfile?.id == profile.id) {
          _currentProfile = updatedProfile;
        }
      });
      _logMessage('Profiles', '✅ Renamed profile to: $newName', isIncoming: false);
    } catch (e) {
      _logMessage('Profiles', '❌ Error renaming profile: $e', isIncoming: false);
    }
  }

  Future<void> _initializeProfiles() async {
    try {
      await _profileHelper.createDefaultProfiles();
      final profiles = await _profileHelper.getAllProfiles();
      setState(() {
        _profiles = profiles;
      });
    } catch (e) {
      _logMessage('Profiles', 'Error loading profiles: $e', isIncoming: false);
    }
  }

  // Load saved messages when app starts
  Future<void> _loadMessageHistory() async {
    try {
      final savedMessages = await _databaseHelper.getAllMessages();
      setState(() {
        _messages.addAll(savedMessages.map((history) => Message(
          id: history.id,
          topic: history.topic,
          payload: history.payload,
          isIncoming: history.isIncoming,
          timestamp: history.timestamp,
          qos: history.qos,
        )).toList());
      });
    } catch (e) {
      _logMessage('Database', 'Error loading history: $e', isIncoming: false);
    }
  }

  // LOG MESSAGE WITH MEMORY LIMIT
  void _logMessage(String topic, String message, {bool isIncoming = true, int qos = 0}) async {
    if (_messages.length >= _maxMessages) {
      setState(() {
        _messages = _messages.sublist(0, _maxMessages ~/ 2);
      });
    }
    
    final newMessage = Message(
      topic: topic,
      payload: message,
      isIncoming: isIncoming,
      timestamp: DateTime.now(),
      qos: qos,
    );
    
    setState(() {
      _messages.insert(0, newMessage);
    });

    try {
      await _databaseHelper.insertMessage(newMessage.toMessageHistory());
    } catch (e) {
      print('Database save error: $e');
    }
  }

  // Enhanced clear messages that also clears database
  void _clearMessages() async {
    try {
      await _databaseHelper.clearAllMessages();
      setState(() => _messages.clear());
      _logMessage('System', 'Message log and history cleared', isIncoming: false);
    } catch (e) {
      _logMessage('System', 'Error clearing history: $e', isIncoming: false);
    }
  }

  void _clearRetainedMessage() {
    final c = _client;
    if (_connectionState != ConnectionState.connected || c == null) {
      _logMessage('System', 'Not connected to broker', isIncoming: false);
      return;
    }
    
    final topic = pubTopicCtrl.text.trim();
    if (topic.isEmpty) {
      _logMessage('System', 'Enter a topic to clear retained message', isIncoming: false);
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder()..addString('');
      c.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
      
      _logMessage('System', '🧹 Cleared retained message for: $topic', isIncoming: false);
      _logMessage('System', '💡 New subscribers will no longer receive old retained messages', isIncoming: false);
    } catch (e) {
      _logMessage('System', '❌ Error clearing retained message: $e', isIncoming: false);
    }
  }

  // Clear Will Retained Message functionality
  void _clearWillRetainedMessage() {
    final c = _client;
    if (_connectionState != ConnectionState.connected || c == null) {
      _logMessage('System', 'Not connected to broker', isIncoming: false);
      return;
    }
    
    final topic = willTopicCtrl.text.trim();
    if (topic.isEmpty) {
      _logMessage('System', 'Enter a Will topic to clear retained Will message', isIncoming: false);
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder()..addString('');
      c.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
      
      _logMessage('System', '🧹 Cleared retained Will message for: $topic', isIncoming: false);
      _logMessage('System', '💡 Will message has been cleared from broker', isIncoming: false);
    } catch (e) {
      _logMessage('System', '❌ Error clearing retained Will message: $e', isIncoming: false);
    }
  }

  // Export database to Downloads
  void _exportDatabase() async {
    try {
      _logMessage('System', '📤 Starting database export...', isIncoming: false);
      
      final databasesPath = await getDatabasesPath();
      final dbFile = File(path.join(databasesPath, 'mqtt_messages.db'));
      
      if (await dbFile.exists()) {
        final downloadsDir = await getDownloadsDirectory();
        final exportPath = path.join(downloadsDir!.path, 'mqtt_messages_${DateTime.now().millisecondsSinceEpoch}.db');
        
        await dbFile.copy(exportPath);
        
        _logMessage('System', '✅ Database exported successfully!', isIncoming: false);
        _logMessage('System', '📁 Location: $exportPath', isIncoming: false);
        _logMessage('System', '📊 File: ${path.basename(exportPath)}', isIncoming: false);
        
        final messageCount = await _databaseHelper.getMessageCount();
        _logMessage('System', '📈 Total messages in database: $messageCount', isIncoming: false);
      } else {
        _logMessage('System', '❌ Database file not found', isIncoming: false);
        _logMessage('System', '💡 Send some messages first, then try again', isIncoming: false);
      }
    } catch (e) {
      _logMessage('System', '❌ Export error: $e', isIncoming: false);
    }
  }

  // Export Profiles and Templates
  Future<void> _exportProfilesAndTemplates() async {
    try {
      _logMessage('System', '📤 Exporting profiles and templates...', isIncoming: false);
      
      final profilesJson = await _profileHelper.exportProfilesToJson();
      final templatesJson = await _templateHelper.exportTemplatesToJson();
      
      final exportData = {
        'profiles': jsonDecode(profilesJson),
        'templates': jsonDecode(templatesJson),
        'exportDate': DateTime.now().toIso8601String(),
      };
      
      final downloadsDir = await getDownloadsDirectory();
      final exportPath = path.join(downloadsDir!.path, 'mqtt_config_${DateTime.now().millisecondsSinceEpoch}.json');
      
      await File(exportPath).writeAsString(jsonEncode(exportData));
      
      _logMessage('System', '✅ Profiles & templates exported!', isIncoming: false);
      _logMessage('System', '📁 Location: $exportPath', isIncoming: false);
    } catch (e) {
      _logMessage('System', '❌ Export error: $e', isIncoming: false);
    }
  }

  // Toggle between live view and full history
  void _toggleHistoryView() async {
    if (_showHistory) {
      setState(() {
        _showHistory = false;
        if (_messages.length > 100) {
          _messages = _messages.sublist(0, 100);
        }
      });
    } else {
      try {
        final allMessages = await _databaseHelper.getAllMessages();
        setState(() {
          _showHistory = true;
          _messages = allMessages.map((history) => Message(
            id: history.id,
            topic: history.topic,
            payload: history.payload,
            isIncoming: history.isIncoming,
            timestamp: history.timestamp,
            qos: history.qos,
          )).toList();
        });
        _logMessage('System', 'Showing full message history (${allMessages.length} messages)', isIncoming: false);
      } catch (e) {
        _logMessage('System', 'Error loading full history: $e', isIncoming: false);
      }
    }
  }

  // VALIDATE WILL CONFIGURATION - NEW METHOD
  bool _validateWillConfiguration() {
    if (!_enableWillMessage) return true;
    
    final willTopic = willTopicCtrl.text.trim();
    final willPayload = willPayloadCtrl.text.trim();
    
    if (willTopic.isEmpty) {
      _logMessage('Will', '❌ Will topic cannot be empty', isIncoming: false);
      return false;
    }
    
    if (willPayload.isEmpty) {
      _logMessage('Will', '❌ Will payload cannot be empty', isIncoming: false);
      return false;
    }
    
    // Check for problematic topic patterns
    if (willTopic.contains('#') || willTopic.contains('+')) {
      _logMessage('Will', '❌ Will topic cannot contain wildcards (# or +)', isIncoming: false);
      return false;
    }
    
    // Check topic length
    if (willTopic.length > 65535) {
      _logMessage('Will', '❌ Will topic too long', isIncoming: false);
      return false;
    }
    
    // Check payload size (limit to 256MB for MQTT 5, 256MB for MQTT 3.1.1)
    final payloadBytes = utf8.encode(willPayload).length;
    if (payloadBytes > 268435456) {
      _logMessage('Will', '❌ Will payload too large (max 256MB)', isIncoming: false);
      return false;
    }
    
    return true;
  }

  // APPLY BROKER-SPECIFIC SETTINGS - NEW METHOD
 // APPLY BROKER-SPECIFIC SETTINGS - CORRECTED VERSION
void _applyBrokerSpecificSettings(MqttServerClient client, String url) {
  final uri = Uri.parse(url);
  final host = uri.host.toLowerCase();
  
  // Mosquitto-specific settings
  if (host.contains('mosquitto')) {
    _logMessage('Broker', '🎯 Applying Mosquitto-specific settings', isIncoming: false);
    
    // Mosquitto has strict session handling with Will messages
    if (_enableWillMessage) {
      // Mosquitto prefers clean session = false with Will messages
      if (_cleanSession) {
        _logMessage('Broker', '⚠️ Mosquitto: Forcing Clean Session = FALSE for Will messages', isIncoming: false);
      }
      
      // Mosquitto requires proper keep-alive with Will messages
      // Set shorter keep-alive period
      final currentKeepAlive = int.tryParse(keepAliveCtrl.text) ?? 60;
      if (currentKeepAlive > 30) {
        keepAliveCtrl.text = '30';
        _logMessage('Broker', '📊 Adjusted keep-alive to 30 seconds for Mosquitto', isIncoming: false);
      }
    }
  }
  
  // EMQX-specific settings
  else if (host.contains('emqx')) {
    _logMessage('Broker', '🎯 Applying EMQX-specific settings', isIncoming: false);
    
    // EMQX is more lenient with Will messages
    if (_enableWillMessage) {
      final currentKeepAlive = int.tryParse(keepAliveCtrl.text) ?? 60;
      if (currentKeepAlive > 45) {
        keepAliveCtrl.text = '45';
        _logMessage('Broker', '📊 Adjusted keep-alive to 45 seconds for EMQX', isIncoming: false);
      }
    }
  }
  
  // HiveMQ-specific settings
  else if (host.contains('hivemq')) {
    _logMessage('Broker', '🎯 Applying HiveMQ-specific settings', isIncoming: false);
    
    // HiveMQ Cloud settings
    if (_enableWillMessage) {
      final currentKeepAlive = int.tryParse(keepAliveCtrl.text) ?? 60;
      if (currentKeepAlive > 25) {
        keepAliveCtrl.text = '25';
        _logMessage('Broker', '📊 Adjusted keep-alive to 25 seconds for HiveMQ', isIncoming: false);
      }
    }
  }
}










  // FIXED CONNECT METHOD WITH WILL MESSAGE FIXES
  Future<void> _connect() async {
    if (_connectionState == ConnectionState.connected || 
        _connectionState == ConnectionState.connecting) {
      _logMessage('Connection', 'Already connected or connecting', isIncoming: false);
      return;
    }

    _cancelAutoReconnect();
    setState(() => _connectionState = ConnectionState.connecting);

    final raw = urlCtrl.text.trim();
    _logMessage('Connection', 'Connecting to: $raw', isIncoming: false);

    try {
      // Parse the URI
      Uri uri;
      try {
        uri = Uri.parse(raw);
      } catch (e) {
        _logMessage('Connection', '❌ Invalid URL format: $e', isIncoming: false);
        setState(() => _connectionState = ConnectionState.error);
        return;
      }

      final host = uri.host;
      int port = uri.port;
      final scheme = uri.scheme;
      
      if (host.isEmpty) {
        _logMessage('Connection', '❌ No host specified in URL', isIncoming: false);
        setState(() => _connectionState = ConnectionState.error);
        return;
      }

      // Detect protocol types
      final useWebSocket = scheme.startsWith('ws');
      final useSSL = scheme.startsWith('ssl') || scheme.startsWith('wss') || _enableTLS;
      
      // Set default ports if not specified
      if (port == 0) {
        if (useWebSocket) {
          port = useSSL ? 443 : 80;
          _logMessage('Connection', 'Using default WebSocket port: $port', isIncoming: false);
        } else {
          port = useSSL ? 8883 : 1883;
          _logMessage('Connection', 'Using default MQTT port: $port', isIncoming: false);
        }
      }
      
      _logMessage('Connection', 
          'Parsed: Host=$host, Port=$port, Scheme=$scheme, WebSocket=$useWebSocket, SSL=$useSSL', 
          isIncoming: false);

      // Validate Will configuration before connecting
      if (_enableWillMessage && !_validateWillConfiguration()) {
        _logMessage('Connection', '❌ Invalid Will configuration, aborting connection', isIncoming: false);
        setState(() => _connectionState = ConnectionState.error);
        return;
      }

      // Generate a unique client ID if not provided
      String clientId = clientIdCtrl.text.trim();
      if (clientId.isEmpty) {
        clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
        clientIdCtrl.text = clientId;
        _logMessage('Connection', 'Generated Client ID: $clientId', isIncoming: false);
      }

      // Create client with host and port
      final client = MqttServerClient.withPort(host, clientId, port);
      
      // Configure logging for debugging
      client.logging(on: true); // Set to true for debugging
      
      // Apply broker-specific settings
      _applyBrokerSpecificSettings(client, raw);
      
      // Configure SSL if needed
      if (useSSL) {
        client.secure = true;
        client.securityContext = SecurityContext.defaultContext;
        client.onBadCertificate = (dynamic cert) {
          _logMessage('Security', '🔓 Accepting certificate', isIncoming: false);
          return _allowSelfSigned;
        };
        _logMessage('Security', '🔐 SSL/TLS Enabled', isIncoming: false);
      }
      
      // Configure WebSocket
      if (useWebSocket) {
        client.useWebSocket = true;
        client.websocketProtocols = ['mqtt', 'mqttv3.1', 'mqttv3.1.1'];
        _logMessage('Connection', '🌐 WebSocket Enabled', isIncoming: false);
      }

      client.keepAlivePeriod = int.tryParse(keepAliveCtrl.text) ?? 60;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnectedWithReconnect;
      client.onSubscribed = _onSubscribed;
      client.pongCallback = _onPong;

      _setupAutoReconnect();

      // Create base connection message
      var connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId);

      // Set Will message FIRST if enabled - CRITICAL FIX
      if (_enableWillMessage && willTopicCtrl.text.trim().isNotEmpty) {
        final willTopic = willTopicCtrl.text.trim();
        final willPayload = willPayloadCtrl.text.trim();
        
        connMessage = connMessage
            .withWillTopic(willTopic)
            .withWillMessage(willPayload)
            .withWillQos(_willQos);
        
        if (_willRetain) {
          connMessage = connMessage.withWillRetain();
        }
        
        _logMessage('Will Config', 
            '⚰️ Will Message Configured:\n'
            '📝 Topic: $willTopic\n'
            '📦 Payload: $willPayload\n'
            '⚡ QoS: ${_willQos.index}\n'
            '💾 Retain Flag: $_willRetain',
            isIncoming: false);
        
        // For Mosquitto brokers, force clean session to false when Will is enabled
        if (host.contains('mosquitto')) {
          _cleanSession = false;
          _logMessage('Broker', '⚠️ Mosquitto: Auto-setting Clean Session = FALSE for Will messages', isIncoming: false);
        }
      }

      // Set clean session AFTER Will message - CRITICAL FIX
      if (_cleanSession) {
        connMessage = connMessage.startClean();
        _logMessage('Connection', '🧹 Clean Session: TRUE', isIncoming: false);
      } else {
        _logMessage('Connection', '📚 Clean Session: FALSE (Broker will remember subscriptions)', isIncoming: false);
      }

      // Set authentication if enabled
      if (_enableAuth && usernameCtrl.text.trim().isNotEmpty) {
        final username = usernameCtrl.text.trim();
        final password = passwordCtrl.text.trim();
        connMessage = connMessage.authenticateAs(username, password);
        _logMessage('Security', '🔐 Auth Enabled for user: $username', isIncoming: false);
      }

      client.connectionMessage = connMessage;

      _logMessage('Connection', 'Attempting connection...', isIncoming: false);
      
      final connResult = await client.connect();
      
      if (connResult?.state == MqttConnectionState.connected) {
        _client = client;
        _setupMessageListener();
        _reconnectAttempts = 0;
        _logMessage('Connection', '✅ Connected Successfully!', isIncoming: false);
        
        // Debug Will message configuration
        if (_enableWillMessage) {
          _logMessage('Will Debug', 
              'Will Configuration Connected:\n'
              'Topic: ${willTopicCtrl.text.trim()}\n'
              'Payload: ${willPayloadCtrl.text.trim()}\n'
              'QoS: ${_willQos.index}\n'
              'Retain: $_willRetain\n'
              'Clean Session: $_cleanSession',
              isIncoming: false);
        }
        
        setState(() => _connectionState = ConnectionState.connected);
        _startUptimeTracker();
        _startKeepAlive();
        _startConnectionHealthCheck();
        
        // Subscribe to Will topic automatically if enabled - IMPORTANT
        if (_enableWillMessage && willTopicCtrl.text.trim().isNotEmpty) {
          final willTopic = willTopicCtrl.text.trim();
          try {
            client.subscribe(willTopic, MqttQos.atLeastOnce);
            _logMessage('Will', '👂 Auto-subscribed to Will topic: $willTopic', isIncoming: false);
            
            // Add to subscriptions list
            if (!_subscriptions.any((sub) => sub.topic == willTopic)) {
              setState(() {
                _subscriptions.add(Subscription(topic: willTopic, qos: MqttQos.atLeastOnce));
              });
            }
          } catch (e) {
            _logMessage('Will', '❌ Failed to subscribe to Will topic: $e', isIncoming: false);
          }
        }
      } else {
        _logMessage('Connection', '❌ Connection Failed: ${connResult?.state}', isIncoming: false);
        _logMessage('Connection', '💡 Check broker URL, port, and network connectivity', isIncoming: false);
        setState(() => _connectionState = ConnectionState.error);
        client.disconnect();
        
        // Provide helpful error messages based on connection type
        if (useWebSocket) {
          _logMessage('Connection', 
              '💡 WebSocket Tips:\n'
              '1. Try port 443 for wss:// or 80 for ws://\n'
              '2. Ensure broker supports MQTT over WebSocket\n'
              '3. Test with public broker: wss://test.mosquitto.org:8081', 
              isIncoming: false);
        }
      }

    } on SocketException catch (e) {
      _logMessage('Connection', '❌ Network error: ${e.message}', isIncoming: false);
      _logMessage('Connection', '💡 Check internet connection and firewall settings', isIncoming: false);
      setState(() => _connectionState = ConnectionState.error);
    } on HandshakeException catch (e) {
      _logMessage('Connection', '❌ SSL/TLS handshake failed: ${e.message}', isIncoming: false);
      _logMessage('Connection', '💡 Try disabling SSL or enabling "Allow Self-Signed"', isIncoming: false);
      setState(() => _connectionState = ConnectionState.error);
    } on TimeoutException {
      _logMessage('Connection', '❌ Connection timeout (default timeout reached)', isIncoming: false);
      _logMessage('Connection', '💡 Broker may be offline or URL/port is incorrect', isIncoming: false);
      setState(() => _connectionState = ConnectionState.error);
    } on FormatException catch (e) {
      _logMessage('Connection', '❌ URL format error: $e', isIncoming: false);
      _logMessage('Connection', '💡 Use format: protocol://host:port (e.g., tcp://test.mosquitto.org:1883)', isIncoming: false);
      setState(() => _connectionState = ConnectionState.error);
    } catch (e) {
      _logMessage('Connection', '❌ Unexpected error: $e', isIncoming: false);
      _logMessage('Connection', '💡 Try a different broker or check app permissions', isIncoming: false);
      setState(() => _connectionState = ConnectionState.error);
    }
  }

  // RESTORE SUBSCRIPTIONS WITH DELAY
  void _restoreSubscriptionsWithDelay() {
    if (_client == null || _connectionState != ConnectionState.connected) {
      return;
    }
    
    if (_subscriptions.isEmpty) {
      _logMessage('System', 'ℹ️ No active subscriptions to restore', isIncoming: false);
      return;
    }
    
    _logMessage('System', '🔄 Restoring ${_subscriptions.length} subscription(s) in 1 second...', isIncoming: false);
    
    // Wait 1 second to ensure connection is fully established
    Timer(const Duration(seconds: 1), () {
      _resubscribeToAllTopics();
    });
  }

  // RESUBSCRIBE TO ALL TOPICS
  void _resubscribeToAllTopics() {
    if (_client == null || _connectionState != ConnectionState.connected) {
      return;
    }
    
    if (_subscriptions.isEmpty) {
      _logMessage('System', 'ℹ️ No active subscriptions to restore', isIncoming: false);
      return;
    }
    
    _logMessage('System', '🔄 Restoring ${_subscriptions.length} subscription(s)', isIncoming: false);
    
    for (final subscription in _subscriptions) {
      try {
        _client!.subscribe(subscription.topic, subscription.qos);
        _logMessage('Subscription', 
            '✅ Re-subscribed: ${subscription.topic} (QoS ${subscription.qos.index})', 
            isIncoming: false);
      } catch (e) {
        _logMessage('Subscription', 
            '⚠️ Failed to re-subscribe to ${subscription.topic}: $e', 
            isIncoming: false);
      }
    }
  }

  void _onConnected() {
    _logMessage('Connection', '✅ onConnected callback triggered', isIncoming: false);
    
    setState(() {
      _connectionState = ConnectionState.connected;
      _reconnectAttempts = 0;
      _missedPings = 0;
    });
    
    _startUptimeTracker();
    _startKeepAlive();
    _startConnectionHealthCheck();
    
    // CRITICAL: Subscribe to Will topic immediately after connection
    if (_enableWillMessage && willTopicCtrl.text.trim().isNotEmpty && _client != null) {
      final willTopic = willTopicCtrl.text.trim();
      try {
        // Ensure we're subscribed to our own Will topic
        if (!_subscriptions.any((sub) => sub.topic == willTopic)) {
          _client!.subscribe(willTopic, MqttQos.atLeastOnce);
          setState(() {
            _subscriptions.add(Subscription(topic: willTopic, qos: MqttQos.atLeastOnce));
          });
          _logMessage('Will', '👂 Connected: Subscribed to own Will topic: $willTopic', isIncoming: false);
        }
      } catch (e) {
        _logMessage('Will', '❌ Failed to subscribe to Will topic on connected: $e', isIncoming: false);
      }
    }
    
    // CRITICAL: Restore subscriptions after reconnection
    if (_shouldRestoreSubscriptions) {
      _shouldRestoreSubscriptions = false;
      _restoreSubscriptionsWithDelay();
    }
  }

  void _onDisconnected() {
    _logMessage('Connection', '🔌 onDisconnected callback triggered', isIncoming: false);
    setState(() => _connectionState = ConnectionState.disconnected);
    _stopUptimeTracker();
    _stopKeepAlive();
  }

  void _onSubscribed(String topic) {
    _logMessage('Subscription', '✅ Subscribed to: $topic', isIncoming: false);
  }

  void _onPong() {
    _missedPings = 0;
    _logMessage('Connection', '💓 Ping response received - connection healthy', isIncoming: false);
  }

  void _setupMessageListener() {
    _updatesSub?.cancel();
    _updatesSub = _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? events) {
      if (events == null) return;
      
      for (final event in events) {
        try {
          final topic = event.topic;
          final message = event.payload;
          
          if (message is MqttPublishMessage) {
            final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
            final qosIndex = message.payload.header?.qos.index ?? 0;
            _logMessage(topic, 'RX: $payload', isIncoming: true, qos: qosIndex);
          }
        } catch (e) {
          _logMessage('Error', 'Failed to process message: $e', isIncoming: true);
        }
      }
    }, onError: (error) {
      _logMessage('Receiver', '❌ Stream error: $error', isIncoming: true);
    });
  }

  // PROFILE MANAGEMENT METHODS
  void _loadProfile(ConnectionProfile profile) {
    setState(() {
      _currentProfile = profile;
      
      urlCtrl.text = profile.brokerUrl;
      clientIdCtrl.text = profile.clientId.isEmpty 
          ? 'flutter_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(4)}'
          : profile.clientId;
      usernameCtrl.text = profile.username;
      passwordCtrl.text = profile.password;
      _enableAuth = profile.enableAuth;
      _cleanSession = profile.cleanSession;
      keepAliveCtrl.text = profile.keepAlive.toString();
      _qos = MqttQos.values[profile.defaultQos.clamp(0, 2)];
      _enableWillMessage = profile.enableWill;
      willTopicCtrl.text = profile.willTopic;
      willPayloadCtrl.text = profile.willPayload;
      _willQos = MqttQos.values[profile.willQos.clamp(0, 2)];
      _willRetain = profile.willRetain;
      _retainMessage = profile.willRetain;
      
      _enableTLS = profile.brokerUrl.startsWith('ssl://') || profile.brokerUrl.startsWith('wss://');
    });
    
    _logMessage('Profiles', '✅ Loaded profile: ${profile.name}', isIncoming: false);
  }

  Future<void> _saveCurrentAsProfile() async {
    String suggestName() {
      final url = urlCtrl.text.trim();
      if (url.contains('mosquitto')) return 'Mosquitto Server';
      if (url.contains('localhost')) return 'Local Server';
      if (url.contains('hivemq')) return 'HiveMQ';
      if (url.contains('emqx')) return 'EMQX';
      
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) {
        return '${uri.host} Server';
      }
      
      return 'Connection ${_profiles.length + 1}';
    }

    String brokerUrl = urlCtrl.text.trim();
    if (_enableTLS) {
      if (brokerUrl.startsWith('tcp://')) {
        brokerUrl = brokerUrl.replaceFirst('tcp://', 'ssl://');
      } else if (brokerUrl.startsWith('ws://')) {
        brokerUrl = brokerUrl.replaceFirst('ws://', 'wss://');
      } else if (!brokerUrl.startsWith('ssl://') && !brokerUrl.startsWith('wss://')) {
        brokerUrl = 'ssl://$brokerUrl';
      }
    }

    final profile = ConnectionProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: suggestName(),
      brokerUrl: brokerUrl,
      clientId: clientIdCtrl.text.trim(),
      username: usernameCtrl.text.trim(),
      password: passwordCtrl.text.trim(),
      enableAuth: _enableAuth,
      cleanSession: _cleanSession,
      keepAlive: int.tryParse(keepAliveCtrl.text) ?? 60,
      defaultQos: _qos.index,
      enableWill: _enableWillMessage,
      willTopic: willTopicCtrl.text.trim(),
      willPayload: willPayloadCtrl.text.trim(),
      willQos: _willQos.index,
      willRetain: _willRetain,
      createdAt: DateTime.now(),
    );
    
    try {
      await _profileHelper.insertProfile(profile);
      final profiles = await _profileHelper.getAllProfiles();
      setState(() {
        _profiles = profiles;
        _currentProfile = profile;
      });
      _logMessage('Profiles', '✅ Profile saved: ${profile.name}', isIncoming: false);
    } catch (e) {
      _logMessage('Profiles', '❌ Error saving profile: $e', isIncoming: false);
    }
  }

  Future<void> _updateCurrentProfile() async {
    if (_currentProfile == null) return;
    
    try {
      final updatedProfile = ConnectionProfile(
        id: _currentProfile!.id,
        name: _currentProfile!.name,
        brokerUrl: urlCtrl.text.trim(),
        clientId: clientIdCtrl.text.trim(),
        username: usernameCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
        enableAuth: _enableAuth,
        cleanSession: _cleanSession,
        keepAlive: int.tryParse(keepAliveCtrl.text) ?? 60,
        defaultQos: _qos.index,
        enableWill: _enableWillMessage,
        willTopic: willTopicCtrl.text.trim(),
        willPayload: willPayloadCtrl.text.trim(),
        willQos: _willQos.index,
        willRetain: _willRetain,
        createdAt: _currentProfile!.createdAt,
      );
      
      await _profileHelper.updateProfile(updatedProfile);
      final profiles = await _profileHelper.getAllProfiles();
      setState(() {
        _profiles = profiles;
        _currentProfile = updatedProfile;
      });
      _logMessage('Profiles', '✅ Profile updated: ${updatedProfile.name}', isIncoming: false);
    } catch (e) {
      _logMessage('Profiles', '❌ Error updating profile: $e', isIncoming: false);
    }
  }

  void _deleteProfile(ConnectionProfile profile) async {
    try {
      await _profileHelper.deleteProfile(profile.id);
      final profiles = await _profileHelper.getAllProfiles();
      setState(() {
        _profiles = profiles;
        if (_currentProfile?.id == profile.id) {
          _currentProfile = null;
        }
      });
      _logMessage('Profiles', '🗑️ Deleted profile: ${profile.name}', isIncoming: false);
    } catch (e) {
      _logMessage('Profiles', '❌ Error deleting profile: $e', isIncoming: false);
    }
  }

  void _disconnect() {
    _cancelAutoReconnect();
    _connectionHealthTimer?.cancel();
    _stopUptimeTracker();
    _stopKeepAlive();
    
    _client?.disconnect();
    
    // IMPORTANT: Don't clear subscriptions when disconnecting!
    // The subscriptions should remain in the list so they can be restored
    // Only clear them if user manually unsubscribes
    // if (_cleanSession) {
    //   setState(() {
    //     _subscriptions.clear();
    //   });
    //   _logMessage('System', 'Cleared local subscriptions (Clean Session)', isIncoming: false);
    // }
    
    setState(() => _connectionState = ConnectionState.disconnected);
    _logMessage('Connection', 'Disconnected properly', isIncoming: false);
    _logMessage('System', '📋 Subscriptions preserved for next connection', isIncoming: false);
  }

  // SUBSCRIBE METHOD
  void _subscribe() {
    final c = _client;
    if (_connectionState != ConnectionState.connected || c == null) {
      _logMessage('Subscription', 'Not connected to broker', isIncoming: false);
      return;
    }
    
    final topic = subTopicCtrl.text.trim();
    if (topic.isEmpty) return;

    if (!_isValidWildcardTopic(topic)) {
      _logMessage('Subscription', '❌ Invalid wildcard topic. Use + for single level and # for multi-level', isIncoming: false);
      return;
    }

    if (_subscriptions.any((sub) => sub.topic == topic)) {
      _logMessage('Subscription', 'Already subscribed to: $topic', isIncoming: false);
      return;
    }

    try {
      c.subscribe(topic, _qos);
      setState(() {
        _subscriptions.add(Subscription(topic: topic, qos: _qos));
      });
      
      if (topic.contains('+') || topic.contains('#')) {
        _logMessage('Subscription', '🎯 Wildcard subscription added: $topic (QoS ${_qos.index})', isIncoming: false);
      } else {
        _logMessage('Subscription', 'Subscribed to: $topic (QoS ${_qos.index})', isIncoming: false);
      }
      
      subTopicCtrl.clear();
    } catch (e) {
      _logMessage('Subscription', 'Subscribe error: $e', isIncoming: false);
    }
  }

  void _unsubscribe(String topic) {
    final c = _client;
    if (_connectionState != ConnectionState.connected || c == null) return;
    
    try {
      c.unsubscribe(topic);
      setState(() {
        _subscriptions.removeWhere((sub) => sub.topic == topic);
      });
      _logMessage('Subscription', 'Unsubscribed from: $topic', isIncoming: false);
    } catch (e) {
      _logMessage('Subscription', 'Unsubscribe error: $e', isIncoming: false);
    }
  }

  void _publish() {
    final c = _client;
    if (_connectionState != ConnectionState.connected || c == null) {
      _logMessage('Publish', 'Not connected to broker', isIncoming: false);
      return;
    }
    
    final topic = pubTopicCtrl.text.trim();
    final payload = payloadCtrl.text.trim();
    
    if (topic.isEmpty || payload.isEmpty) return;

    try {
      final builder = MqttClientPayloadBuilder()..addString(payload);
      c.publishMessage(topic, _qos, builder.payload!, retain: _retainMessage);
      
      _logMessage(topic, 'TX: $payload ${_retainMessage ? "🔒 [RETAINED]" : ""}', 
                  isIncoming: false, qos: _qos.index);
    } catch (e) {
      _logMessage('Publish', 'Publish error: $e', isIncoming: false);
    }
  }

  // BUILD CONNECTION STATS WIDGET
  Widget _buildConnectionStats() {
    final messagesReceived = _messages.where((m) => m.isIncoming).length;
    final messagesSent = _messages.where((m) => !m.isIncoming).length;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, size: 16),
                SizedBox(width: 8),
                Text(
                  'Connection Stats',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('📨 Messages Received: $messagesReceived', style: const TextStyle(fontSize: 12)),
            Text('📤 Messages Sent: $messagesSent', style: const TextStyle(fontSize: 12)),
            Text('🔔 Active Subscriptions: ${_subscriptions.length}', style: const TextStyle(fontSize: 12)),
            Text('🔄 Reconnect Attempts: $_reconnectAttempts/$_maxReconnectAttempts', style: const TextStyle(fontSize: 12)),
            if (_connectionState == ConnectionState.connected) 
              Text('⏱️ Uptime: ${_formatDuration(_connectionUptime)}', style: const TextStyle(fontSize: 12)),
            if (_enableWillMessage)
              const Text('⚰️ Will Message: Enabled', style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ),
      ),
    );
  }

  // GET CONNECTION STATE COLOR
  Color _getConnectionStateColor() {
    switch (_connectionState) {
      case ConnectionState.disconnected:
        return Colors.grey;
      case ConnectionState.connecting:
        return Colors.orange;
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.reconnecting:
        return Colors.orange;
      case ConnectionState.error:
        return Colors.red;
    }
  }

  // GET CONNECTION STATE TEXT
  String _getConnectionStateText() {
    switch (_connectionState) {
      case ConnectionState.disconnected:
        return 'DISCONNECTED';
      case ConnectionState.connecting:
        return 'CONNECTING...';
      case ConnectionState.connected:
        return 'CONNECTED';
      case ConnectionState.reconnecting:
        return 'RECONNECTING...';
      case ConnectionState.error:
        return 'ERROR';
    }
  }

  // URL DEBUG HELPER
  void _logConnectionDetails(String url) {
    try {
      final uri = Uri.parse(url);
      final useWebSocket = url.startsWith('ws://') || url.startsWith('wss://');
      final useSSL = url.startsWith('ssl://') || url.startsWith('wss://');
      
      _logMessage('Debug', 
          'URL Analysis:\n'
          '• Original: $url\n'
          '• Scheme: ${uri.scheme}\n'
          '• Host: ${uri.host}\n'
          '• Port: ${uri.port} (0 means default)\n'
          '• WebSocket: $useWebSocket\n'
          '• SSL: $useSSL\n'
          '• Path: ${uri.path}',
          isIncoming: false);
    } catch (e) {
      _logMessage('Debug', 'Failed to parse URL: $e', isIncoming: false);
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _connectionHealthTimer?.cancel();
    _uptimeTimer?.cancel();
    _keepAliveTimer?.cancel();
    _searchDebounce?.cancel();
    _updatesSub?.cancel();
    
    // IMPORTANT: Send proper disconnect on app close
    if (_client != null && _connectionState == ConnectionState.connected) {
      _client?.disconnect();
    }
    
    urlCtrl.dispose();
    clientIdCtrl.dispose();
    subTopicCtrl.dispose();
    pubTopicCtrl.dispose();
    payloadCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    keepAliveCtrl.dispose();
    willTopicCtrl.dispose();
    willPayloadCtrl.dispose();
    searchCtrl.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    final inputDecoration = InputDecoration(
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      fillColor: _isDarkMode ? Colors.grey[800] : Colors.white,
      filled: true,
    );

    return MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MQTT Mobile App'),
          backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportDatabase,
              tooltip: 'Export Database',
            ),
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearMessages,
              tooltip: 'Clear Messages',
            ),
            // Add reconnect button to app bar
            if (_connectionState == ConnectionState.error || _connectionState == ConnectionState.disconnected)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _forceReconnect,
                tooltip: 'Reconnect',
              ),
            // Add debug button to app bar
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                _logMessage('Debug', 
                    'Current Connection State:\n'
                    'State: $_connectionState\n'
                    'Will Enabled: $_enableWillMessage\n'
                    'Will Topic: ${willTopicCtrl.text}\n'
                    'Clean Session: $_cleanSession\n'
                    'Keep Alive: ${keepAliveCtrl.text}\n'
                    'Auto Reconnect: $_autoReconnect\n'
                    'Reconnect Attempts: $_reconnectAttempts\n'
                    'Active Subscriptions: ${_subscriptions.length}\n'
                    'Client ID: ${clientIdCtrl.text}',
                    isIncoming: false);
              },
              tooltip: 'Debug Connection',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getConnectionStateColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getConnectionStateColor()),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _connectionState == ConnectionState.connected 
                            ? Icons.wifi 
                            : Icons.wifi_off,
                        color: _getConnectionStateColor(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getConnectionStateText(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getConnectionStateColor(),
                          ),
                        ),
                      ),
                      if (_connectionState == ConnectionState.error || _connectionState == ConnectionState.disconnected)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _forceReconnect,
                          tooltip: 'Reconnect',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildConnectionStats(),
                
                const SizedBox(height: 16),
                
                // Quick Test Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'Quick Test',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Test with popular public brokers',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.play_arrow, size: 16),
                              label: const Text('Mosquitto TCP'),
                              backgroundColor: Colors.amber.shade100,
                              labelStyle: const TextStyle(color: Colors.amber),
                              onPressed: () {
                                urlCtrl.text = 'tcp://test.mosquitto.org:1883';
                                _enableTLS = false;
                                _logMessage('Test', 'Set to Mosquitto TCP broker', isIncoming: false);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.play_arrow, size: 16),
                              label: const Text('Mosquitto WS'),
                              backgroundColor: Colors.amber.shade100,
                              labelStyle: const TextStyle(color: Colors.amber),
                              onPressed: () {
                                urlCtrl.text = 'ws://test.mosquitto.org:8883';
                                _enableTLS = false;
                                _logMessage('Test', 'Set to Mosquitto WebSocket broker', isIncoming: false);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.play_arrow, size: 16),
                              label: const Text('EMQX TCP'),
                              backgroundColor: Colors.amber.shade100,
                              labelStyle: const TextStyle(color: Colors.amber),
                              onPressed: () {
                                urlCtrl.text = 'tcp://broker.emqx.io:1883';
                                _enableTLS = false;
                                _logMessage('Test', 'Set to EMQX TCP broker', isIncoming: false);
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.play_arrow, size: 16),
                              label: const Text('EMQX WS'),
                              backgroundColor: Colors.amber.shade100,
                              labelStyle: const TextStyle(color: Colors.amber),
                              onPressed: () {
                                urlCtrl.text = 'ws://broker.emqx.io:8883';
                                _enableTLS = false;
                                _logMessage('Test', 'Set to EMQX WebSocket broker', isIncoming: false);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                
                // Templates Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.content_copy, color: Colors.purple),
                            const SizedBox(width: 8),
                            const Text(
                              'Message Templates',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _showTemplates ? Icons.expand_less : Icons.expand_more,
                                color: Colors.purple,
                              ),
                              onPressed: () => setState(() => _showTemplates = !_showTemplates),
                              tooltip: _showTemplates ? 'Hide Templates' : 'Show Templates',
                            ),
                          ],
                        ),
                        if (_showTemplates) ...[
                          const SizedBox(height: 12),
                          if (_templates.isEmpty) 
                            const Text('No templates saved. Create your first one!'),
                          if (_templates.isNotEmpty) ...[
                            const Text(
                              'Quick Load:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _templates.map((template) => ActionChip(
                                avatar: _currentTemplate?.id == template.id 
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : const Icon(Icons.description, size: 16),
                                label: Text(template.name),
                                backgroundColor: _currentTemplate?.id == template.id 
                                    ? Colors.purple 
                                    : Colors.purple.shade100,
                                labelStyle: TextStyle(
                                  color: _currentTemplate?.id == template.id 
                                      ? Colors.white 
                                      : Colors.purple,
                                  fontWeight: FontWeight.w500,
                                ),
                                onPressed: () => _loadTemplate(template),
                              )).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saveCurrentAsTemplate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.save, size: 18),
                                  label: const Text('Save Current as Template'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_currentTemplate != null) ...[
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTemplate(_currentTemplate!),
                                  tooltip: 'Delete Current Template',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                
                // Profiles Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bookmark, color: Colors.purple),
                            const SizedBox(width: 8),
                            const Text(
                              'Connection Profiles',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _showProfiles ? Icons.expand_less : Icons.expand_more,
                                color: Colors.purple,
                              ),
                              onPressed: () => setState(() => _showProfiles = !_showProfiles),
                              tooltip: _showProfiles ? 'Hide Profiles' : 'Show Profiles',
                            ),
                          ],
                        ),
                        if (_showProfiles) ...[
                          const SizedBox(height: 12),
                          if (_profiles.isEmpty) 
                            const Text('No profiles saved. Create your first one!'),
                          if (_profiles.isNotEmpty) ...[
                            const Text(
                              'Quick Connect:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _profiles.map((profile) => GestureDetector(
                                onLongPress: () => _showRenameDialog(profile),
                                child: ActionChip(
                                  avatar: _currentProfile?.id == profile.id 
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : const Icon(Icons.play_arrow, size: 16),
                                  label: Text(profile.name),
                                  backgroundColor: _currentProfile?.id == profile.id 
                                      ? Colors.purple 
                                      : Colors.purple.shade100,
                                  labelStyle: TextStyle(
                                    color: _currentProfile?.id == profile.id 
                                        ? Colors.white 
                                      : Colors.purple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  onPressed: () => _loadProfile(profile),
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saveCurrentAsProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.save, size: 18),
                                  label: const Text('Save Current as Profile'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_currentProfile != null) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showRenameDialog(_currentProfile!),
                                  tooltip: 'Rename Current Profile',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _showDeleteDialog(_currentProfile!),
                                  tooltip: 'Delete Current Profile',
                                ),
                              ],
                            ],
                          ),
                          if (_currentProfile != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _updateCurrentProfile,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                ),
                                child: const Text('Update Current Profile with Current Settings'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Current: ${_currentProfile!.name}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                
                // Connection Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.link, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Broker Connection',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: urlCtrl,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Broker URL (tcp://, ws://, ssl://, wss://)',
                            hintText: 'e.g., tcp://test.mosquitto.org:1883',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.info, size: 18),
                              onPressed: () {
                                _logMessage('Tips', 
                                    'Common broker URLs:\n'
                                    '• tcp://test.mosquitto.org:1883\n'
                                    '• ws://test.mosquitto.org:8080\n'
                                    '• tcp://broker.emqx.io:1883\n'
                                    '• ws://broker.emqx.io:8083\n'
                                    '• ssl://broker.emqx.io:8883',
                                    isIncoming: false);
                              },
                              tooltip: 'Common broker examples',
                            ),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: clientIdCtrl,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Client ID',
                                  hintText: 'Leave empty for auto-generate',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                clientIdCtrl.text = 'flutter_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
                                _logMessage('System', 'Generated new Client ID', isIncoming: false);
                              },
                              tooltip: 'Generate new Client ID',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // SSL/TLS Settings
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Enable SSL/TLS'),
                                subtitle: const Text('Secure connection (ssl://, wss://)'),
                                value: _enableTLS,
                                onChanged: (value) => setState(() => _enableTLS = value ?? false),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            if (_enableTLS) ...[
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('Allow Self-Signed'),
                                  subtitle: const Text('Accept self-signed certificates'),
                                  value: _allowSelfSigned,
                                  onChanged: (value) => setState(() => _allowSelfSigned = value ?? true),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        // Auto-reconnect setting
                        CheckboxListTile(
                          title: const Text('Auto-reconnect'),
                          subtitle: const Text('Automatically reconnect if connection is lost'),
                          value: _autoReconnect,
                          onChanged: (value) => setState(() => _autoReconnect = value ?? true),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        
                        if (_reconnectAttempts > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _reconnectAttempts >= _maxReconnectAttempts 
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _reconnectAttempts >= _maxReconnectAttempts 
                                  ? Colors.red
                                  : Colors.orange,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _reconnectAttempts >= _maxReconnectAttempts 
                                      ? Icons.error
                                      : Icons.autorenew,
                                  color: _reconnectAttempts >= _maxReconnectAttempts 
                                      ? Colors.red
                                      : Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reconnect attempts: $_reconnectAttempts/$_maxReconnectAttempts',
                                  style: TextStyle(
                                    color: _reconnectAttempts >= _maxReconnectAttempts 
                                        ? Colors.red
                                        : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 400) {
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<MqttQos>(
                                      value: _qos,
                                      items: const [
                                        DropdownMenuItem(
                                          value: MqttQos.atMostOnce,
                                          child: Text('QoS 0 - At Most Once'),
                                        ),
                                        DropdownMenuItem(
                                          value: MqttQos.atLeastOnce,
                                          child: Text('QoS 1 - At Least Once'),
                                        ),
                                        DropdownMenuItem(
                                          value: MqttQos.exactlyOnce,
                                          child: Text('QoS 2 - Exactly Once'),
                                        ),
                                      ],
                                      onChanged: _connectionState == ConnectionState.connected ? null : (v) => setState(() => _qos = v ?? MqttQos.atMostOnce),
                                      decoration: inputDecoration.copyWith(labelText: 'Default QoS'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: ElevatedButton(
                                      onPressed: _connectionState == ConnectionState.connected ? _disconnect : _connect,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _connectionState == ConnectionState.connected ? Colors.red : Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        _connectionState == ConnectionState.connected ? 'DISCONNECT' : 'CONNECT',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  DropdownButtonFormField<MqttQos>(
                                    value: _qos,
                                    items: const [
                                      DropdownMenuItem(
                                        value: MqttQos.atMostOnce,
                                        child: Text('QoS 0 - At Most Once'),
                                      ),
                                      DropdownMenuItem(
                                        value: MqttQos.atLeastOnce,
                                        child: Text('QoS 1 - At Least Once'),
                                      ),
                                      DropdownMenuItem(
                                        value: MqttQos.exactlyOnce,
                                        child: Text('QoS 2 - Exactly Once'),
                                      ),
                                    ],
                                    onChanged: _connectionState == ConnectionState.connected ? null : (v) => setState(() => _qos = v ?? MqttQos.atMostOnce),
                                    decoration: inputDecoration.copyWith(labelText: 'Default QoS'),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _connectionState == ConnectionState.connected ? _disconnect : _connect,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _connectionState == ConnectionState.connected ? Colors.red : Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(_connectionState == ConnectionState.connected ? 'DISCONNECT' : 'CONNECT'),
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            _logConnectionDetails(urlCtrl.text.trim());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Debug URL', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Authentication Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security, color: Colors.purple),
                            SizedBox(width: 8),
                            Text(
                              'Authentication',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Username/Password for secure brokers',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: const Text('Enable Authentication'),
                          subtitle: const Text('Use username/password'),
                          value: _enableAuth,
                          onChanged: (value) => setState(() => _enableAuth = value ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_enableAuth) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: usernameCtrl,
                            decoration: inputDecoration.copyWith(
                              labelText: 'Username',
                              hintText: 'e.g., admin, user, iot_device',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: _hidePassword,
                            decoration: inputDecoration.copyWith(
                              labelText: 'Password', 
                              hintText: 'Enter your password',
                              suffixIcon: IconButton(
                                icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Connection Settings Section - UPDATED
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.settings, color: Colors.brown),
                            SizedBox(width: 8),
                            Text(
                              'Connection Settings',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Clean Session'),
                                subtitle: const Text('TRUE: Fresh start, FALSE: Remember subscriptions'),
                                value: _cleanSession,
                                onChanged: (value) => setState(() => _cleanSession = value ?? true),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: keepAliveCtrl,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Keep Alive (seconds)',
                                  hintText: 'e.g., 60',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '💡 Clean Session = TRUE: Fresh connection, no persistent session\n'
                            'Clean Session = FALSE: Broker remembers session (required for Will messages with some brokers)\n'
                            '⚠️ Note: For reliable Will messages, use Clean Session = FALSE',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Will Message Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.emergency, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Will Message',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Message published if client disconnects unexpectedly (app crash/swipe)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: const Text('Enable Will Message'),
                          subtitle: const Text('Send message if connection is lost abruptly'),
                          value: _enableWillMessage,
                          onChanged: (value) => setState(() => _enableWillMessage = value ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_enableWillMessage) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: willTopicCtrl,
                            decoration: inputDecoration.copyWith(
                              labelText: 'Will Topic',
                              hintText: 'e.g., device/status',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: willPayloadCtrl,
                            decoration: inputDecoration.copyWith(
                              labelText: 'Will Payload', 
                              hintText: 'e.g., offline, disconnected, error',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<MqttQos>(
                                  value: _willQos,
                                  items: const [
                                    DropdownMenuItem(
                                      value: MqttQos.atMostOnce, 
                                      child: Text('Will QoS 0'),
                                    ),
                                    DropdownMenuItem(
                                      value: MqttQos.atLeastOnce, 
                                      child: Text('Will QoS 1'),
                                    ),
                                    DropdownMenuItem(
                                      value: MqttQos.exactlyOnce, 
                                      child: Text('Will QoS 2'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _willQos = v ?? MqttQos.atMostOnce),
                                  decoration: inputDecoration.copyWith(labelText: 'Will QoS'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('Retain Will'),
                                  subtitle: const Text('Broker stores Will for new subscribers'),
                                  value: _willRetain,
                                  onChanged: (value) => setState(() => _willRetain = value ?? false),
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '💡 Will Message Tips:\n'
                              '1. Set Clean Session = FALSE for best results\n'
                              '2. Will triggers on app crash/swipe (no disconnect packet)\n'
                              '3. Test by swiping app away or force closing\n'
                              '4. Subscribe to Will topic to see the message',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _clearWillRetainedMessage,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.cleaning_services, size: 18),
                              label: const Text('CLEAR RETAINED WILL MESSAGE'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Subscription Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.rss_feed, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Subscribe to Topics',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use + for single-level and # for multi-level wildcards',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: subTopicCtrl,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Topic to subscribe (supports + and #)',
                                  hintText: 'e.g., sensor/+/temperature, home/#',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _subscribe,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'SUBSCRIBE',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (_subscriptions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Active Subscriptions:', style: TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                onPressed: _connectionState == ConnectionState.connected ? _resubscribeToAllTopics : null,
                                tooltip: 'Refresh All Subscriptions',
                              ),
                            ],
                          ),
                          const Divider(),
                          ..._subscriptions.map((sub) => ListTile(
                            title: Text(
                              sub.topic,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: sub.topic.contains('+') || sub.topic.contains('#') 
                                    ? Colors.orange 
                                    : null,
                                fontWeight: sub.topic.contains('+') || sub.topic.contains('#')
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            subtitle: Text('QoS: ${sub.qos.index} ${sub.topic.contains('+') || sub.topic.contains('#') ? '• Wildcard' : ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.unsubscribe, color: Colors.red),
                              onPressed: () => _unsubscribe(sub.topic),
                            ),
                            dense: true,
                          )),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '✅ Subscriptions will be preserved when you disconnect/reconnect',
                              style: TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Publish Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.send, color: Colors.purple),
                            SizedBox(width: 8),
                            Text(
                              'Publish Message',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: pubTopicCtrl,
                          decoration: inputDecoration.copyWith(labelText: 'Topic to publish'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: payloadCtrl,
                          decoration: inputDecoration.copyWith(labelText: 'Payload'),
                          minLines: 2,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          title: const Text('Retain Message'),
                          subtitle: const Text('Broker will store last message and deliver to new subscribers'),
                          value: _retainMessage,
                          onChanged: (value) => setState(() => _retainMessage = value ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _publish,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('PUBLISH'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _clearRetainedMessage,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('CLEAR RETAINED MESSAGE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Messages Log Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.message, color: Colors.teal),
                            const SizedBox(width: 8),
                            const Text(
                              'Message Log',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _showHistory ? Icons.live_tv : Icons.history,
                                color: _showHistory ? Colors.blue : Colors.grey,
                              ),
                              onPressed: _toggleHistoryView,
                              tooltip: _showHistory ? 'Switch to Live View' : 'View Full History',
                            ),
                            Text(
                              '${_filteredMessages.length} messages',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchCtrl,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Search messages...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                        
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '🔍 Showing ${_filteredMessages.length} messages matching "$_searchQuery"',
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                        
                        if (_showHistory) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '📚 Viewing Full History',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: _isDarkMode ? Colors.grey[800] : Colors.grey.shade50,
                          ),
                          child: _filteredMessages.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isNotEmpty 
                                            ? 'No messages found for "$_searchQuery"'
                                            : 'No messages yet\n\nConnect to broker and subscribe to topics',
                                        style: TextStyle(color: Colors.grey.shade600),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  itemCount: _filteredMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = _filteredMessages[index];
                                    return MessageItem(message: message);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Export Profiles & Templates Button
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          'Backup & Restore',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _exportProfilesAndTemplates,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                            ),
                            icon: const Icon(Icons.backup, size: 16),
                            label: const Text('EXPORT PROFILES & TEMPLATES'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Data model for MQTT messages
class Message {
  final int? id;
  final String topic;
  final String payload;
  final bool isIncoming;
  final DateTime timestamp;
  final int qos;

  Message({
    this.id,
    required this.topic,
    required this.payload,
    required this.isIncoming,
    required this.timestamp,
    required this.qos,
  });

  MessageHistory toMessageHistory() {
    return MessageHistory(
      topic: topic,
      payload: payload,
      isIncoming: isIncoming,
      qos: qos,
      timestamp: timestamp,
    );
  }
}

// Data model for topic subscriptions
class Subscription {
  final String topic;
  final MqttQos qos;

  Subscription({required this.topic, required this.qos});
}

// Widget to display individual messages with color coding
class MessageItem extends StatelessWidget {
  final Message message;

  const MessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isIncoming 
            ? (isDarkMode ? Colors.blue.shade900 : Colors.blue.shade50)
            : (isDarkMode ? Colors.green.shade900 : Colors.green.shade50),
        border: Border.all(
          color: message.isIncoming 
              ? (isDarkMode ? Colors.blue.shade700 : Colors.blue.shade200)
              : (isDarkMode ? Colors.green.shade700 : Colors.green.shade200),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                message.isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                size: 16,
                color: message.isIncoming 
                    ? (isDarkMode ? Colors.blue.shade300 : Colors.blue)
                    : (isDarkMode ? Colors.green.shade300 : Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.topic,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: message.isIncoming 
                        ? (isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800)
                        : (isDarkMode ? Colors.green.shade200 : Colors.green.shade800),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'QoS: ${message.qos}',
                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
              const SizedBox(width: 8),
              Text(
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}:${message.timestamp.second.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            message.payload,
            style: TextStyle(
              fontFamily: 'monospace', 
              fontSize: 13, 
              color: isDarkMode ? Colors.white : Colors.black87
            )
          ),
        ],
      ),
    );
  }
}
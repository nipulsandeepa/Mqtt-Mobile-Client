import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class MessageHistory {
  final int? id;
  final String topic;
  final String payload;
  final bool isIncoming;
  final int qos;
  final DateTime timestamp;

  MessageHistory({
    this.id,
    required this.topic,
    required this.payload,
    required this.isIncoming,
    required this.qos,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic': topic,
      'payload': payload,
      'isIncoming': isIncoming ? 1 : 0,
      'qos': qos,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory MessageHistory.fromMap(Map<String, dynamic> map) {
    return MessageHistory(
      id: map['id'],
      topic: map['topic'],
      payload: map['payload'],
      isIncoming: map['isIncoming'] == 1,
      qos: map['qos'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mqtt_messages.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT NOT NULL,
        payload TEXT NOT NULL,
        isIncoming INTEGER NOT NULL,
        qos INTEGER NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    
    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_topic ON messages(topic)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_timestamp ON messages(timestamp)
    ''');
  }

  // Insert a new message
  Future<int> insertMessage(MessageHistory message) async {
    final db = await database;
    return await db.insert('messages', message.toMap());
  }

  // Get all messages, newest first
  Future<List<MessageHistory>> getAllMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => MessageHistory.fromMap(maps[i]));
  }

  // Get messages by topic
  Future<List<MessageHistory>> getMessagesByTopic(String topic) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'topic = ?',
      whereArgs: [topic],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => MessageHistory.fromMap(maps[i]));
  }

  // Clear all messages
  Future<void> clearAllMessages() async {
    final db = await database;
    await db.delete('messages');
  }

  // Clear messages by topic
  Future<void> clearMessagesByTopic(String topic) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'topic = ?',
      whereArgs: [topic],
    );
  }

  // Get message count
  Future<int> getMessageCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM messages')
    ) ?? 0;
  }


  
}
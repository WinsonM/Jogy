import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'jogy_messages.db');

    return await openDatabase(
      path,
      version: 4, // Upgrade version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        content TEXT,
        isMe INTEGER, -- 1 for true, 0 for false
        timestamp INTEGER,
        title TEXT, -- For link previews
        subtitle TEXT, -- For link previews
        fileName TEXT, -- For file messages
        fileSize INTEGER -- For file messages
      )
    ''');

    await _createChatSessionsTable(db);
    await _createPostDraftsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createChatSessionsTable(db);
    }
    if (oldVersion < 3) {
      await _createPostDraftsTable(db);
    }
    if (oldVersion < 4) {
      // Add location columns to post_drafts
      await db.execute('ALTER TABLE post_drafts ADD COLUMN location_lat REAL');
      await db.execute('ALTER TABLE post_drafts ADD COLUMN location_lng REAL');
      await db.execute(
        'ALTER TABLE post_drafts ADD COLUMN location_place_name TEXT',
      );
      await db.execute(
        'ALTER TABLE post_drafts ADD COLUMN location_address TEXT',
      );
    }
  }

  Future<void> _createChatSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE chat_sessions(
        chat_id TEXT PRIMARY KEY,
        scroll_offset REAL,
        last_updated INTEGER
      )
    ''');
  }

  Future<void> _createPostDraftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE post_drafts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        image_paths TEXT, -- JSON encoded list of strings
        type TEXT,
        type TEXT,
        timestamp INTEGER,
        location_lat REAL,
        location_lng REAL,
        location_place_name TEXT,
        location_address TEXT
      )
    ''');
  }

  // Insert a message
  Future<int> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    // Adapt logic: boolean to int for SQLite
    final Map<String, dynamic> dbMessage = Map.from(message);
    if (dbMessage.containsKey('isMe')) {
      dbMessage['isMe'] = (dbMessage['isMe'] == true) ? 1 : 0;
    }
    // Add timestamp if not present
    if (!dbMessage.containsKey('timestamp')) {
      dbMessage['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    }

    return await db.insert('messages', dbMessage);
  }

  // Get messages (paged)
  // Reversed: true means we get latest messages first (ORDER BY id DESC)
  Future<List<Map<String, dynamic>>> getMessages({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      orderBy: 'timestamp DESC, id DESC', // Latest first
      limit: limit,
      offset: offset,
    );

    // Convert int back to boolean
    return maps.map((map) {
      final m = Map<String, dynamic>.from(map);
      m['isMe'] = (m['isMe'] == 1);
      return m;
    }).toList();
  }

  // Save scroll offset for a chat
  Future<void> saveScrollOffset(String chatId, double offset) async {
    final db = await database;
    await db.insert('chat_sessions', {
      'chat_id': chatId,
      'scroll_offset': offset,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Get scroll offset for a chat
  Future<double?> getScrollOffset(String chatId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );

    if (maps.isNotEmpty) {
      return maps.first['scroll_offset'] as double?;
    }
    return null;
  }

  // Save Draft
  Future<void> saveDraft(Map<String, dynamic> draft) async {
    final db = await database;
    // Clean up old drafts (assuming single draft for now, or just clear table)
    // To keep it simple, we delete all and insert new. User implies "the" draft.
    await deleteDraft();

    await db.insert('post_drafts', {
      'title': draft['title'],
      'content': draft['content'],
      'image_paths': draft['image_paths'], // Should be JSON string
      'type': draft['type'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location_lat': draft['location_lat'],
      'location_lng': draft['location_lng'],
      'location_place_name': draft['location_place_name'],
      'location_address': draft['location_address'],
    });
  }

  // Get Draft
  Future<Map<String, dynamic>?> getDraft() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'post_drafts',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Delete Draft
  Future<void> deleteDraft() async {
    final db = await database;
    await db.delete('post_drafts');
  }

  // Delete DB (for debug/reset)
  Future<void> deleteDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'jogy_messages.db');
    await deleteDatabase(path);
    _database = null;
  }
}

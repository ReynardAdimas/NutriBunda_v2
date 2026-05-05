import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// DatabaseHelper - SQLite local database service
/// Implements offline-first storage with sync tracking
/// Requirements: 3.3, 3.4, 7.4 - Local SQLite database for offline functionality
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nutribunda.db');
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // dinaikkan dari 1 → 3 (v2: food price, v3: baby fields)
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        email TEXT NOT NULL,
        full_name TEXT NOT NULL,
        weight REAL,
        height REAL,
        age INTEGER,
        is_breastfeeding INTEGER DEFAULT 0,
        activity_level TEXT DEFAULT 'sedentary',
        profile_image_url TEXT,
        timezone TEXT DEFAULT 'WIB',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced',
        baby_birth_date TEXT,
        baby_weight_kg REAL
      )
    ''');

    // Foods table
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        calories_per_100g REAL NOT NULL,
        protein_per_100g REAL NOT NULL,
        carbs_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL,
        estimated_price_per_100g REAL,  -- BARU (nullable)
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
        )   
    ''');

    // Create index for food search
    await db.execute('''
      CREATE INDEX idx_foods_name ON foods(name)
    ''');

    await db.execute('''
      CREATE INDEX idx_foods_category ON foods(category)
    ''');

    // Recipes table
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        name TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        instructions TEXT NOT NULL,
        nutrition_info TEXT,
        category TEXT DEFAULT 'mpasi',
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Diary entries table
    await db.execute('''
      CREATE TABLE diary_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        user_id INTEGER NOT NULL,
        profile_type TEXT NOT NULL,
        food_id INTEGER,
        custom_food_name TEXT,
        serving_size REAL NOT NULL,
        meal_time TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        entry_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT DEFAULT 'pending',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (food_id) REFERENCES foods(id)
      )
    ''');

    // Create indexes for diary entries
    await db.execute('''
      CREATE INDEX idx_diary_user_date ON diary_entries(user_id, entry_date)
    ''');

    await db.execute('''
      CREATE INDEX idx_diary_profile_type ON diary_entries(profile_type)
    ''');

    await db.execute('''
      CREATE INDEX idx_diary_sync_status ON diary_entries(sync_status)
    ''');

    // Favorite recipes table
    await db.execute('''
      CREATE TABLE favorite_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        user_id INTEGER NOT NULL,
        recipe_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT DEFAULT 'pending',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        UNIQUE(user_id, recipe_id)
      )
    ''');

    // Quiz questions table
    await db.execute('''
      CREATE TABLE quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        question TEXT NOT NULL,
        option_a TEXT NOT NULL,
        option_b TEXT NOT NULL,
        option_c TEXT NOT NULL,
        option_d TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        explanation TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT UNIQUE,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Daily step table 
    await db.execute('''
      CREATE TABLE daily_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        calories_burned REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, date)
      )
      ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT UNIQUE NOT NULL,
        last_sync_at TEXT NOT NULL
      )
    '''); 
  }

  /// Upgrade database schema
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: tambah kolom harga makanan
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE foods ADD COLUMN estimated_price_per_100g REAL',
      );
    }
    // v2 → v3: tambah kolom data bayi di tabel users
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN baby_birth_date TEXT',
      );
      await db.execute(
        'ALTER TABLE users ADD COLUMN baby_weight_kg REAL',
      );
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  /// Clear all data (for testing or logout)
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('users');
    await db.delete('foods');
    await db.delete('recipes');
    await db.delete('diary_entries');
    await db.delete('favorite_recipes');
    await db.delete('quiz_questions');
    await db.delete('notifications');
    await db.delete('sync_metadata');
  }

  /// Delete database file
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nutribunda.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
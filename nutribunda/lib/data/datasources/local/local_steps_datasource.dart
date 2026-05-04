import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class LocalStepsDatasource {
  final DatabaseHelper _dbHelper;

  LocalStepsDatasource(this._dbHelper);

  /// Simpan atau update data steps hari ini menggunakan UPSERT
  Future<void> saveOrUpdateDailySteps({
    required int userId,
    required String date, // format: 'YYYY-MM-DD'
    required int steps,
    required double caloriesBurned,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // INSERT OR REPLACE: jika (user_id, date) sudah ada → update, jika belum → insert
    await db.rawInsert('''
      INSERT INTO daily_steps (user_id, date, steps, calories_burned, created_at, updated_at, is_synced)
      VALUES (?, ?, ?, ?, ?, ?, 0)
      ON CONFLICT(user_id, date) DO UPDATE SET
        steps = excluded.steps,
        calories_burned = excluded.calories_burned,
        updated_at = excluded.updated_at,
        is_synced = 0
    ''', [userId, date, steps, caloriesBurned, now, now]);
  }

  /// Ambil data steps untuk tanggal tertentu
  Future<Map<String, dynamic>?> getDailySteps({
    required int userId,
    required String date,
  }) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'daily_steps',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Ambil semua data steps yang belum disync ke backend
  Future<List<Map<String, dynamic>>> getUnsyncedSteps(int userId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'daily_steps',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
  }

  /// Tandai record sebagai sudah disync
  Future<void> markAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'daily_steps',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
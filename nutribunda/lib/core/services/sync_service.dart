import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/local/local_diary_datasource.dart';
import '../../data/models/local/local_diary_entry.dart';
import '../../data/models/sync_request.dart';
import '../../data/models/sync_response.dart';
import '../../data/models/diary_entry.dart';
import 'secure_storage_service.dart';
import 'http_client_service.dart';

/// Sync Service
/// Manages bidirectional synchronization between local SQLite and server
/// Requirements: 3.5, 4.1, 7.4 - Data synchronization with conflict resolution
class SyncService {
  final HttpClientService _httpClient;
  final LocalDiaryDataSource _localDiary;
  final SecureStorageService _storage;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Sync status callbacks
  final void Function(SyncStatus)? onSyncStatusChanged;
  final void Function(List<SyncConflict>)? onConflictsDetected;

  SyncService({
    required HttpClientService httpClient,
    required LocalDiaryDataSource localDiary,
    required SecureStorageService storage,
    Connectivity? connectivity,
    this.onSyncStatusChanged,
    this.onConflictsDetected,
  })  : _httpClient = httpClient,
        _localDiary = localDiary,
        _storage = storage,
        _connectivity = connectivity ?? Connectivity();

  /// Start background sync monitoring
  /// Automatically syncs when connectivity is restored
  void startBackgroundSync({Duration interval = const Duration(minutes: 15)}) {
    // Monitor connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
    );

    // Periodic sync timer
    _syncTimer = Timer.periodic(interval, (_) {
      syncDiaryEntries();
    });
  }

  /// Stop background sync monitoring
  void stopBackgroundSync() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    if (hasConnection && !_isSyncing) {
      // Connectivity restored - trigger sync
      syncDiaryEntries();
    }
  }

  /// Check if device has internet connectivity
  Future<bool> hasConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }

  /// Sync diary entries with server
  /// Returns true if sync was successful, false otherwise
  Future<bool> syncDiaryEntries() async {
    if (_isSyncing) {
      return false; 
    }

    if (!await hasConnectivity()) {
      onSyncStatusChanged?.call(SyncStatus.offline);
      return false;
    }

    _isSyncing = true;
    onSyncStatusChanged?.call(SyncStatus.syncing);

    try {
      // Get last sync time
      final lastSyncTime = await _storage.getLastSyncTime();

      // Get pending local changes
      final pendingEntries = await _localDiary.getPendingSyncEntries();
      final deletedEntries = pendingEntries.where((e) => e.deletedAt != null).toList();
      final modifiedEntries = pendingEntries.where((e) => e.deletedAt == null).toList();

      // Convert to sync format
      final syncEntries = modifiedEntries.map((entry) => SyncDiaryEntry(
        id: entry.serverId ?? _generateUuid(),
        profileType: entry.profileType,
        foodId: entry.foodId?.toString(),
        customFoodName: entry.customFoodName,
        servingSize: entry.servingSize,
        mealTime: entry.mealTime,
        calories: entry.calories,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
        entryDate: _formatDate(entry.entryDate),
        updatedAt: entry.updatedAt.toIso8601String(),
      )).toList();

      final deletedIds = deletedEntries
          .where((e) => e.serverId != null)
          .map((e) => e.serverId!)
          .toList();

      // Create sync request
      final request = SyncRequest(
        lastSyncTime: lastSyncTime,
        entries: syncEntries,
        deletedIds: deletedIds,
      );

      // Send sync request to server
      final response = await _httpClient.post(
        '/api/diary/sync',
        data: request.toJson(),
      );

      final syncResponse = SyncResponse.fromJson(response.data);

      // Apply server changes to local database
      await _applyServerChanges(syncResponse);

      // Handle conflicts
      if (syncResponse.conflicts.isNotEmpty) {
        onConflictsDetected?.call(syncResponse.conflicts);
        onSyncStatusChanged?.call(SyncStatus.conflicts);
        return false; // Sync incomplete due to conflicts
      }

      // Update last sync time
      await _storage.setLastSyncTime(DateTime.now().toIso8601String());

      // Mark synced entries as synced
      for (final entry in modifiedEntries) {
        if (entry.id != null) {
          await _localDiary.updateDiaryEntry(
            entry.copyWith(syncStatus: 'synced'),
          );
        }
      }

      // Remove hard-deleted entries
      for (final entry in deletedEntries) {
        if (entry.id != null) {
          await _localDiary.hardDeleteDiaryEntry(entry.id!);
        }
      }

      onSyncStatusChanged?.call(SyncStatus.synced);
      _isSyncing = false;
      return true;
    } catch (e) {
      // Sync error - mark entries as failed
      onSyncStatusChanged?.call(SyncStatus.failed);
      _isSyncing = false;

      // Mark failed entries
      final pendingEntries = await _localDiary.getPendingSyncEntries();
      for (final entry in pendingEntries) {
        if (entry.id != null) {
          await _localDiary.updateDiaryEntry(
            entry.copyWith(syncStatus: 'failed'),
          );
        }
      }

      return false;
    }
  }

  /// Apply server changes to local database
  Future<void> _applyServerChanges(SyncResponse response) async {
    // Apply new/updated entries from server
    for (final serverEntry in response.entries) {
      // Check if entry exists locally
      final existingEntries = await _localDiary.getPendingSyncEntries();
      final existing = existingEntries.firstWhere(
        (e) => e.serverId == serverEntry.id,
        orElse: () => LocalDiaryEntry(
          userId: 0, // Will be updated
          profileType: '',
          servingSize: 0,
          mealTime: '',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          entryDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existing.id != null) {
        // Update existing entry
        final updated = LocalDiaryEntry.fromDiaryEntry(
          serverEntry,
          existing.userId,
          existing.foodId,
        ).copyWith(id: existing.id);
        await _localDiary.updateDiaryEntry(updated);
      } else {
        // Insert new entry from server
        // Note: This requires user_id mapping which should be handled by the app
        // For now, we'll skip entries without local user mapping
        // TODO: Implement proper user ID mapping
      }
    }

    // Apply deletions from server
    for (final deletedId in response.deletedIds) {
      final existingEntries = await _localDiary.getPendingSyncEntries();
      final existing = existingEntries.firstWhere(
        (e) => e.serverId == deletedId,
        orElse: () => LocalDiaryEntry(
          userId: 0,
          profileType: '',
          servingSize: 0,
          mealTime: '',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          entryDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existing.id != null) {
        await _localDiary.hardDeleteDiaryEntry(existing.id!);
      }
    }
  }

  /// Resolve a sync conflict
  /// resolution: "use_client" or "use_server"
  Future<DiaryEntry?> resolveConflict({
    required String entryId,
    required String resolution,
    Map<String, dynamic>? clientEntry,
  }) async {
    try {
      final request = {
        'entry_id': entryId,
        'resolution': resolution,
        if (clientEntry != null) 'entry': clientEntry,
      };

      final response = await _httpClient.post(
        '/api/diary/resolve-conflict',
        data: request,
      );

      final resolvedEntry = DiaryEntry.fromJson(response.data);

      // Update local database with resolved entry
      final existingEntries = await _localDiary.getPendingSyncEntries();
      final existing = existingEntries.firstWhere(
        (e) => e.serverId == entryId,
        orElse: () => LocalDiaryEntry(
          userId: 0,
          profileType: '',
          servingSize: 0,
          mealTime: '',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          entryDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existing.id != null) {
        final updated = LocalDiaryEntry.fromDiaryEntry(
          resolvedEntry,
          existing.userId,
          existing.foodId,
        ).copyWith(id: existing.id);
        await _localDiary.updateDiaryEntry(updated);
      }

      return resolvedEntry;
    } catch (e) {
      // Conflict resolution error
      return null;
    }
  }

  /// Retry failed sync entries
  Future<void> retryFailedSync() async {
    final failedEntries = await _localDiary.getFailedSyncEntries();
    
    for (final entry in failedEntries) {
      if (entry.id != null) {
        await _localDiary.updateDiaryEntry(
          entry.copyWith(syncStatus: 'pending'),
        );
      }
    }

    await syncDiaryEntries();
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    final pendingEntries = await _localDiary.getPendingSyncEntries();
    final failedEntries = await _localDiary.getFailedSyncEntries();
    final lastSyncTime = await _storage.getLastSyncTime();

    return SyncStatistics(
      pendingCount: pendingEntries.length,
      failedCount: failedEntries.length,
      lastSyncTime: lastSyncTime != null ? DateTime.parse(lastSyncTime) : null,
    );
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Generate a UUID (simplified version)
  /// In production, use uuid package
  String _generateUuid() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundSync();
  }
}

/// Sync Status Enum
enum SyncStatus {
  idle,
  syncing,
  synced,
  failed,
  conflicts,
  offline,
}

/// Sync Statistics Model
class SyncStatistics {
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncTime;

  const SyncStatistics({
    required this.pendingCount,
    required this.failedCount,
    this.lastSyncTime,
  });
}

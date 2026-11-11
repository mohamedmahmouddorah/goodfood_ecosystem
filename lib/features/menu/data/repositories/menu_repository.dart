import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';

import '../models/meal_model.dart';
import '../services/meal_image_file_store.dart';
import '../services/meal_image_storage_service.dart';
import '../services/meal_local_cache.dart';
import '../services/menu_remote_service.dart';

class MenuFailure implements Exception {
  const MenuFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class MenuSyncEvent {
  const MenuSyncEvent({required this.mealId, required this.imageUploaded});

  final String mealId;
  final bool imageUploaded;
}

/// Reads menu data locally first and keeps admin mutations in a SQLite outbox
/// until Firestore and ImgBB have both accepted them.
class MenuRepository {
  static const _offlineSyncMessage =
      'No internet connection. The image and product are saved on this device. '
      'The image will upload automatically when internet returns, then the '
      'product and image link will sync to Firebase.';

  MenuRepository(
    this._service, {
    MealLocalCache? mealLocalCache,
    MealImageStorageService? imageStorage,
    MealImageFileStore? imageFileStore,
  }) : _cache = mealLocalCache,
       _imageStorage = imageStorage ?? ImgBbMealImageStorageService(),
       _imageFileStore = imageFileStore ?? MealImageFileStore();

  final MenuRemoteService _service;
  final MealLocalCache? _cache;
  final MealImageStorageService _imageStorage;
  final MealImageFileStore _imageFileStore;
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _syncRequested = false;
  Completer<void>? _syncIdle;
  String? _lastSyncError;
  final StreamController<MenuSyncEvent> _syncEvents =
      StreamController<MenuSyncEvent>.broadcast();
  final StreamController<void> _localChanges =
      StreamController<void>.broadcast();

  bool get hasPersistentOutbox => _cache is MealMutationOutbox;
  String? get syncErrorMessage => _lastSyncError;
  Stream<MenuSyncEvent> get syncEvents => _syncEvents.stream;
  Stream<void> get localChanges => _localChanges.stream;

  Future<List<MealModel>?> readMealsFromCache() async {
    final cached = await _readCacheSafely();
    return cached?.meals;
  }

  Future<List<MealModel>?> readAvailableMealsFromCache() async =>
      (await readMealsFromCache())
          ?.where((meal) => meal.isAvailable)
          .toList(growable: false);

  void startSync({Duration interval = const Duration(seconds: 20)}) {
    if (!hasPersistentOutbox || _syncTimer != null) return;
    unawaited(_cleanupOrphansAndSync());
    _syncTimer = Timer.periodic(interval, (_) {
      unawaited(syncPendingMutations());
    });
  }

  Future<void> _cleanupOrphansAndSync() async {
    try {
      final cached = await _readCacheSafely();
      if (cached != null) {
        final activePaths = {
          for (final meal in cached.meals)
            if (meal.localImagePath != null) meal.localImagePath!,
        };
        await _imageFileStore.deleteOrphans(activePaths);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not clean up local meal images: $error\n$stackTrace');
    }
    await syncPendingMutations();
  }

  Future<String> saveImageLocally(PickedMealImage image) async {
    try {
      return await _imageFileStore.save(
        bytes: image.bytes,
        fileName: image.fileName ?? 'meal.${image.extension}',
        extension: image.extension,
      );
    } on Exception catch (error, stackTrace) {
      debugPrint('Local meal image save failed: $error\n$stackTrace');
      throw const MenuFailure(
        'Could not save the image on this device. Check available storage.',
      );
    }
  }

  /// Stages an image replacement locally. The old remote URL remains valid
  /// until the new image has uploaded successfully.
  Future<void> stageMealImage(
    String id,
    String localImagePath, {
    required String fileName,
    MealModel? meal,
  }) async {
    final outbox = _outbox;
    if (outbox == null) {
      throw const MenuFailure('Local offline sync is not available.');
    }
    final current = await _cachedMeal(id) ?? meal;
    if (current == null) throw const MenuFailure('Meal not found locally.');
    await outbox.enqueueUpsert(
      current.copyWith(
        localImagePath: localImagePath,
        localImageName: fileName,
      ),
      isCreate: false,
    );
    if (current.localImagePath != null &&
        current.localImagePath != localImagePath) {
      await _deleteLocalImageSafely(current.localImagePath);
    }
    _localChanges.add(null);
  }

  /// Cached menu is emitted first so screens can render while offline.
  /// DebounceTime (300ms) is applied to avoid excessive stream emissions.
  Stream<RemoteMealsSnapshot> watchAvailableMeals() {
    return _watchAvailableMealsInternal().debounceTime(
      const Duration(milliseconds: 300),
    );
  }

  Stream<RemoteMealsSnapshot> _watchAvailableMealsInternal() async* {
    try {
      final cached = await _readCacheSafely();
      if (cached != null) {
        yield RemoteMealsSnapshot(
          meals: cached.meals
              .where((meal) => meal.isAvailable)
              .toList(growable: false),
          isFromCache: true,
          hasPendingWrites: false,
        );
      }
      await for (final snapshot in _service.watchAvailable()) {
        if (_shouldPersist(snapshot)) {
          await _writeCacheSafely(
            (cache) => cache.replaceAvailableMeals(snapshot.meals),
          );
        }
        final mergedMeals = await _overlayPendingMutations(snapshot.meals);
        yield RemoteMealsSnapshot(
          meals: mergedMeals.where((meal) => meal.isAvailable).toList(),
          isFromCache: snapshot.isFromCache,
          hasPendingWrites: snapshot.hasPendingWrites,
        );
      }
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  Stream<List<MealModel>> watchAllMeals() {
    return _watchAllMealsInternal().debounceTime(
      const Duration(milliseconds: 300),
    );
  }

  Stream<List<MealModel>> _watchAllMealsInternal() async* {
    try {
      final cached = await _readCacheSafely();
      if (cached != null) yield cached.meals;
      await for (final snapshot in _service.watchAll(includeHidden: true)) {
        if (_shouldPersist(snapshot)) {
          await _writeCacheSafely(
            (cache) => cache.replaceMeals(snapshot.meals),
          );
        }
        yield await _overlayPendingMutations(snapshot.meals);
      }
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  // Mutations are committed atomically to SQLite before any network attempt.
  Future<String> addMeal(MealModel meal) async {
    final id = meal.id.isEmpty ? _service.newMealId() : meal.id;
    final localMeal = meal.copyWith(id: id);
    final outbox = _outbox;
    if (outbox != null) {
      await outbox.enqueueUpsert(localMeal, isCreate: true);
      _localChanges.add(null);
      return id;
    }

    await _local((cache) => cache.upsertMeal(localMeal));
    try {
      await _guard(() => _service.add(localMeal));
      return id;
    } on MenuFailure {
      await _local((cache) => cache.removeMeal(id));
      rethrow;
    }
  }

  Future<void> updateMeal(MealModel meal) async {
    final outbox = _outbox;
    if (outbox != null) {
      final previous = await _cachedMeal(meal.id);
      final previousImagePath = previous?.localImagePath;
      await outbox.enqueueUpsert(meal, isCreate: false);
      if (previousImagePath != null &&
          previousImagePath != meal.localImagePath) {
        await _deleteLocalImageSafely(previousImagePath);
      }
      _localChanges.add(null);
      return;
    }

    final previous = await _cachedMeal(meal.id);
    await _local((cache) => cache.upsertMeal(meal));
    try {
      await _guard(() => _service.update(meal));
    } on MenuFailure {
      await _restore(meal.id, previous);
      rethrow;
    }
  }

  Future<void> updateMealImage(String id, String imageUrl) async {
    final previous = await _cachedMeal(id);
    if (previous == null) throw const MenuFailure('Meal not found locally.');
    final updated = previous.copyWith(
      imageUrl: imageUrl,
      clearLocalImagePath: true,
    );
    final outbox = _outbox;
    if (outbox != null) {
      await outbox.enqueueUpsert(updated, isCreate: false);
      await _deleteLocalImageSafely(previous.localImagePath);
      _localChanges.add(null);
      return;
    }

    await _local((cache) => cache.upsertMeal(updated));
    try {
      await _guard(() => _service.updateImageUrl(id, imageUrl));
    } on MenuFailure {
      await _restore(id, previous);
      rethrow;
    }
  }

  Future<void> setAvailability(String id, bool value, {MealModel? meal}) async {
    final previous = await _cachedMeal(id) ?? meal;
    final updated = previous?.copyWith(isAvailable: value);
    final outbox = _outbox;
    if (outbox != null && updated != null) {
      await outbox.enqueueUpsert(updated, isCreate: false);
      _localChanges.add(null);
      return;
    }

    if (updated != null) {
      await _local((cache) => cache.upsertMeal(updated));
    }
    try {
      await _guard(() => _service.setAvailability(id, value));
    } on MenuFailure {
      await _restore(id, previous);
      rethrow;
    }
  }

  Future<void> deleteMeal(String id, {MealModel? meal}) async {
    final outbox = _outbox;
    if (outbox != null) {
      final localImagePath = await outbox.enqueueDelete(id);
      await _deleteLocalImageSafely(localImagePath);
      _localChanges.add(null);
      return;
    }

    final previous = await _cachedMeal(id) ?? meal;
    await _local((cache) => cache.removeMeal(id));
    try {
      await _guard(() => _service.delete(id));
    } on MenuFailure {
      await _restore(id, previous);
      rethrow;
    }
  }

  /// Retries all persisted admin mutations in order. A failed operation stays
  /// in SQLite and is retried by the timer or at the next app launch.
  Future<bool> syncPendingMutations() async {
    final outbox = _outbox;
    final cache = _cache;
    if (outbox == null || cache == null) return true;
    if (_isSyncing) {
      _syncRequested = true;
      final idle = _syncIdle;
      if (idle != null) await idle.future;
      return syncPendingMutations();
    }
    _isSyncing = true;
    final idle = Completer<void>();
    _syncIdle = idle;
    _lastSyncError = null;
    try {
      do {
        _syncRequested = false;
        await _syncPendingMutationsBatch(outbox, cache);
      } while (_syncRequested && _lastSyncError == null);
      return _lastSyncError == null &&
          (await outbox.readPendingMutations()).isEmpty;
    } catch (error, stackTrace) {
      _lastSyncError = error.toString();
      debugPrint('Could not read the menu sync queue: $error\n$stackTrace');
      return false;
    } finally {
      _isSyncing = false;
      _syncIdle = null;
      idle.complete();
    }
  }

  Future<void> _syncPendingMutationsBatch(
    MealMutationOutbox outbox,
    MealLocalCache cache,
  ) async {
    try {
      final pending = await outbox.readPendingMutations();
      for (final mutation in pending) {
        if (!await outbox.isMutationCurrent(
          mutation.mealId,
          mutation.version,
        )) {
          continue;
        }
        try {
          var imageUploaded = false;
          if (mutation.type == MealMutationType.delete) {
            await _service.delete(mutation.mealId);
          } else {
            var meal = await cache.readMeal(mutation.mealId);
            if (meal == null) continue;
            final localImagePath = meal.localImagePath;
            if (localImagePath != null && localImagePath.isNotEmpty) {
              final imageFile = File(localImagePath);
              if (!await imageFile.exists()) {
                throw const FileSystemException(
                  'The pending meal image is missing from local storage.',
                );
              }
              final extension = p
                  .extension(localImagePath)
                  .replaceFirst('.', '');
              final imageUrl = await _imageStorage.upload(
                PickedMealImage(
                  bytes: await imageFile.readAsBytes(),
                  extension: extension,
                  fileName: meal.localImageName ?? p.basename(localImagePath),
                ),
              );
              final saved = await outbox.saveUploadedImageUrl(
                mutation.mealId,
                mutation.version,
                imageUrl,
              );
              if (!saved) continue;
              await _deleteLocalImageSafely(localImagePath);
              _localChanges.add(null);
              imageUploaded = true;
              meal = await cache.readMeal(mutation.mealId);
              if (meal == null) continue;
            }
            if (!await outbox.isMutationCurrent(
              mutation.mealId,
              mutation.version,
            )) {
              continue;
            }
            if (mutation.type == MealMutationType.create) {
              await _service.add(meal);
            } else {
              await _service.update(meal);
            }
          }
          await _service.waitForPendingWrites().timeout(
            const Duration(seconds: 12),
          );
          final completed = await outbox.completeMutation(
            mutation.mealId,
            mutation.version,
          );
          if (completed) {
            _syncEvents.add(
              MenuSyncEvent(
                mealId: mutation.mealId,
                imageUploaded: imageUploaded,
              ),
            );
          }
          _lastSyncError = null;
        } catch (error, stackTrace) {
          final message = _syncErrorMessage(error);
          if (_lastSyncError != message) {
            debugPrint(
              'Menu sync paused; changes remain in SQLite: $error\n$stackTrace',
            );
            _lastSyncError = message;
          }
          break;
        }
      }
    } catch (error, stackTrace) {
      _lastSyncError = error.toString();
      debugPrint('Could not read the menu sync queue: $error\n$stackTrace');
    }
  }

  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  MealMutationOutbox? get _outbox => switch (_cache) {
    final MealMutationOutbox outbox => outbox,
    _ => null,
  };

  bool _shouldPersist(RemoteMealsSnapshot snapshot) =>
      _cache != null && !snapshot.isFromCache && !snapshot.hasPendingWrites;

  Future<CachedMeals?> _readCacheSafely() async {
    final cache = _cache;
    if (cache == null) return null;
    try {
      return await cache.readMeals();
    } catch (error, stackTrace) {
      debugPrint('Menu cache read failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> _deleteLocalImageSafely(String? path) async {
    try {
      await _imageFileStore.delete(path);
    } catch (error, stackTrace) {
      debugPrint('Could not remove a local meal image: $error\n$stackTrace');
    }
  }

  Future<void> _writeCacheSafely(
    Future<void> Function(MealLocalCache cache) write,
  ) async {
    final cache = _cache;
    if (cache == null) return;
    try {
      await write(cache);
    } catch (error, stackTrace) {
      debugPrint('Menu cache write failed: $error\n$stackTrace');
    }
  }

  Future<List<MealModel>> _overlayPendingMutations(
    List<MealModel> remoteMeals,
  ) async {
    final outbox = _outbox;
    final cache = _cache;
    if (outbox == null || cache == null) return remoteMeals;
    final pending = await outbox.readPendingMutations();
    if (pending.isEmpty) return remoteMeals;
    final merged = {for (final meal in remoteMeals) meal.id: meal};
    for (final mutation in pending) {
      if (mutation.type == MealMutationType.delete) {
        merged.remove(mutation.mealId);
      } else {
        final localMeal = await cache.readMeal(mutation.mealId);
        if (localMeal != null) merged[localMeal.id] = localMeal;
      }
    }
    return merged.values.toList(growable: false);
  }

  Future<T?> _local<T>(
    Future<T> Function(MealLocalCache cache) operation,
  ) async {
    final cache = _cache;
    if (cache == null) return null;
    try {
      return await operation(cache);
    } on Exception catch (error, stackTrace) {
      debugPrint('Menu local cache operation failed: $error\n$stackTrace');
      throw const MenuFailure(
        'Could not access local menu storage. Check device storage and try again.',
      );
    }
  }

  Future<MealModel?> _cachedMeal(String id) =>
      _local<MealModel?>((cache) => cache.readMeal(id));

  Future<void> _restore(String id, MealModel? meal) async {
    await _local(
      (cache) => meal == null ? cache.removeMeal(id) : cache.upsertMeal(meal),
    );
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseException catch (e) {
      throw MenuFailure(_firebaseMessage(e));
    }
  }

  String _firebaseMessage(FirebaseException error) => switch (error.code) {
    'permission-denied' =>
      'Firebase denied this write. A signed-in admin with the admin: true claim is required.',
    'unauthenticated' =>
      'Firebase requires a signed-in account to save changes.',
    'unavailable' =>
      'Firebase is unreachable. Changes remain saved locally and will sync when the connection returns.',
    'failed-precondition' =>
      'The Firebase menu index is not ready. Deploy the indexes and try again.',
    'not-found' => 'Meal not found.',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };

  String _syncErrorMessage(Object error) {
    if (error is FirebaseException) return _firebaseMessage(error);
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return _offlineSyncMessage;
    }
    return error.toString();
  }
}
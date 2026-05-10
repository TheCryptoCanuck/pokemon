import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final _log = Logger('PhotoUploadService');
const _uuid = Uuid();

/// Buckets available for photo uploads.
class StorageBuckets {
  static const dogPhotos = 'dog-photos';
  static const sightingPhotos = 'sighting-photos';
  static const lostDogPhotos = 'lost-dog-photos';
  static const communityPhotos = 'community-photos';
}

/// Provides [PhotoUploadService] when authenticated, null otherwise.
final photoUploadServiceProvider = Provider<PhotoUploadService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  return PhotoUploadService(Supabase.instance.client);
});

/// Parameters passed to the isolate for image processing.
class _ProcessParams {
  final Uint8List bytes;
  final int maxDimension;

  _ProcessParams(this.bytes, this.maxDimension);
}

/// Processes an image in an isolate: decodes, resizes, strips EXIF, re-encodes
/// as JPEG. Returns the processed JPEG bytes, or null on failure.
Uint8List? _processImageIsolate(_ProcessParams params) {
  final decoded = img.decodeImage(params.bytes);
  if (decoded == null) return null;

  // Resize so the longest side is at most maxDimension.
  img.Image resized;
  if (decoded.width > params.maxDimension ||
      decoded.height > params.maxDimension) {
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(decoded, width: params.maxDimension);
    } else {
      resized = img.copyResize(decoded, height: params.maxDimension);
    }
  } else {
    resized = decoded;
  }

  // Re-encoding as JPEG strips all EXIF metadata (including GPS).
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// Service for uploading photos to Supabase Storage with client-side
/// preprocessing (resize, EXIF stripping).
class PhotoUploadService {
  final SupabaseClient _client;

  PhotoUploadService(this._client);

  String get _userId {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No authenticated user — session expired');
    }
    return uid;
  }

  // ---------------------------------------------------------------------------
  // Main upload
  // ---------------------------------------------------------------------------

  /// Uploads [photo] to the specified [bucket].
  ///
  /// The image is resized to max 1024px on its longest side and re-encoded as
  /// JPEG (which strips EXIF/GPS data). Processing happens in a background
  /// isolate to keep the UI responsive.
  ///
  /// Returns a public URL for `lost-dog-photos` or a 1-year signed URL for
  /// other buckets. Returns `null` on failure.
  Future<String?> uploadPhoto(
    File photo, {
    required String bucket,
    String? subfolder,
  }) async {
    try {
      // Read the raw file bytes.
      final rawBytes = await photo.readAsBytes();

      // Process in an isolate (resize + strip EXIF).
      final processed = await compute(
        _processImageIsolate,
        _ProcessParams(rawBytes, 1024),
      );

      if (processed == null) {
        _log.severe('Failed to process image: decode returned null');
        return null;
      }

      // Build a unique storage path.
      final folder = subfolder ?? _userId;
      final filename = '${_uuid.v4()}.jpg';
      final storagePath = '$folder/$filename';

      // Upload to Supabase Storage.
      await _client.storage.from(bucket).uploadBinary(
            storagePath,
            processed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Return the appropriate URL.
      if (bucket == StorageBuckets.lostDogPhotos) {
        // Public bucket — return permanent public URL.
        return _client.storage.from(bucket).getPublicUrl(storagePath);
      }

      // Private buckets — return a signed URL valid for 1 year.
      return _client.storage.from(bucket).createSignedUrl(
            storagePath,
            60 * 60 * 24 * 365, // 1 year in seconds
          );
    } catch (e, st) {
      _log.severe('Photo upload failed (bucket=$bucket)', e, st);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience methods
  // ---------------------------------------------------------------------------

  /// Uploads a dog profile photo to the `dog-photos` bucket.
  Future<String?> uploadDogPhoto(File photo) =>
      uploadPhoto(photo, bucket: StorageBuckets.dogPhotos);

  /// Uploads a breed identification photo to the `sighting-photos` bucket.
  Future<String?> uploadSightingPhoto(File photo) =>
      uploadPhoto(photo, bucket: StorageBuckets.sightingPhotos);

  /// Uploads a lost dog report photo to the `lost-dog-photos` bucket (public).
  Future<String?> uploadLostDogPhoto(File photo) =>
      uploadPhoto(photo, bucket: StorageBuckets.lostDogPhotos);

  /// Uploads a community post photo to the `community-photos` bucket.
  Future<String?> uploadCommunityPhoto(File photo) =>
      uploadPhoto(photo, bucket: StorageBuckets.communityPhotos);

  // ---------------------------------------------------------------------------
  // Deletion
  // ---------------------------------------------------------------------------

  /// Deletes a file at [path] from the given [bucket].
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> deletePhoto(String bucket, String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
      return true;
    } catch (e, st) {
      _log.severe('Photo delete failed (bucket=$bucket, path=$path)', e, st);
      return false;
    }
  }
}

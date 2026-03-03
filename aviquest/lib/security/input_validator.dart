/// Input validation and sanitization utilities for AviQuest.
/// Prevents injection attacks and ensures safe data handling.
class InputValidator {
  InputValidator._();

  /// Maximum allowed length for search queries.
  static const int maxSearchLength = 100;

  /// Maximum allowed length for general text input.
  static const int maxTextLength = 500;

  /// Sanitize a search query by removing potentially dangerous characters
  /// and limiting length.
  static String sanitizeSearchQuery(String input) {
    if (input.isEmpty) return input;

    // Trim and limit length
    String sanitized = input.trim();
    if (sanitized.length > maxSearchLength) {
      sanitized = sanitized.substring(0, maxSearchLength);
    }

    // Remove control characters (keep only printable chars + common unicode)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Remove SQL injection patterns
    sanitized = sanitized.replaceAll(RegExp(r"[;'\"\\]"), '');

    // Remove potential script injection patterns
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');

    return sanitized;
  }

  /// Validate that a URL is HTTPS and from an allowed domain.
  static bool isValidMediaUrl(String url) {
    if (url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Enforce HTTPS
    if (uri.scheme != 'https') return false;

    // Allowlist of trusted media domains
    const allowedDomains = [
      'upload.wikimedia.org',
      'commons.wikimedia.org',
      'xeno-canto.org',
      'www.xeno-canto.org',
    ];

    return allowedDomains.any(
      (domain) => uri.host == domain || uri.host.endsWith('.$domain'),
    );
  }

  /// Sanitize a bird name for safe storage and display.
  static String sanitizeBirdName(String name) {
    if (name.isEmpty) return name;

    String sanitized = name.trim();
    if (sanitized.length > maxTextLength) {
      sanitized = sanitized.substring(0, maxTextLength);
    }

    // Remove control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Remove HTML/script tags
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');

    return sanitized;
  }

  /// Validate that a file path is within expected app directories.
  /// Prevents path traversal attacks.
  static bool isValidAppFilePath(String path) {
    if (path.isEmpty) return false;

    // Reject path traversal sequences
    if (path.contains('..')) return false;
    if (path.contains('~')) return false;

    // Reject absolute paths to sensitive directories
    const sensitiveDirectories = [
      '/etc/',
      '/system/',
      '/proc/',
      '/data/data/',
      '/sdcard/',
    ];

    final lowerPath = path.toLowerCase();
    return !sensitiveDirectories.any((dir) => lowerPath.startsWith(dir));
  }
}

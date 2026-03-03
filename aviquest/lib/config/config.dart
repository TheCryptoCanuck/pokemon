/// Configuration validation module for AviQuest.
///
/// Provides schemas, validators, and environment-aware configuration
/// for all application settings, game balance, and data integrity.
///
/// Usage:
/// ```dart
/// import 'package:aviquest/config/config.dart';
///
/// final config = AppConfig.development();
/// final result = config.validate();
/// if (!result.isValid) {
///   for (final error in result.errors) {
///     print(error);
///   }
/// }
/// ```
library;

export 'config_schema.dart';
export 'config_validator.dart';
export 'bird_data_validator.dart';
export 'app_config.dart';

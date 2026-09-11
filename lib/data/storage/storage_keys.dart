/// Storage key constants for local persistence.
class StorageKeys {
  StorageKeys._();

  /// Key for all kit models (JSON array string).
  static const String kits = 'tsumi_pura_kits_v1';

  /// Key for all craft log records (JSON array string).
  static const String craftLogs = 'tsumi_pura_craft_logs_v1';

  /// Key for current active/selected kit ID (String UUID).
  static const String activeKitId = 'tsumi_pura_active_kit_id_v1';

  /// Key for user profile (reserved for future milestones).
  static const String userProfile = 'tsumi_pura_user_profile_v1';
}

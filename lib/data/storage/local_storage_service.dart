import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract for key-value and JSON list local persistence.
abstract class ILocalStorageService {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<List<Map<String, dynamic>>> getJsonList(String key);
  Future<bool> setJsonList(String key, List<Map<String, dynamic>> list);
  Future<bool> remove(String key);
  Future<bool> clear();
}

/// SharedPreferences-backed implementation using pure JSON serialization.
class LocalStorageService implements ILocalStorageService {
  SharedPreferences? _prefs;

  LocalStorageService([SharedPreferences? prefs]) : _prefs = prefs;

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> getString(String key) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(key);
    } catch (e, stack) {
      debugPrint('LocalStorageService.getString error for $key: $e\n$stack');
      return null;
    }
  }

  @override
  Future<bool> setString(String key, String value) async {
    try {
      final prefs = await _getPrefs();
      return prefs.setString(key, value);
    } catch (e, stack) {
      debugPrint('LocalStorageService.setString error for $key: $e\n$stack');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        return <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e, stack) {
      debugPrint('LocalStorageService.getJsonList error for key $key: $e\n$stack');
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Future<bool> setJsonList(String key, List<Map<String, dynamic>> list) async {
    try {
      final prefs = await _getPrefs();
      final jsonString = jsonEncode(list);
      return await prefs.setString(key, jsonString);
    } catch (e, stack) {
      debugPrint('LocalStorageService.setJsonList error for key $key: $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    try {
      final prefs = await _getPrefs();
      return prefs.remove(key);
    } catch (e, stack) {
      debugPrint('LocalStorageService.remove error for $key: $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      final prefs = await _getPrefs();
      return prefs.clear();
    } catch (e, stack) {
      debugPrint('LocalStorageService.clear error: $e\n$stack');
      return false;
    }
  }
}

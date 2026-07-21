import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeychainItem {
  final String id;
  final String label;
  final String token;
  final String? description;
  final int createdAt;

  KeychainItem({
    required this.id,
    required this.label,
    required this.token,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'token': token,
        'description': description,
        'createdAt': createdAt,
      };

  factory KeychainItem.fromJson(Map<String, dynamic> json) => KeychainItem(
        id: json['id'] as String,
        label: json['label'] as String,
        token: json['token'] as String,
        description: json['description'] as String?,
        createdAt: json['createdAt'] as int,
      );
}

class KeychainState {
  final bool isPinSet;
  final bool isUnlocked;
  final List<KeychainItem> items;

  KeychainState({
    required this.isPinSet,
    required this.isUnlocked,
    required this.items,
  });

  KeychainState copyWith({
    bool? isPinSet,
    bool? isUnlocked,
    List<KeychainItem>? items,
  }) {
    return KeychainState(
      isPinSet: isPinSet ?? this.isPinSet,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      items: items ?? this.items,
    );
  }
}

class KeychainNotifier extends StateNotifier<KeychainState> {
  KeychainNotifier() : super(KeychainState(isPinSet: false, isUnlocked: false, items: [])) {
    _init();
  }

  static const _secureStorage = FlutterSecureStorage();
  static const _pinKey = 'keychain_pin';
  static const _itemsKey = 'keychain_items';

  Future<void> _init() async {
    final pin = await _secureStorage.read(key: _pinKey);
    final itemsStr = await _secureStorage.read(key: _itemsKey);
    List<KeychainItem> items = [];
    if (itemsStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(itemsStr);
        items = decoded.map((e) => KeychainItem.fromJson(e)).toList();
      } catch (_) {}
    }
    state = KeychainState(
      isPinSet: pin != null && pin.isNotEmpty,
      isUnlocked: false,
      items: items,
    );
  }

  Future<bool> setPin(String pin) async {
    if (pin.length != 4) return false;
    await _secureStorage.write(key: _pinKey, value: pin);
    state = state.copyWith(isPinSet: true, isUnlocked: true);
    return true;
  }

  Future<bool> verifyAndUnlock(String pin) async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    if (storedPin == pin) {
      state = state.copyWith(isUnlocked: true);
      return true;
    }
    return false;
  }

  void lock() {
    state = state.copyWith(isUnlocked: false);
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    if (storedPin == oldPin && newPin.length == 4) {
      await _secureStorage.write(key: _pinKey, value: newPin);
      state = state.copyWith(isPinSet: true, isUnlocked: true);
      return true;
    }
    return false;
  }

  Future<void> resetKeychainAndWipe() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.delete(key: _itemsKey);
    state = KeychainState(isPinSet: false, isUnlocked: false, items: []);
  }

  Future<void> addItem(String label, String token, String? description) async {
    final item = KeychainItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      token: token,
      description: description,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final newItems = [...state.items, item];
    await _secureStorage.write(key: _itemsKey, value: jsonEncode(newItems.map((e) => e.toJson()).toList()));
    state = state.copyWith(items: newItems);
  }

  Future<void> removeItem(String id) async {
    final newItems = state.items.where((e) => e.id != id).toList();
    await _secureStorage.write(key: _itemsKey, value: jsonEncode(newItems.map((e) => e.toJson()).toList()));
    state = state.copyWith(items: newItems);
  }
}

final keychainProvider = StateNotifierProvider<KeychainNotifier, KeychainState>((ref) {
  return KeychainNotifier();
});

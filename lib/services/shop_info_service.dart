import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ShopInfo {
  final String name;
  final String phone;
  final String address;
  final String invoiceFooter;
  final String logoPath;

  const ShopInfo({
    required this.name,
    required this.phone,
    required this.address,
    required this.invoiceFooter,
    this.logoPath = '',
  });
}

class ShopInfoService {
  static const String _keyShopName = 'shop_name';
  static const String _keyShopPhone = 'shop_phone';
  static const String _keyShopAddress = 'shop_address';
  static const String _keyInvoiceFooter = 'invoice_footer';
  static const String _keyShopLogo = 'shop_logo';

  static const String defaultName = 'ADOT Organic Store';
  static const String defaultPhone = '01800-000000';
  static const String defaultAddress = 'ঢাকা, বাংলাদেশ';
  static const String defaultInvoiceFooter = 'আবার আসবেন, ধন্যবাদ!';

  static final ValueNotifier<ShopInfo> shopInfoNotifier = ValueNotifier<ShopInfo>(
    const ShopInfo(
      name: defaultName,
      phone: defaultPhone,
      address: defaultAddress,
      invoiceFooter: defaultInvoiceFooter,
      logoPath: '',
    ),
  );

  static StreamSubscription? _realtimeSubscription;

  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Listen to live updates from Supabase `store_settings` table in real-time across devices
  static void listenToRealtimeShopSettings() {
    final client = _supabase;
    if (client == null) return;

    _realtimeSubscription?.cancel();
    try {
      _realtimeSubscription = client
          .from('store_settings')
          .stream(primaryKey: ['id'])
          .listen((data) async {
            if (data.isNotEmpty) {
              final payload = data.first;
              final remoteName = payload['shop_name']?.toString() ?? defaultName;
              final remotePhone = payload['phone']?.toString() ?? defaultPhone;
              final remoteAddress = payload['address']?.toString() ?? defaultAddress;
              final remoteFooter = payload['invoice_footer']?.toString() ?? defaultInvoiceFooter;
              final remoteLogo = payload['logo_url']?.toString() ?? payload['logo_path']?.toString() ?? '';

              final remoteShopInfo = ShopInfo(
                name: remoteName,
                phone: remotePhone,
                address: remoteAddress,
                invoiceFooter: remoteFooter,
                logoPath: remoteLogo,
              );

              // Update local SharedPreferences
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_keyShopName, remoteName);
                await prefs.setString(_keyShopPhone, remotePhone);
                await prefs.setString(_keyShopAddress, remoteAddress);
                await prefs.setString(_keyInvoiceFooter, remoteFooter);
                await prefs.setString(_keyShopLogo, remoteLogo);
              } catch (_) {}

              // Update reactive ValueNotifier
              shopInfoNotifier.value = remoteShopInfo;
            }
          }, onError: (e) {
            debugPrint('Realtime store_settings stream error: $e');
          });
    } catch (e) {
      debugPrint('Realtime store_settings subscription error: $e');
    }
  }

  static void disposeRealtimeListener() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  /// Cross-platform helper to get ImageProvider for logo (Base64, Network, or File)
  static ImageProvider? buildShopLogoImage(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('data:image')) {
      try {
        final base64Str = trimmed.contains(',') ? trimmed.split(',').last : trimmed;
        final bytes = base64Decode(base64Str);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding base64 logo: $e');
        return null;
      }
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    if (kIsWeb) {
      return NetworkImage(trimmed);
    }

    final file = File(trimmed);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }

  /// Cross-platform check if valid logo exists
  static bool hasValidLogo(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('data:image') || trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return true;
    }
    if (kIsWeb) return true;
    return File(trimmed).existsSync();
  }

  /// Helper to pick image from gallery and encode it as Base64 data string (bypasses ImageCropper for Android stability)
  static Future<String?> pickAndCropLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      final Uint8List bytes = await pickedFile.readAsBytes();
      final String base64Image = 'data:image/png;base64,${base64Encode(bytes)}';

      return base64Image;
    } on MissingPluginException catch (e) {
      debugPrint('Image picker MissingPluginException: $e');
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('Image picker PlatformException: $e');
      rethrow;
    } catch (e) {
      debugPrint('Error picking image: $e');
      rethrow;
    }
  }

  /// Load persisted shop info from SharedPreferences and sync with Supabase `store_settings`
  static Future<void> loadShopInfo() async {
    // 1. First load local SharedPreferences for instant startup
    String name = defaultName;
    String phone = defaultPhone;
    String address = defaultAddress;
    String invoiceFooter = defaultInvoiceFooter;
    String logoPath = '';

    try {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString(_keyShopName) ?? defaultName;
      phone = prefs.getString(_keyShopPhone) ?? defaultPhone;
      address = prefs.getString(_keyShopAddress) ?? defaultAddress;
      invoiceFooter = prefs.getString(_keyInvoiceFooter) ?? defaultInvoiceFooter;
      logoPath = prefs.getString(_keyShopLogo) ?? '';
    } catch (_) {}

    shopInfoNotifier.value = ShopInfo(
      name: name,
      phone: phone,
      address: address,
      invoiceFooter: invoiceFooter,
      logoPath: logoPath,
    );

    // 2. Fetch remote store_settings from Supabase if connected
    final client = _supabase;
    if (client != null) {
      try {
        final userId = client.auth.currentUser?.id;
        dynamic response;
        if (userId != null) {
          response = await client.from('store_settings').select().eq('user_id', userId).maybeSingle();
        }
        response ??= await client.from('store_settings').select().limit(1).maybeSingle();

        if (response != null && response is Map<String, dynamic>) {
          final remoteNameRaw = response['shop_name']?.toString() ?? response['name']?.toString();
          final remotePhoneRaw = response['phone']?.toString();
          final remoteAddressRaw = response['address']?.toString();
          final remoteFooterRaw = response['invoice_footer']?.toString();
          final remoteLogoRaw = response['logo_url']?.toString() ?? response['logo_path']?.toString();

          final remoteName = (remoteNameRaw != null && remoteNameRaw.trim().isNotEmpty) ? remoteNameRaw.trim() : name;
          final remotePhone = (remotePhoneRaw != null && remotePhoneRaw.trim().isNotEmpty) ? remotePhoneRaw.trim() : phone;
          final remoteAddress = (remoteAddressRaw != null && remoteAddressRaw.trim().isNotEmpty) ? remoteAddressRaw.trim() : address;
          final remoteFooter = (remoteFooterRaw != null && remoteFooterRaw.trim().isNotEmpty) ? remoteFooterRaw.trim() : invoiceFooter;
          final remoteLogo = (remoteLogoRaw != null && remoteLogoRaw.trim().isNotEmpty) ? remoteLogoRaw.trim() : logoPath;

          final remoteShopInfo = ShopInfo(
            name: remoteName,
            phone: remotePhone,
            address: remoteAddress,
            invoiceFooter: remoteFooter,
            logoPath: remoteLogo,
          );

          // Update local preferences with remote data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyShopName, remoteName);
          await prefs.setString(_keyShopPhone, remotePhone);
          await prefs.setString(_keyShopAddress, remoteAddress);
          await prefs.setString(_keyInvoiceFooter, remoteFooter);
          await prefs.setString(_keyShopLogo, remoteLogo);

          shopInfoNotifier.value = remoteShopInfo;
        }
      } catch (e) {
        debugPrint('Supabase store_settings fetch info: $e');
      }

      // 3. Start realtime stream listener for instant multi-device sync
      listenToRealtimeShopSettings();
    }
  }

  /// Save updated shop info to SharedPreferences, Supabase `store_settings`, and update ValueNotifier
  static Future<void> updateShopInfo({
    required String name,
    required String phone,
    required String address,
    required String invoiceFooter,
    String? logoPath,
  }) async {
    final currentLogo = logoPath ?? shopInfoNotifier.value.logoPath;

    final updated = ShopInfo(
      name: name.trim().isEmpty ? defaultName : name.trim(),
      phone: phone.trim().isEmpty ? defaultPhone : phone.trim(),
      address: address.trim().isEmpty ? defaultAddress : address.trim(),
      invoiceFooter: invoiceFooter.trim().isEmpty ? defaultInvoiceFooter : invoiceFooter.trim(),
      logoPath: currentLogo,
    );

    // 1. Save locally to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyShopName, updated.name);
      await prefs.setString(_keyShopPhone, updated.phone);
      await prefs.setString(_keyShopAddress, updated.address);
      await prefs.setString(_keyInvoiceFooter, updated.invoiceFooter);
      await prefs.setString(_keyShopLogo, updated.logoPath);
    } catch (_) {}

    // 2. Update reactive ValueNotifier for instant UI refresh
    shopInfoNotifier.value = updated;

    // 3. Upsert to Supabase `store_settings` table
    final client = _supabase;
    if (client != null) {
      try {
        final user = client.auth.currentUser;
        final storeData = <String, dynamic>{
          'shop_name': updated.name,
          'phone': updated.phone,
          'address': updated.address,
          'invoice_footer': updated.invoiceFooter,
          'logo_url': updated.logoPath,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        if (user != null) {
          storeData['user_id'] = user.id;
        }

        final response = await client
            .from('store_settings')
            .upsert(storeData, onConflict: user != null ? 'user_id' : null)
            .select();

        debugPrint('Supabase Store Settings Saved Successfully: $response');

        // Re-assign ValueNotifier to guarantee broadcast to all UI listeners
        shopInfoNotifier.value = ShopInfo(
          name: updated.name,
          phone: updated.phone,
          address: updated.address,
          invoiceFooter: updated.invoiceFooter,
          logoPath: updated.logoPath,
        );
      } catch (e) {
        debugPrint('Error saving to Supabase store_settings: $e');
        rethrow;
      }
    }
  }
}

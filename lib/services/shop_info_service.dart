import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

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

  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Cross-platform helper to get ImageProvider for logo
  static ImageProvider? buildShopLogoImage(String path) {
    if (path.trim().isEmpty) return null;
    if (kIsWeb) {
      return NetworkImage(path);
    }
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  /// Cross-platform check if valid logo exists
  static bool hasValidLogo(String path) {
    if (path.trim().isEmpty) return false;
    if (kIsWeb) return true;
    return File(path).existsSync();
  }

  /// Helper to pick image from gallery and crop it to 1:1 square ratio (with raw image fallback)
  static Future<String?> pickAndCropLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // Validate reading bytes cross-platform
      await pickedFile.readAsBytes();

      XFile finalFile = pickedFile;

      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'লোগো সাইজ পরিবর্তন করুন',
              toolbarColor: const Color(0xFF2E4F3E),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'লোগো সাইজ পরিবর্তন করুন',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          finalFile = XFile(croppedFile.path);
        }
      } catch (e) {
        debugPrint('Cropper not supported on this platform, using raw image: $e');
      }

      return finalFile.path;
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
          final remoteName = response['shop_name']?.toString() ?? name;
          final remotePhone = response['phone']?.toString() ?? phone;
          final remoteAddress = response['address']?.toString() ?? address;
          final remoteFooter = response['invoice_footer']?.toString() ?? invoiceFooter;
          final remoteLogo = response['logo_url']?.toString() ?? response['logo_path']?.toString() ?? logoPath;

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
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (user != null) {
          storeData['user_id'] = user.id;
        }

        final response = await client
            .from('store_settings')
            .upsert(storeData)
            .select();

        debugPrint('Supabase Store Settings Saved Successfully: $response');
      } catch (e) {
        debugPrint('Error saving to Supabase store_settings: $e');
        rethrow;
      }
    }
  }
}

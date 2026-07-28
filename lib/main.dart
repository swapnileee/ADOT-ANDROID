import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/shop_info_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Client
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  // Load Shop Info from SharedPreferences & Supabase store_settings
  await ShopInfoService.loadShopInfo();

  runApp(const AdotShopApp());
}

class AdotShopApp extends StatelessWidget {
  const AdotShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADOT | আদত',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const MainScreen(),
    );
  }
}

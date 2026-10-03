import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/core/const/data.dart';
import 'package:quiz_monster/core/router/router_provider.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/settings/notification_listener.dart'
    as notifications;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_API_KEY,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // 세로 모드만 허용
  ]);
  runApp(ProviderScope(child: const _App()));
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class _App extends ConsumerWidget {
  const _App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => notifications.NotificationListener(
        messengerKey: _messengerKey,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: theme,
    );
  }
}

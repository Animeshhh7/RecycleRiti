import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/controller/bottom_nav_controller.dart';
import 'package:recycle_riti/model/page_model.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/error_screen.dart';
import 'package:recycle_riti/view/home_screen.dart';
import 'package:recycle_riti/view/pickup_screen.dart';
import 'package:recycle_riti/view/profile_screen.dart';
import 'package:recycle_riti/view/recycle_screen.dart';
import 'package:recycle_riti/widgets/custom_bottom_nav_bar.dart';

// Global key for ScaffoldMessenger to show SnackBars globally
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  print('Loaded BASE_URL: ${dotenv.env['BASE_URL']}');

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }

  // Request notification permissions
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('Notification permissions requested');
  } catch (e) {
    print('Failed to request notification permissions: $e');
  }

  // Test backend connection
  try {
    await AuthService.testBackend();
    print('Backend test passed');
  } catch (e) {
    print('Backend test failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BottomNavController(totalTabs: 4)),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recycle Riti',
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: scaffoldMessengerKey,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.getRoutes(),
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const ErrorScreen(message: 'Route not found'),
        );
      },
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navCtrl = Provider.of<BottomNavController>(context);

    final List<PageModel> pages = [
      PageModel(lbl: 'Home', ico: Icons.home, view: const HomeScreen()),
      PageModel(
          lbl: 'Schedule', ico: Icons.calendar_today, view: const PickupScreen()),
      PageModel(lbl: 'Recycle', ico: Icons.recycling, view: const RecycleScreen()),
      PageModel(lbl: 'Profile', ico: Icons.person, view: const ProfileScreen()),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppTheme.backgroundColor),
        child: IndexedStack(
          index: navCtrl.currentIndex,
          children: pages.map((page) => page.view).toList(),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        pages: pages,
      ),
    );
  }
}
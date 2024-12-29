import 'package:flutter/material.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/main.dart';
import 'package:recycle_riti/view/agent_screen.dart';
import 'package:recycle_riti/view/edit_profile.dart';
import 'package:recycle_riti/view/error_screen.dart';
import 'package:recycle_riti/view/event_participation_screen.dart';
import 'package:recycle_riti/view/home_screen.dart';
import 'package:recycle_riti/view/login_screen.dart';
import 'package:recycle_riti/view/pickup_confirmation_screen.dart';
import 'package:recycle_riti/view/pickup_history_screen.dart';
import 'package:recycle_riti/view/pickup_screen.dart';
import 'package:recycle_riti/view/profile_screen.dart';
import 'package:recycle_riti/view/recycle_screen.dart';
import 'package:recycle_riti/view/recycling_tips_screen.dart';
import 'package:recycle_riti/view/signup_screen.dart';
import 'package:recycle_riti/view/splash_screen.dart';
import 'package:recycle_riti/view/track_request_screen.dart';
import 'package:recycle_riti/view/track_request_screen_agent.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Rewards Screen - Coming Soon')),
    );
  }
}

class EventsHistoryScreen extends StatelessWidget {
  const EventsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Events History Screen - Coming Soon')),
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Account Settings Screen - Coming Soon')),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Help & Support Screen - Coming Soon')),
    );
  }
}

class AppRoutes {
  static const String editProfile = '/edit-profile';
  static const String error = '/error';
  static const String eventParticipation = '/event-participation';
  static const String home = '/home';
  static const String login = '/login';
  static const String main = '/main';
  static const String pickupConfirmation = '/pickup-confirmation';
  static const String profile = '/profile';
  static const String recycle = '/recycle';
  static const String schedule = '/schedule';
  static const String signup = '/signup';
  static const String agent = '/agent';
  static const String splash = '/splash';
  static const String trackAgent = '/track-agent';
  static const String trackRequestUser = '/track-request-user';
  static const String trackRequestAgent = '/track-request-agent';
  static const String recyclingTips = '/recycling-tips';
  static const String rewards = '/rewards';
  static const String recyclingHistory = '/recycling-history';
  static const String eventsHistory = '/events-history';
  static const String accountSettings = '/account-settings';
  static const String helpSupport = '/help-support';

  static Widget _validateArgumentsAndBuild({
    required Map<String, dynamic>? args,
    required String requiredKey,
    required String routeName,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    if (args == null || !args.containsKey(requiredKey)) {
      print('AppRoutes - $routeName: Missing required argument: $requiredKey');
      return ErrorScreen(message: 'Error in $routeName: $requiredKey is required');
    }

    if (requiredKey == 'requestId') {
      final requestId = args[requiredKey];
      if (requestId is! String || requestId.isEmpty) {
        print('AppRoutes - $routeName: Invalid $requiredKey: $requestId (must be a non-empty string)');
        return ErrorScreen(message: 'Error in $routeName: $requiredKey must be a non-empty string');
      }
    }

    return builder(args);
  }

  static Widget _validateMainArguments({
    required Map<String, dynamic>? args,
    required Widget Function(Map<String, dynamic>?) builder,
  }) {
    int tabIndex = 0;
    if (args != null && args.containsKey('tabIndex')) {
      final index = args['tabIndex'];
      if (index is! int || index < 0 || index > 3) {
        print('AppRoutes - $main: Invalid tabIndex: $index (must be an integer between 0 and 3)');
        return const ErrorScreen(message: 'Error in Main Route: tabIndex must be between 0 and 3');
      }
      tabIndex = index;
    }
    return builder({'tabIndex': tabIndex});
  }

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      editProfile: (context) => const EditProfileScreen(),
      error: (context) => const ErrorScreen(message: 'An error occurred'),
      eventParticipation: (context) => const EventParticipationScreen(),
      home: (context) => const HomeScreen(),
      login: (context) => const LoginScreen(),
      main: (context) => _validateMainArguments(
        args: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?,
        builder: (args) => const MainApp(),
      ),
      pickupConfirmation: (context) => _validateArgumentsAndBuild(
        args: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?,
        requiredKey: 'requestId',
        routeName: pickupConfirmation,
        builder: (args) => PickupConfirmationScreen(requestId: args['requestId']),
      ),
      profile: (context) => const ProfileScreen(),
      recycle: (context) => const RecycleScreen(),
      schedule: (context) => const PickupScreen(),
      signup: (context) => const SignupScreen(),
      agent: (context) => const AgentScreen(),
      splash: (context) => SplashScreen(
        onInitializationComplete: () async {
          try {
            final authService = AuthService();
            return await authService.getInitialRoute();
          } catch (e) {
            print('AppRoutes - SplashScreen: Failed to determine initial route: $e');
            print('AppRoutes - Stack trace: ${e.toString()}');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Failed to initialize app. Redirecting to login.',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(10),
                ),
              );
            }
            return AppRoutes.login;
          }
        },
      ),
      trackAgent: (context) => _validateArgumentsAndBuild(
        args: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?,
        requiredKey: 'requestId',
        routeName: trackAgent,
        builder: (args) => TrackRequestScreenAgent(requestId: args['requestId']),
      ),
      trackRequestUser: (context) => _validateArgumentsAndBuild(
        args: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?,
        requiredKey: 'requestId',
        routeName: trackRequestUser,
        builder: (args) => TrackRequestScreenUser(requestId: args['requestId']),
      ),
      trackRequestAgent: (context) => _validateArgumentsAndBuild(
        args: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?,
        requiredKey: 'requestId',
        routeName: trackRequestAgent,
        builder: (args) => TrackRequestScreenAgent(requestId: args['requestId']),
      ),
      rewards: (context) => const RewardsScreen(),
      recyclingHistory: (context) => const PickupHistoryScreen(),
      eventsHistory: (context) => const EventsHistoryScreen(),
      accountSettings: (context) => const AccountSettingsScreen(),
      helpSupport: (context) => const HelpSupportScreen(),
      recyclingTips: (context) => const RecyclingTipsScreen(),
    };
  }
}// 5411
// 22984
// 17662

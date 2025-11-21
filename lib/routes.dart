import 'package:flutter/material.dart';
import 'models/order_model.dart';

// Экраны Auth
import 'screens/main_router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/role_selection_screen.dart';

// Экраны Client
import 'screens/client/client_home_screen.dart';
import 'screens/client/client_order_creation_screen.dart';
import 'screens/client/client_order_tracking_screen.dart';
import 'screens/client/client_rating_screen.dart';

// Экраны Master
import 'screens/master/master_home_screen.dart';
import 'screens/master/master_order_map_view_screen.dart';
import 'screens/master/master_profile_editor_screen.dart';
import 'screens/master/master_verification_screen.dart';

// Экран Chat
import 'screens/chat/chat_screen.dart';

class Routes {
  static const String initial = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role_selection';

  static const String clientHome = '/client/home';
  static const String clientOrderCreation = '/client/create_order';
  static const String clientOrderTracking = '/client/tracking';
  static const String clientRating = '/client/rating';

  static const String masterHome = '/master/home';
  static const String masterOrderMapView = '/master/map_view';
  static const String masterProfileEditor = '/master/profile_editor';
  static const String masterVerification = '/master/verification';

  static const String chat = '/chat';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
    // --- Core ---
      case Routes.initial:
        return MaterialPageRoute(builder: (_) => const MainRouter());

    // --- Auth ---
      case Routes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case Routes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case Routes.roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());

    // --- Client ---
      case Routes.clientHome:
        return MaterialPageRoute(builder: (_) => const ClientHomeScreen());
      case Routes.clientOrderCreation:
        return MaterialPageRoute(builder: (_) => const ClientOrderCreationScreen());
      case Routes.clientOrderTracking:
        if (args is OrderModel) {
          return MaterialPageRoute(builder: (_) => ClientOrderTrackingScreen(initialOrder: args));
        }
        return _errorRoute('OrderModel required for Tracking');
      case Routes.clientRating:
        if (args is OrderModel) {
          return MaterialPageRoute(builder: (_) => ClientRatingScreen(order: args));
        }
        return _errorRoute('OrderModel required for Rating');

    // --- Master ---
      case Routes.masterHome:
        return MaterialPageRoute(builder: (_) => const MasterHomeScreen());
      case Routes.masterProfileEditor:
        return MaterialPageRoute(builder: (_) => const MasterProfileEditorScreen());
      case Routes.masterVerification:
      // Если передаем аргумент isAwaiting (bool), используем его, иначе false
        final bool isAwaiting = (args is bool) ? args : false;
        return MaterialPageRoute(builder: (_) => MasterVerificationScreen(isAwaiting: isAwaiting));
      case Routes.masterOrderMapView:
        if (args is OrderModel) {
          return MaterialPageRoute(builder: (_) => MasterOrderMapViewScreen(initialOrder: args));
        }
        return _errorRoute('OrderModel required for MapView');

    // --- Chat ---
      case Routes.chat:
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              orderId: args['orderId'],
              otherUserName: args['otherUserName'],
            ),
          );
        }
        return _errorRoute('Invalid args for Chat');

      default:
        return _errorRoute('No route defined for ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:bolt_usta_app/models/order_model.dart';

// --- Экраны ---
import 'package:bolt_usta_app/screens/main_router.dart';
import 'package:bolt_usta_app/screens/auth/login_screen.dart';
import 'package:bolt_usta_app/screens/auth/register_screen.dart';
import 'package:bolt_usta_app/screens/auth/role_selection_screen.dart';

import 'package:bolt_usta_app/screens/client/client_home_screen.dart';
import 'package:bolt_usta_app/screens/client/client_order_creation_screen.dart';
import 'package:bolt_usta_app/screens/client/client_order_tracking_screen.dart';
import 'package:bolt_usta_app/screens/client/client_rating_screen.dart';

import 'package:bolt_usta_app/screens/master/master_home_screen.dart';
import 'package:bolt_usta_app/screens/master/master_order_map_view_screen.dart';
import 'package:bolt_usta_app/screens/master/master_profile_editor_screen.dart';
import 'package:bolt_usta_app/screens/master/master_verification_screen.dart';

import 'package:bolt_usta_app/screens/chat/chat_screen.dart';

class Routes {
  // Основные
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role_selection';

  // Клиент
  static const String clientHome = '/client/home';
  static const String clientOrderCreation = '/client/create_order';
  static const String clientOrderTracking = '/client/tracking';
  static const String clientRating = '/client/rating';

  // Мастер
  static const String masterHome = '/master/home';
  static const String masterVerification = '/master/verification';
  static const String masterProfileEditor = '/master/profile';
  static const String masterOrderMapView = '/master/map_view';

  // Общие
  static const String chat = '/chat';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
    // --- Core ---
      case Routes.root:
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
        final args = settings.arguments;
        if (args is OrderModel) {
          return MaterialPageRoute(builder: (_) => ClientOrderTrackingScreen(initialOrder: args));
        }
        return _errorRoute('Ошибка: Неверный аргумент для трекинга');
      case Routes.clientRating:
        final args = settings.arguments;
        if (args is OrderModel) {
          return MaterialPageRoute(builder: (_) => ClientRatingScreen(order: args));
        }
        return _errorRoute('Ошибка: Неверный аргумент для оценки');

    // --- Master ---
      case Routes.masterHome:
        return MaterialPageRoute(builder: (_) => const MasterHomeScreen());
      case Routes.masterVerification:
        final isAwaiting = settings.arguments as bool? ?? false;
        return MaterialPageRoute(builder: (_) => MasterVerificationScreen(isAwaiting: isAwaiting));
      case Routes.masterProfileEditor:
        return MaterialPageRoute(builder: (_) => const MasterProfileEditorScreen());
      case Routes.masterOrderMapView:
        final args = settings.arguments;
        if (args is OrderModel) {
          return MaterialPageRoute(builder: (_) => MasterOrderMapViewScreen(initialOrder: args));
        }
        return _errorRoute('Ошибка: Неверный аргумент для карты');

    // --- Chat ---
      case Routes.chat:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args != null && args.containsKey('orderId') && args.containsKey('otherUserName')) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              orderId: args['orderId'],
              otherUserName: args['otherUserName'],
            ),
          );
        }
        return _errorRoute('Ошибка: Неверные аргументы для чата');

      default:
        return _errorRoute('Маршрут не найден: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Ошибка Навигации'), backgroundColor: Colors.red),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(message, textAlign: TextAlign.center),
        )),
      ),
    );
  }
}
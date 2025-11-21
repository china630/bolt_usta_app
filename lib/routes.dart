import 'package:flutter/material.dart';
import 'package:on_demand_service_app/models/order_model.dart';

// --- Основные импорты экранов ---
import 'package:on_demand_service_app/screens/main_router.dart'; // Главный роутер для проверки авторизации/роли

// Экраны Аутентификации
import 'package:on_demand_service_app/screens/auth/login_screen.dart';
import 'package:on_demand_service_app/screens/auth/register_screen.dart';
import 'package:on_demand_service_app/screens/auth/role_selection_screen.dart'; // Экран выбора роли

// Экраны Клиента
import 'package:on_demand_service_app/screens/client/client_home_screen.dart';
import 'package:on_demand_service_app/screens/client/client_order_creation_screen.dart';
import 'package:on_demand_service_app/screens/client/client_order_tracking_screen.dart';
import 'package:on_demand_service_app/screens/client/client_rating_screen.dart'; // Импорт экрана оценки

// Экраны Мастера
import 'package:on_demand_service_app/screens/master/master_home_screen.dart';
import 'package:on_demand_service_app/screens/master/master_order_map_view_screen.dart';
import 'package:on_demand_service_app/screens/master/master_profile_editor_screen.dart'; // Для верификации и заполнения профиля

/// Класс для хранения всех именованных маршрутов
class Routes {
  // Основные и Аутентификационные
  static const String mainRouter = '/'; // Основной маршрут, который проверяет авторизацию
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role_selection';

  // Маршруты Клиента
  static const String clientHome = '/client_home';
  static const String clientOrderCreation = '/client_order_creation';
  static const String clientOrderTracking = '/client_order_tracking';
  static const String clientRating = '/client_rating';

  // Маршруты Мастера
  static const String masterHome = '/master_home';
  static const String masterOrderMapView = '/master_order_map_view';
  static const String masterProfileEditor = '/master_profile_editor';
}

/// Класс для управления навигацией и генерацией маршрутов
class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
    // --- Основные и Аутентификационные маршруты ---
      case Routes.mainRouter:
      // MainRouter теперь содержит логику перенаправления на home или roleSelection
        return MaterialPageRoute(builder: (_) => const MainRouter());
      case Routes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case Routes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case Routes.roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());

    // --- Клиентские маршруты ---
      case Routes.clientHome:
        return MaterialPageRoute(builder: (_) => const ClientHomeScreen());
      case Routes.clientOrderCreation:
        return MaterialPageRoute(builder: (_) => const ClientOrderCreationScreen());
      case Routes.clientOrderTracking:
      // Требует OrderModel в качестве аргумента.
        final args = settings.arguments;
        if (args is OrderModel) {
          return MaterialPageRoute(
              builder: (_) => ClientOrderTrackingScreen(initialOrder: args));
        }
        return _errorRoute('Неверный аргумент для ClientOrderTrackingScreen');

      case Routes.clientRating:
      // Требует OrderModel в качестве аргумента.
        final args = settings.arguments;
        if (args is OrderModel) {
          return MaterialPageRoute(
              builder: (_) => ClientRatingScreen(order: args));
        }
        return _errorRoute('Неверный аргумент для ClientRatingScreen');

    // --- Мастерские маршруты ---
      case Routes.masterHome:
        return MaterialPageRoute(builder: (_) => const MasterHomeScreen());
      case Routes.masterOrderMapView:
      // Требует OrderModel в качестве аргумента.
        final args = settings.arguments;
        if (args is OrderModel) {
          return MaterialPageRoute(
              builder: (_) => MasterOrderMapViewScreen(initialOrder: args));
        }
        return _errorRoute('Неверный аргумент для MasterOrderMapViewScreen');

      case Routes.masterProfileEditor:
        return MaterialPageRoute(builder: (_) => const MasterProfileEditorScreen());

      default:
      // Маршрут по умолчанию (ошибка)
        return _errorRoute('Нет маршрута для: ${settings.name}');
    }
  }

  /// Вспомогательная функция для создания маршрута ошибки
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Ошибка Навигации'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
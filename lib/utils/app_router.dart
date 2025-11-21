import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes.dart';

// Импорты экранов
import '../screens/master/master_home_screen.dart';
import '../screens/master/master_verification_screen.dart';
import '../screens/client/client_order_wait_screen.dart';
import '../screens/client/client_order_creation_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/client/client_home_screen.dart'; // Добавлен импорт клиентского экрана


// --- Заглушка Экрана Аутентификации (для app_router.dart) ---
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Простая заглушка для перенаправления
    // В реальном приложении здесь будет логика входа/регистрации
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Если пользователь не авторизован или ждем данных
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          // Если анонимный вход еще не произошел (или пользователь вышел), показываем заглушку
          if (FirebaseAuth.instance.currentUser == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Вход / Регистрация')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Заглушка экрана аутентификации. Вход...'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Реализовать логику выбора роли или автоматический анонимный вход
                        Navigator.of(context).pushNamed(Routes.clientHome);
                      },
                      child: const Text('Перейти к Клиенту'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Реализовать логику выбора роли или автоматический анонимный вход
                        Navigator.of(context).pushNamed(Routes.masterHome);
                      },
                      child: const Text('Перейти к Мастеру'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Реализовать логику выбора роли или автоматический анонимный вход
                        Navigator.of(context).pushNamed(Routes.masterVerification);
                      },
                      child: const Text('Перейти к Верификации Мастера'),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        // В реальном приложении здесь будет логика проверки роли и перенаправления.
        // Пока просто перенаправляем на главную клиента по умолчанию.
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed(Routes.clientHome);
        });
        return const SizedBox.shrink();
      },
    );
  }
}

// --- Класс Роутера ---

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
    // Аутентификация
      case Routes.auth:
        return MaterialPageRoute(builder: (_) => const AuthScreen());

    // Клиентские маршруты
      case Routes.clientHome:
        return MaterialPageRoute(builder: (_) => const ClientHomeScreen());

      case Routes.clientOrderCreation:
        return MaterialPageRoute(builder: (_) => const ClientOrderCreationScreen());

      case Routes.clientOrderWait:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => ClientOrderWaitScreen(orderId: args),
          );
        }
        return _errorRoute('Не передан orderId для ClientOrderWaitScreen');

    // Мастерские маршруты
      case Routes.masterVerification:
      // Если передан аргумент isAwaiting (хотя мы не используем его в pushNamed)
        final bool isAwaiting = (args is bool) ? args : false;
        return MaterialPageRoute(
            builder: (_) => MasterVerificationScreen(isAwaiting: isAwaiting));

      case Routes.masterHome:
        return MaterialPageRoute(builder: (_) => const MasterHomeScreen());

    // Общие маршруты (Чат)
      case Routes.chat:
        if (args is Map<String, dynamic> &&
            args.containsKey('orderId') &&
            args.containsKey('otherUserName')) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              orderId: args['orderId'] as String,
              otherUserName: args['otherUserName'] as String,
            ),
          );
        }
        return _errorRoute('Неверные аргументы для ChatScreen');


      default:
        return _errorRoute('Неизвестный роут: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}
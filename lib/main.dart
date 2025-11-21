import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Импорт необходимых файлов
import 'firebase_options.dart';
import 'routes.dart';

void main() async {
  // Инициализация Flutter-движка
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On-Demand Service App',
      theme: ThemeData(
        // Основная тема приложения
        primarySwatch: Colors.teal,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal.shade700,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        // Убрано visualDensity, так как это обычно является значением по умолчанию
        // и может вызывать предупреждения в некоторых версиях.
        useMaterial3: true,
      ),

      // Настройка роутов
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: Routes.authCheck, // Устанавливаем начальный роут

      // Используем StreamBuilder для отслеживания состояния авторизации
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Ожидание подключения/авторизации
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Если пользователь не авторизован (null), показываем экран аутентификации
          if (!snapshot.hasData || snapshot.data == null) {
            // Перенаправляем на заглушку AuthScreen, которая в реальном приложении будет экраном Входа/Регистрации
            return AuthScreen(); // Это заглушка из app_router.dart
          }

          // 3. Пользователь авторизован (snapshot.data - это User)
          final user = snapshot.data!;

          // Здесь должна быть логика проверки роли (Клиент vs Мастер)
          // В реальном приложении эта информация должна быть в Firestore

          // --- ВРЕМЕННАЯ ЛОГИКА ОПРЕДЕЛЕНИЯ РОЛИ (Заглушка) ---
          // Предположим, что все новые пользователи - Клиенты, пока не пройдут верификацию Мастера.

          // В рамках этого приложения:
          // Если пользователь - "Мастер", его роль будет проверена в MasterVerificationScreen
          // или он будет перенаправлен на MasterHomeScreen.

          // В текущей реализации мы просто переходим на ClientHomeScreen для авторизованного пользователя.
          // ВАЖНО: В настоящем приложении нужно читать роль из Firestore!

          // Для простоты, перенаправляем всех авторизованных на "домашний экран клиента"
          // ВНИМАНИЕ: Если вы добавите логику ролей, этот кусок нужно будет изменить.

          // В случае AuthCheck в app_router, роут будет выглядеть так:
          return const AuthCheckWrapper();
        },
      ),
    );
  }
}


// Вспомогательный виджет, который будет использовать роутер для навигации
// после того, как StreamBuilder в main.dart подтвердит авторизацию.
class AuthCheckWrapper extends StatelessWidget {
  const AuthCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Эта заглушка позволяет использовать AuthCheck для начальной навигации
    // (например, чтобы проверить, является ли пользователь Мастером или Клиентом)
    return Scaffold(
      appBar: AppBar(title: const Text('Загрузка профиля...')),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
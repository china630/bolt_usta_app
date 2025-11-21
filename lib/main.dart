import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Импорт настроек
import 'firebase_options.dart';

// ИСПОЛЬЗУЕМ ПРАВИЛЬНЫЙ РОУТЕР
import 'routes.dart';

// Импорты для проверки авторизации
import 'services/user_service.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Ошибка инициализации Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On-Demand Service App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.amber),
        useMaterial3: true,
      ),

      // Используем генератор маршрутов из routes.dart
      onGenerateRoute: AppRouter.generateRoute,

      // Определяем стартовый экран
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginScreen();
          }

          return const AuthCheckWrapper();
        },
      ),
    );
  }
}

class AuthCheckWrapper extends StatelessWidget {
  const AuthCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final UserService userService = UserService();
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<AppUser>(
      stream: userService.getUserStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;

        // Навигация на основе роли
        switch (user.role) {
          case UserRole.client:
            Future.microtask(() => Navigator.of(context).pushReplacementNamed(Routes.clientHome));
            break;
          case UserRole.master:
            Future.microtask(() => Navigator.of(context).pushReplacementNamed(Routes.masterHome));
            break;
          case UserRole.pendingMaster:
            Future.microtask(() => Navigator.of(context).pushReplacementNamed(Routes.masterVerification, arguments: true));
            break;
          case UserRole.unknown:
          default:
            Future.microtask(() => Navigator.of(context).pushReplacementNamed(Routes.roleSelection));
            break;
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
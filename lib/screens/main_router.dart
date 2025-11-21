import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Импортируем все необходимое для работы с данными
import '../models/user_model.dart'; // Предполагается, что здесь определены AppUser и UserRole
import '../services/user_service.dart';
import '../routes.dart';

// Инициализация сервиса для работы с данными пользователя
final UserService _userService = UserService();

/// Главный роутер, который проверяет статус авторизации и роль пользователя
/// для немедленного перенаправления на соответствующий домашний экран.
class MainRouter extends StatelessWidget {
  const MainRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Слушаем изменения состояния аутентификации
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Отображение индикатора загрузки, пока ждем данных Auth
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        // --- Шаг 1: Пользователь не авторизован ---
        if (user == null) {
          // Перенаправляем на экран входа
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // pushReplacementNamed удаляет MainRouter из стека
            Navigator.of(context).pushReplacementNamed(Routes.login);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // --- Шаг 2: Пользователь авторизован, проверяем его данные (роль) ---
        // Используем UserService для получения данных AppUser, включая роль.
        return StreamBuilder<AppUser>(
          stream: _userService.getUserStream(user.uid),
          builder: (context, userSnapshot) {
            // Отображение индикатора загрузки, пока ждем данных AppUser
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Если произошла ошибка при получении данных пользователя
            if (userSnapshot.hasError || !userSnapshot.hasData) {
              // Если не удалось получить данные AppUser, выходим из системы (на всякий случай)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacementNamed(Routes.login);
              });
              return const Scaffold(
                body: Center(child: Text('Ошибка загрузки данных пользователя. Выход.')),
              );
            }

            final appUser = userSnapshot.data!;

            // --- Шаг 3: Определяем маршрут на основе роли ---
            String nextRoute;

            switch (appUser.role) {
              case UserRole.client:
                nextRoute = Routes.clientHome;
                break;
              case UserRole.master:
                nextRoute = Routes.masterHome;
                break;
              case UserRole.pendingMaster:
              // Если мастер ожидает верификации, направляем его на экран
              // редактирования профиля, где он сможет увидеть свой статус.
                nextRoute = Routes.masterProfileEditor;
                break;
              case UserRole.unknown:
              default:
              // Роль не определена - перенаправляем на выбор роли
                nextRoute = Routes.roleSelection;
                break;
            }

            // Перенаправление происходит один раз, как только получаем роль
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Проверяем, что виджет все еще существует перед навигацией
              if (Navigator.of(context).mounted) {
                Navigator.of(context).pushReplacementNamed(nextRoute);
              }
            });

            // Во время перенаправления показываем заглушку
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}
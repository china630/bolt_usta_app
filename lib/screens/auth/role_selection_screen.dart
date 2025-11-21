import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:on_demand_service_app/services/user_service.dart';
import 'package:on_demand_service_app/models/user_model.dart';
import 'package:on_demand_service_app/routes.dart';

// Инициализируем UserService
final UserService _userService = UserService();

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;
  final user = FirebaseAuth.instance.currentUser;

  // Функция для сохранения роли в Firestore и перенаправления
  Future<void> _selectRole(UserRole role) async {
    if (user == null) {
      // Если пользователя нет (не должен случиться на этом этапе), возвращаемся на логин
      Navigator.of(context).pushReplacementNamed(Routes.login);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ИСПОЛЬЗУЕМ СЕРВИС: Обновляем роль в Firestore по безопасному пути
      await _userService.updateUserRole(
        user!.uid,
        newRole: role,
      );

      // Перенаправление (MainRouter перехватит и отправит на Home или Editor)
      // Возвращаемся к MainRouter, чтобы он заново проверил роль и выполнил pushReplacement
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRouter, (route) => false);

    } catch (e) {
      // Здесь можно показать диалог ошибки
      print('Ошибка при выборе роли: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе роли: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRoleButton({
    required String title,
    required String description,
    required IconData icon,
    required UserRole role,
    required Color color,
  }) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: _isLoading ? null : () => _selectRole(role),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color.shade800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор Роли'),
        automaticallyImplyLeading: false, // Отключаем кнопку "Назад"
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Добро пожаловать!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ваша учетная запись создана. Кем вы хотите быть?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 40),

              // Кнопка для Клиента
              _buildRoleButton(
                title: 'Я Клиент',
                description: 'Мне нужны услуги. Я буду создавать и отслеживать заказы.',
                icon: Icons.person_add_alt_1,
                role: UserRole.client,
                color: Colors.teal,
              ),

              // Кнопка для Мастера
              _buildRoleButton(
                title: 'Я Мастер',
                description: 'Я хочу предоставлять услуги и принимать заказы от клиентов.',
                icon: Icons.handyman,
                role: UserRole.master,
                color: Colors.indigo,
              ),

              const SizedBox(height: 30),

              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
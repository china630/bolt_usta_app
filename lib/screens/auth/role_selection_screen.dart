import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Оставляем, если другие части кода его используют

import '../../services/user_service.dart'; // Импортируем сервис
import '../../models/user_model.dart'; // Импортируем модель для UserRole

// Создаем экземпляр сервиса
final UserService _userService = UserService();

// Импортируем экраны, на которые будем перенаправлять
import 'package:on_demand_service_app/routes.dart';

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
      // Если пользователя нет, перенаправляем на вход
      Navigator.of(context).pushReplacementNamed(Routes.login);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ИСПОЛЬЗУЕМ UserService для обновления роли
      await _userService.updateUserRole(user!.uid, role);

      // Перенаправление в зависимости от роли
      if (role == UserRole.client) {
        Navigator.of(context).pushReplacementNamed(Routes.clientHome);
      } else if (role == UserRole.master) {
        // Мастер должен пройти верификацию перед использованием
        Navigator.of(context).pushReplacementNamed(Routes.masterVerification);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе роли: $e')),
      );
      print('Ошибка при выборе роли: $e');
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: _isLoading ? null : () => _selectRole(role),
          borderRadius: BorderRadius.circular(16),
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
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите Роль'),
        automaticallyImplyLeading: false, // Не позволяем вернуться назад после регистрации
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Добро пожаловать!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueAccent,
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
                role: UserRole.master, // Устанавливаем роль Master
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
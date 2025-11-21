import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bolt_usta_app/services/user_service.dart';
import 'package:bolt_usta_app/models/user_model.dart';
import 'package:bolt_usta_app/routes.dart';

// Создаем экземпляр сервиса
final UserService _userService = UserService();

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _showErrorDialog(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ОК'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Регистрация пользователя в Firebase Authentication
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;

      if (user != null) {
        // 2. ИСПОЛЬЗУЕМ UserService для создания профиля
        // Это гарантирует, что профиль сохраняется в правильной, защищенной коллекции.
        await _userService.createOrUpdateUser(
          uid: user.uid,
          email: user.email!,
          displayName: _nameController.text.trim(),
          role: UserRole.unknown, // Ставим 'unknown', чтобы MainRouter отправил на выбор роли
        );

        // 3. Обновление имени пользователя в Auth (для AppBar)
        await user.updateDisplayName(_nameController.text.trim());

        // После успешной регистрации MainRouter автоматически
        // обнаружит изменения и перенаправит на RoleSelectionScreen.
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRouter, (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'Пароль слишком слабый.';
          break;
        case 'email-already-in-use':
          message = 'Аккаунт с таким email уже существует.';
          break;
        case 'invalid-email':
          message = 'Некорректный формат email.';
          break;
        default:
          message = 'Произошла ошибка регистрации: ${e.message}';
          break;
      }
      await _showErrorDialog(message);
    } catch (e) {
      await _showErrorDialog('Произошла непредвиденная ошибка. Попробуйте еще раз.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Создание аккаунта',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(height: 30),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Ваше Имя',
                    prefixIcon: const Icon(Icons.person, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите ваше имя.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty || !value.contains('@')) {
                      return 'Пожалуйста, введите корректный email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Пароль должен содержать не менее 6 символов.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Подтвердите Пароль',
                    prefixIcon: const Icon(Icons.lock_open, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Пароли не совпадают.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Зарегистрироваться', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),

                // Login Link
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Вернуться на экран входа
                  },
                  child: const Text(
                    'Уже есть аккаунт? Войти',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
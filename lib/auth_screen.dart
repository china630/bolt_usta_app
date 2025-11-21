import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:on_demand_service_app/models/user_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Контроллеры для форм
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Состояние
  bool _isLogin = true; // true = Вход, false = Регистрация
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- Основная функция аутентификации/регистрации ---
  Future<void> _submitAuthForm() async {
    // 1. Проверка валидации формы
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _nameController.text.trim();

    try {
      if (_isLogin) {
        // --- 2. ВХОД (LOGIN) ---
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // --- 3. РЕГИСТРАЦИЯ (SIGN UP) ---
        // Создание пользователя в Firebase Authentication
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Обновление отображаемого имени
        await userCredential.user!.updateDisplayName(displayName);

        // Создание объекта AppUser для записи в Firestore
        final newUser = AppUser(
          uid: userCredential.user!.uid,
          email: email,
          displayName: displayName,
          role: UserRole.client, // По умолчанию все новые пользователи - клиенты
        );

        // Запись данных пользователя в Firestore (коллекция 'users')
        await _firestore.collection('users').doc(newUser.uid).set(newUser.toFirestore());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Регистрация прошла успешно!')),
          );
        }
      }

      // После успешной аутентификации/регистрации, AppRouter в main.dart
      // автоматически перенаправит пользователя.

    } on FirebaseAuthException catch (e) {
      String message = 'Произошла ошибка аутентификации.';
      if (e.code == 'weak-password') {
        message = 'Слишком слабый пароль.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Этот email уже используется.';
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Неверный email или пароль.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Непредвиденная ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Виджет для переключения режима Вход/Регистрация ---
  Widget _buildToggleSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'У вас еще нет аккаунта?' : 'Уже зарегистрированы?',
          style: TextStyle(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _isLogin = !_isLogin;
            });
          },
          child: Text(
            _isLogin ? 'Создать аккаунт' : 'Войти',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход в Bolt Usta' : 'Регистрация'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                // Логотип или заголовок приложения
                Text(
                  _isLogin ? 'С возвращением!' : 'Станьте клиентом',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 30),

                // Поле Имя (Только для регистрации)
                if (!_isLogin)
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ваше Имя',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      prefixIcon: Icon(Icons.person),
                    ),
                    keyboardType: TextInputType.name,
                    validator: (value) {
                      if (!_isLogin && (value == null || value.isEmpty || value.trim().length < 3)) {
                        return 'Пожалуйста, введите корректное имя.';
                      }
                      return null;
                    },
                  ),
                if (!_isLogin) const SizedBox(height: 15),

                // Поле Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Введите корректный Email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Поле Пароль
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return 'Пароль должен быть не менее 6 символов.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Кнопка Вход/Регистрация
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitAuthForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text(
                    _isLogin ? 'Войти' : 'Зарегистрироваться',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 20),

                // Переключатель режима
                _buildToggleSwitch(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
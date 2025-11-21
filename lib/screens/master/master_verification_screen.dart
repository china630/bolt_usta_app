import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes.dart'; // Предполагаемый путь к маршрутам
import '../../services/user_service.dart'; // Импортируем UserService
import '../../models/user_model.dart'; // Импортируем UserRole

// Инициализируем сервис пользователя
final UserService _userService = UserService();

class MasterVerificationScreen extends StatefulWidget {
  // Флаг, чтобы показать, что заявка на рассмотрении
  final bool isAwaiting;

  const MasterVerificationScreen({super.key, this.isAwaiting = false});

  @override
  State<MasterVerificationScreen> createState() => _MasterVerificationScreenState();
}

class _MasterVerificationScreenState extends State<MasterVerificationScreen> {
  final _reasonController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _auth = FirebaseAuth.instance;

  // Список всех доступных специализаций
  final List<String> _allSpecializations = const [
    'Сантехника',
    'Электрика',
    'Уборка',
    'Ремонт техники',
    'Сборка мебели',
    'Кондиционеры',
    'Холодильники',
    'Посудомоечные машины',
    'Стиральные машины',
    'Системы отопления',
  ];

  List<String> _selectedSpecializations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Устанавливаем текущее имя пользователя из Firebase Auth
    _nameController.text = _auth.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- Основная логика отправки заявки ---
  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate() || _selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите специализации и заполните все поля.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final userId = _auth.currentUser!.uid;

    try {
      // 1. Обновляем отображаемое имя (на случай, если пользователь его поменял)
      await _userService.updateDisplayName(userId, _nameController.text.trim());

      // 2. Отправляем заявку на верификацию мастера
      await _userService.submitMasterVerification(
        userId: userId,
        specializations: _selectedSpecializations,
        reason: _reasonController.text.trim(),
      );

      // 3. Успех: Сообщаем пользователю и переходим на главный экран.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка отправлена на рассмотрение!'),
            backgroundColor: Colors.green,
          ),
        );
        // Перенаправляем на главный экран. Там должна сработать логика,
        // которая увидит роль pendingMaster и покажет Awaiting UI.
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки заявки: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI для режима ожидания (заявка отправлена) ---
  Widget _buildAwaitingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time_filled, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'Ваша заявка на рассмотрении',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Мы обрабатываем вашу информацию и сообщим о решении в ближайшее время.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // Выход из аккаунта
                _auth.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (route) => false);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Выйти'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI для формы верификации ---
  Widget _buildVerificationForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Поле для имени
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ваше отображаемое имя',
                hintText: 'Иван Иванов',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Пожалуйста, введите имя.';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),
            // Выбор специализаций
            const Text(
              'Выберите свои специализации:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _allSpecializations.map((spec) {
                final isSelected = _selectedSpecializations.contains(spec);
                return FilterChip(
                  label: Text(spec),
                  selected: isSelected,
                  backgroundColor: isSelected ? Colors.teal.shade50 : Colors.grey.shade100,
                  selectedColor: Colors.teal.shade300,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedSpecializations.add(spec);
                      } else {
                        _selectedSpecializations.remove(spec);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Поле для описания опыта/причины
            TextFormField(
              controller: _reasonController,
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Опишите свой опыт и квалификацию',
                hintText: 'Я более 10 лет занимаюсь ремонтом электрики и имею сертификат...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              validator: (value) {
                if (value == null || value.isEmpty || value.length < 50) {
                  return 'Пожалуйста, опишите свой опыт (минимум 50 символов).';
                }
                return null;
              },
            ),

            const SizedBox(height: 40),

            // Кнопка отправки
            ElevatedButton(
              onPressed: _isLoading ? null : _submitVerification,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                'Отправить Заявку',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            // Кнопка выхода
            Center(
              child: TextButton(
                onPressed: () => _auth.signOut(),
                child: const Text('Выйти', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAwaiting ? 'Заявка на рассмотрении' : 'Верификация Мастера'),
        backgroundColor: widget.isAwaiting ? Colors.amber.shade700 : Colors.teal.shade600,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Отключаем кнопку "Назад"
      ),
      body: widget.isAwaiting ? _buildAwaitingUI() : _buildVerificationForm(context),
    );
  }
}
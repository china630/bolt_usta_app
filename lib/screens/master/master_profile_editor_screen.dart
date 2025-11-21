import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Список доступных категорий услуг
const List<String> availableCategories = [
  'Сантехника',
  'Электрика',
  'Сборка мебели',
  'Ремонт техники',
  'Уборка',
  'Ремонт автомобилей',
  'IT-услуги',
];

class MasterProfileEditorScreen extends StatefulWidget {
  const MasterProfileEditorScreen({super.key});

  @override
  State<MasterProfileEditorScreen> createState() => _MasterProfileEditorScreenState();
}

class _MasterProfileEditorScreenState extends State<MasterProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  // Данные профиля
  String _name = '';
  List<String> _selectedCategories = [];
  String _availabilityStatus = 'offline'; // 'online' или 'offline'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // Загрузка текущих данных профиля из Firestore
  Future<void> _loadProfileData() async {
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _name = data['name'] ?? 'Мастер';
          // Проверяем, что categories существует и является List<String>
          if (data['categories'] is List) {
            _selectedCategories = List<String>.from(data['categories']);
          }
          _availabilityStatus = data['availability_status'] ?? 'offline';
        });
      }
    } catch (e) {
      // Игнорируем ошибки загрузки, используем дефолтные значения
      print('Error loading profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Сохранение данных профиля в Firestore
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _name,
        'categories': _selectedCategories,
        'availability_status': _availabilityStatus,
        'role': 'master', // Подтверждаем роль
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль успешно сохранен!')),
      );

      // После сохранения можно вернуться назад или перейти на главный экран мастера
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Виджет для выбора категорий
  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Специализация (Выберите одну или несколько):',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          children: availableCategories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              selectedColor: Colors.indigo.shade100,
              checkmarkColor: Colors.indigo,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.removeWhere((c) => c == category);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_selectedCategories.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Пожалуйста, выберите хотя бы одну категорию.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать Профиль Мастера'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Настройте свой рабочий профиль',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 30),

              // Имя/Ник
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: 'Ваше имя или Никнейм',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  prefixIcon: Icon(Icons.badge),
                ),
                onChanged: (value) => _name = value.trim(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Имя не может быть пустым';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Выбор Категорий
              _buildCategorySelector(),
              const SizedBox(height: 30),

              // Статус Доступности
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Статус Доступности:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ListTile(
                        leading: Icon(Icons.circle, color: _availabilityStatus == 'online' ? Colors.green : Colors.grey),
                        title: const Text('Я онлайн (Готов принимать заказы)'),
                        trailing: Radio<String>(
                          value: 'online',
                          groupValue: _availabilityStatus,
                          onChanged: (String? value) {
                            setState(() {
                              _availabilityStatus = value!;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.circle, color: _availabilityStatus == 'offline' ? Colors.red : Colors.grey),
                        title: const Text('Я оффлайн (Временно не доступен)'),
                        trailing: Radio<String>(
                          value: 'offline',
                          groupValue: _availabilityStatus,
                          onChanged: (String? value) {
                            setState(() {
                              _availabilityStatus = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Кнопка сохранения
              ElevatedButton.icon(
                onPressed: (_isLoading || _selectedCategories.isEmpty) ? null : _saveProfile,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить Профиль', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Список доступных категорий услуг (должен быть общим для всего приложения)
const List<String> availableCategories = [
  'Сантехника',
  'Электрика',
  'Сборка мебели',
  'Ремонт техники',
  'Уборка',
  'Ремонт автомобилей',
  'IT-услуги',
];

class MasterProfileSettingsScreen extends StatefulWidget {
  const MasterProfileSettingsScreen({super.key});

  @override
  State<MasterProfileSettingsScreen> createState() => _MasterProfileSettingsScreenState();
}

class _MasterProfileSettingsScreenState extends State<MasterProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  // Данные профиля
  String _name = '';
  List<String> _selectedCategories = [];
  String _availabilityStatus = 'offline'; // 'online' или 'offline'
  bool _isLoading = true;
  String _initialName = ''; // Для проверки изменений

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // Загрузка текущих данных профиля из Firestore
  Future<void> _loadProfileData() async {
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _name = data['name'] ?? 'Мастер';
            _initialName = _name;
            if (data['categories'] is List) {
              _selectedCategories = List<String>.from(data['categories']);
            }
            _availabilityStatus = data['availability_status'] ?? 'offline';
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Сохранение данных профиля в Firestore
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите хотя бы одну категорию.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Обновляем только измененные поля
      final updateData = <String, dynamic>{
        'categories': _selectedCategories,
        'availability_status': _availabilityStatus,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (_name != _initialName) {
        updateData['name'] = _name;
      }

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки профиля обновлены.')),
        );
      }
      _initialName = _name; // Обновляем начальное имя после сохранения

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
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

  // Виджет для выбора категорий
  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Специализация (Категории, в которых вы работаете):',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки Профиля Мастера'),
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
                'Управление Рабочими Параметрами',
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

              // Статус Доступности (Онлайн/Оффлайн)
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
                label: const Text('Сохранить Настройки', style: TextStyle(fontSize: 18)),
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
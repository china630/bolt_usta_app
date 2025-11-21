import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:on_demand_service_app/utils/app_router.dart';


// Список доступных категорий
const List<String> categories = [
  'Сантехника',
  'Электрика',
  'Уборка',
  'Ремонт техники',
  'Сборка мебели',
  'Другое'
];

class ClientOrderCreationScreen extends StatefulWidget {
  const ClientOrderCreationScreen({super.key});

  @override
  State<ClientOrderCreationScreen> createState() => _ClientOrderCreationScreenState();
}

class _ClientOrderCreationScreenState extends State<ClientOrderCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  // Данные заказа
  String? _selectedCategory;
  String? _description;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  // Временные контроллеры для ввода координат
  // Используем примерные координаты Баку для демонстрации
  final TextEditingController _latController = TextEditingController(text: '40.3855');
  final TextEditingController _lonController = TextEditingController(text: '49.8350');

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  // Функция для создания заказа
  Future<void> _createOrder() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Убедимся, что координаты введены корректно
      _latitude = double.tryParse(_latController.text);
      _longitude = double.tryParse(_lonController.text);

      if (_latitude == null || _longitude == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пожалуйста, введите корректные координаты.')),
          );
        }
        return;
      }

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка аутентификации. Пользователь не найден.')),
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final newOrder = {
          'client_id': user!.uid,
          'category': _selectedCategory,
          'description': _description,
          'status': 'pending', // Начальный статус
          'created_at': FieldValue.serverTimestamp(),
          'location': GeoPoint(_latitude!, _longitude!),
        };

        // Добавляем документ в коллекцию 'orders'
        final docRef = await FirebaseFirestore.instance.collection('orders').add(newOrder);

        if (mounted) {
          // Показываем сообщение об успехе
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заказ успешно создан! Начинаем поиск мастера...')),
          );

          // Переход на экран ожидания
          Navigator.of(context).pushReplacementNamed(
            AppRouter.clientOrderWait,
            arguments: docRef.id,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при создании заказа: $e')),
          );
        }
        print('Error creating order: $e'); // Логирование ошибки
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание Нового Заказа'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Что нужно сделать?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 20),

              // 1. Выбор Категории
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Категория Услуги',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedCategory,
                hint: const Text('Выберите категорию'),
                items: categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Пожалуйста, выберите категорию.';
                  }
                  return null;
                },
                onSaved: (value) => _selectedCategory = value,
              ),
              const SizedBox(height: 15),

              // 2. Детальное Описание
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Детальное Описание Заказа',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 20) {
                    return 'Описание должно быть не менее 20 символов.';
                  }
                  return null;
                },
                onSaved: (value) => _description = value,
              ),
              const SizedBox(height: 15),

              // 3. Координаты (Местоположение)
              const Text(
                'Местоположение (Координаты)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Широта (Lat)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || double.tryParse(value) == null) {
                          return 'Введите число.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lonController,
                      decoration: const InputDecoration(
                        labelText: 'Долгота (Lon)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || double.tryParse(value) == null) {
                          return 'Введите число.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Кнопка Отправки
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createOrder,
                icon: _isLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
                    : const Icon(Icons.send),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    _isLoading ? 'Создание...' : 'Найти Мастера',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
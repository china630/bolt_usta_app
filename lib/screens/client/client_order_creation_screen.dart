import 'package:flutter/material.dart';
import 'package:on_demand_service_app/routes.dart';
import 'package:geolocator/geolocator.dart'; // Добавляем импорт для типа Position
import '../../services/order_service.dart';
// ИСПРАВЛЕННЫЙ ПУТЬ
import '../../services/location_service.dart';

// Инициализируем сервисы
final OrderService _orderService = OrderService();
final LocationService _locationService = LocationService();

class ClientOrderCreationScreen extends StatefulWidget {
  const ClientOrderCreationScreen({super.key});

  @override
  State<ClientOrderCreationScreen> createState() => _ClientOrderCreationScreenState();
}

class _ClientOrderCreationScreenState extends State<ClientOrderCreationScreen> {
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedCategory;
  bool _isLoading = false;

  // Список доступных категорий услуг
  final List<String> _categories = [
    'Сантехника',
    'Электрика',
    'Уборка',
    'Ремонт техники',
    'Сборка мебели',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите категорию и заполните описание заказа.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. ПОЛУЧАЕМ КООРДИНАТЫ
      // Этот метод автоматически запросит разрешение, если это необходимо
      final Position position = await _locationService.getCurrentLocation();

      // 2. ОТПРАВЛЯЕМ ЗАКАЗ С КООРДИНАТАМИ
      final String orderId = await _orderService.createOrder(
        category: _selectedCategory!,
        description: _descriptionController.text,
        // Передаем широту и долготу, полученные от сервиса
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // 3. Успешное завершение
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Заказ "$orderId" успешно создан и ожидает мастера.'),
          backgroundColor: Colors.teal,
        ),
      );

      // Возвращаемся на главный экран клиента
      if (mounted) {
        Navigator.of(context).popAndPushNamed(Routes.clientHome);
      }
    } catch (e) {
      // 4. Обработка ошибок (например, если пользователь не дал разрешение)
      print('Ошибка при создании заказа: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание Нового Заказа'),
        backgroundColor: Colors.teal.shade400,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Выбор категории
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.teal.shade300, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Категория услуги',
                    border: InputBorder.none, // Убираем стандартную рамку
                    contentPadding: EdgeInsets.zero,
                  ),
                  value: _selectedCategory,
                  hint: const Text('Выберите тип работы'),
                  isExpanded: true,
                  items: _categories.map((String category) {
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
                      return 'Пожалуйста, выберите категорию';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Поле для описания
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Описание проблемы (подробно)',
                  hintText: 'Опишите проблему, которая требует решения...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.teal.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите описание';
                  }
                  if (value.length < 20) {
                    return 'Описание должно быть не менее 20 символов.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Кнопка создания заказа
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  'Создать Заказ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              // Информационное сообщение
              Center(
                child: Text(
                  'Ваше текущее местоположение будет отправлено мастеру.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
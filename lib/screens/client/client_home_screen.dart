import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Импортируем необходимые сервисы и модели
import '../../routes.dart'; // Маршруты
import '../../models/order_model.dart'; // Модель заказа
import '../../models/user_model.dart'; // Модель пользователя
import '../../services/order_service.dart'; // Сервис заказа
import '../../services/user_service.dart'; // Сервис пользователя
import '../../components/order_list_item.dart'; // Компонент элемента списка заказа

// Инициализируем сервисы (для простоты)
final OrderService _orderService = OrderService();
final UserService _userService = UserService();

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  // Получаем ID текущего пользователя. Он не может быть null, так как мы находимся на этом экране.
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Stream для получения данных текущего пользователя в реальном времени
  Stream<AppUser>? _userStream;

  @override
  void initState() {
    super.initState();
    if (currentUserId != null) {
      // Подписываемся на поток данных пользователя (для отображения имени в AppBar)
      _userStream = _userService.getUserStream(currentUserId!);
    }
  }

  // --- Навигация и логика кнопки действия ---
  void _handleOrderAction(OrderModel order) {
    if (order.status == OrderStatus.completed || order.status == OrderStatus.clientCompleted) {
      // Если заказ завершен, можно предложить оставить отзыв (пока заглушка)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Функция оценки и отзыва пока не реализована.')),
      );
      // В будущем можно добавить:
      // Navigator.of(context).pushNamed(Routes.clientOrderReview, arguments: order);
    } else if (order.status == OrderStatus.cancelled) {
      // Отмененный заказ, возможно, просто убрать из активных или показать детали
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот заказ отменен и больше не активен.')),
      );
    }
    else {
      // Для всех активных статусов (new, accepted, arrived, inProgress) - переход на экран трекинга
      Navigator.of(context).pushNamed(
        Routes.clientOrderTracking,
        arguments: order,
      );
    }
  }

  // --- Виджет для отображения одного элемента заказа с помощью OrderListItem ---
  Widget _buildOrderItem(OrderModel order) {
    // Определяем текст и цвет кнопки в зависимости от статуса
    String actionTitle;
    Color actionColor;

    switch (order.status) {
      case OrderStatus.newOrder:
      case OrderStatus.accepted:
      case OrderStatus.arrived:
      case OrderStatus.inProgress:
        actionTitle = 'Отследить заказ';
        actionColor = Colors.teal;
        break;
      case OrderStatus.clientCompleted:
      case OrderStatus.completed:
        actionTitle = 'Оставить отзыв';
        actionColor = Colors.orange;
        break;
      case OrderStatus.cancelled:
        actionTitle = 'Посмотреть детали';
        actionColor = Colors.grey;
        break;
    }

    return OrderListItem(
      order: order,
      isMasterView: false, // Это экран клиента
      onAction: () => _handleOrderAction(order),
      actionButtonTitle: actionTitle,
      actionButtonColor: actionColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Center(child: Text('Ошибка аутентификации'));
    }

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<AppUser>(
          stream: _userStream,
          builder: (context, snapshot) {
            String userName = 'Клиент';
            if (snapshot.hasData) {
              userName = snapshot.data!.displayName.split(' ')[0]; // Используем только первое слово имени
            }
            return Text('Здравствуйте, $userName!');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              // После выхода AuthWrapper автоматически перенаправит на экран входа
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Ваши активные и последние заказы',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // --- Кнопка создания заказа ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(Routes.clientOrderCreation);
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Создать новый заказ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50), // Делаем кнопку широкой
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              // Получаем все заказы текущего клиента
              stream: _orderService.getOrdersForUser(currentUserId!, false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Ошибка загрузки заказов: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_turned_in_not, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          const Text(
                            'У вас пока нет активных заказов.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          // Кнопка создания заказа уже есть выше, поэтому эту убираем
                          // чтобы избежать дублирования
                        ],
                      ),
                    ),
                  );
                }

                // Отображение списка заказов
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderItem(orders[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
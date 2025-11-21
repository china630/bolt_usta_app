import 'dart:async'; // Импортируем для StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bolt_usta_app/models/order_model.dart';
import 'package:bolt_usta_app/models/user_model.dart';
import 'package:bolt_usta_app/services/order_service.dart';
import 'package:bolt_usta_app/services/user_service.dart';
import 'package:bolt_usta_app/routes.dart';

// Инициализация сервисов
final OrderService _orderService = OrderService();
final UserService _userService = UserService();

/// Главный экран для Мастера.
/// Содержит две вкладки: "Новые заказы" и "Мои заказы".
class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  // Получаем ID текущего пользователя. Он не может быть null на этом экране.
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Stream для получения данных текущего пользователя в реальном времени
  Stream<AppUser>? _userStream;

  // --- Поля для симуляции Push-уведомлений ---
  StreamSubscription<List<OrderModel>>? _newOrdersSubscription;
  List<OrderModel> _previousNewOrders = [];

  @override
  void initState() {
    super.initState();
    if (currentUserId != null) {
      // Подписываемся на поток данных пользователя (для проверки статуса верификации)
      _userStream = _userService.getUserStream(currentUserId!);
      // Начинаем слушать новые заказы для симуляции уведомлений
      _listenForNewOrders();
    }
  }

  @override
  void dispose() {
    // Отменяем подписку при выходе с экрана для предотвращения утечек памяти
    _newOrdersSubscription?.cancel();
    super.dispose();
  }

  /// Устанавливает подписку на поток новых заказов и симулирует push-уведомление.
  void _listenForNewOrders() {
    _newOrdersSubscription = _orderService.getNewOrdersStream().listen((currentOrders) {
      // Игнорируем первый вызов (когда _previousNewOrders пуст), но сохраняем текущие заказы.
      // Начинаем проверять только после первого успешного получения данных.
      if (_previousNewOrders.isNotEmpty) {
        // Проверяем, появились ли новые заказы
        // Новый заказ появился, если текущий список длиннее
        if (currentOrders.length > _previousNewOrders.length) {
          // Находим новые заказы, которых не было в предыдущем списке (сравниваем по ID)
          final newOrders = currentOrders.where((order) {
            return !_previousNewOrders.any((prevOrder) => prevOrder.id == order.id);
          }).toList();

          if (newOrders.isNotEmpty) {
            // Симулируем Push-уведомление, используя первый найденный новый заказ
            _showNewOrderNotification(newOrders.first);
          }
        }
      }

      // Обновляем предыдущий список заказов для следующей проверки
      _previousNewOrders = currentOrders;
    });
  }

  /// Отображает SnackBar как симуляцию Push-уведомления.
  void _showNewOrderNotification(OrderModel newOrder) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔔 Новый заказ доступен! Категория: ${newOrder.category}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.pink.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Смотреть',
          textColor: Colors.white,
          onPressed: () {
            // Переключаемся на вкладку "Новые Заказы" (индекс 0)
            DefaultTabController.of(context)?.animateTo(0);
          },
        ),
      ),
    );
  }

  /// Вспомогательный метод для построения списка заказов
  Widget _buildOrderList(Stream<List<OrderModel>> orderStream, bool isNewOrderTab) {
    return StreamBuilder<List<OrderModel>>(
      stream: orderStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          String message = isNewOrderTab
              ? 'В данный момент новых заказов нет.'
              : 'У вас пока нет активных заказов.';
          IconData icon = isNewOrderTab ? Icons.assignment_late_outlined : Icons.checklist_rtl;
          Color color = isNewOrderTab ? Colors.teal.shade200 : Colors.indigo.shade200;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 80, color: color),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
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
            return _buildOrderItem(orders[index], isNewOrderTab);
          },
        );
      },
    );
  }


  /// Вспомогательный метод для построения элемента списка заказа
  Widget _buildOrderItem(OrderModel order, bool isNewOrder) {
    // В зависимости от вкладки, используем разную логику для onTap
    final VoidCallback? onTap = isNewOrder
        ? () {
      // Принять заказ
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Принять Заказ?'),
          content: Text('Вы уверены, что хотите принять заказ: "${order.category}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Закрываем диалог
                try {
                  await _orderService.acceptOrder(order.id!, currentUserId!);
                  // Перенаправляем на экран карты для этого заказа
                  if (mounted) {
                    // Создаем копию модели с новым статусом, чтобы избежать ошибок
                    final acceptedOrder = order.copyWith(
                      masterId: currentUserId,
                      status: OrderStatus.accepted,
                    );
                    Navigator.of(context).pushNamed(
                      Routes.masterOrderMapView,
                      arguments: acceptedOrder,
                    );
                  }
                } catch (e) {
                  // Показываем ошибку
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка при принятии заказа: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Принять'),
            ),
          ],
        ),
      );
    }
        : () {
      // Перейти к отслеживанию заказа (для принятых/активных заказов)
      Navigator.of(context).pushNamed(
        Routes.masterOrderMapView,
        arguments: order,
      );
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isNewOrder ? Colors.teal : Colors.indigo,
          child: Icon(isNewOrder ? Icons.star : Icons.work, color: Colors.white),
        ),
        title: Text(
          order.category,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              if (!isNewOrder) // Показываем статус только для активных
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: order.status.color),
                    const SizedBox(width: 4),
                    Text(
                      order.status.localizedName,
                      style: TextStyle(
                        color: order.status.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        trailing: Icon(isNewOrder ? Icons.arrow_forward_ios : Icons.map_outlined),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      // Это не должно произойти, но на всякий случай
      return const Center(child: Text('Ошибка: Пользователь не авторизован.'));
    }

    // Оборачиваем StreamBuilder в DefaultTabController, чтобы иметь доступ к TabController
    return DefaultTabController(
      length: 2,
      child: StreamBuilder<AppUser>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;

          // Проверка верификации
          if (user == null || user.role == UserRole.pendingMaster) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Профиль Мастера'),
                backgroundColor: Colors.orange,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Выход',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                            Routes.mainRouter, (route) => false);
                      }
                    },
                  ),
                ],
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gpp_maybe, size: 80, color: Colors.orange.shade300),
                      const SizedBox(height: 20),
                      const Text(
                        'Ваша заявка на роль Мастера находится на рассмотрении.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Пожалуйста, заполните ваш профиль. Мы уведомим вас о решении.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_pin_circle_outlined),
                        label: const Text('Заполнить/Проверить Профиль'),
                        onPressed: () {
                          Navigator.of(context).pushNamed(Routes.masterProfileEditor);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Основной экран для верифицированного мастера
          return Scaffold(
            appBar: AppBar(
              title: Text('Мастер: ${user.displayName}'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'Новые Заказы', icon: Icon(Icons.assignment_outlined)),
                  Tab(text: 'Мои Активные Заказы', icon: Icon(Icons.checklist_rtl)),
                ],
              ),
              actions: [
                // Кнопка для редактирования профиля
                IconButton(
                  icon: const Icon(Icons.person_pin_circle_outlined),
                  tooltip: 'Редактировать Профиль',
                  onPressed: () {
                    Navigator.of(context).pushNamed(Routes.masterProfileEditor);
                  },
                ),
                // Кнопка выхода
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Выход',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.mainRouter, (route) => false);
                    }
                  },
                ),
              ],
            ),
            body: TabBarView(
              children: [
                // 1. Вкладка "Новые Заказы"
                _buildOrderList(_orderService.getNewOrdersStream(), true),

                // 2. Вкладка "Мои Активные Заказы" (Принятые + В работе + Прибытие)
                // Используем isNewOrderTab: false, чтобы показать активные заказы и другую логику onTap
                _buildOrderList(_orderService.getOrdersForUser(currentUserId!, true), false),
              ],
            ),
          );
        },
      ),
    );
  }
}
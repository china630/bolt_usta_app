import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

// Глобальные переменные, предоставляемые средой Canvas.
String get _appId {
  try {
    // ignore: undefined_identifier
    return __app_id;
  } catch (e) {
    return 'default-app-id';
  }
}

/// Сервис для взаимодействия с коллекцией заказов (orders) в Firestore.
class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Базовый путь для ПУБЛИЧНЫХ данных заказов
  // Используется: /artifacts/{appId}/public/data/orders/{orderId}
  CollectionReference<Map<String, dynamic>> get _ordersCollection {
    // Внимание: _ordersCollection используется для публичных данных, чтобы клиенты и мастера могли видеть заказы друг друга.
    return _db.collection('artifacts/$_appId/public/data/orders');
  }

  // --- 1. Создание нового заказа ---
  Future<String> createOrder(OrderModel order) async {
    try {
      // Добавляем поле createdAt для сортировки
      final orderData = order.toFirestore();
      orderData['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _ordersCollection.add(orderData);
      return docRef.id;
    } catch (e) {
      print('Ошибка при создании заказа: $e');
      rethrow;
    }
  }

  // --- 2. Получение заказа по ID (разовое) ---
  Future<OrderModel> getOrder(String orderId) async {
    try {
      final doc = await _ordersCollection.doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        return OrderModel.fromFirestore(doc);
      }
      throw Exception('Заказ с ID $orderId не найден.');
    } catch (e) {
      print('Ошибка при получении заказа: $e');
      rethrow;
    }
  }

  // --- 3. Обновление статуса заказа (общее) ---
  /// Используется для простых изменений статуса (например, 'arrived', 'inProgress')
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'status': newStatus.name,
      });
      print('Статус заказа $orderId обновлен на ${newStatus.name}');
    } catch (e) {
      print('Ошибка при обновлении статуса заказа $orderId: $e');
      rethrow;
    }
  }

  // --- 4. Назначение мастера на заказ ---
  Future<void> updateMasterAssignment({
    required String orderId,
    required String masterId,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'masterId': masterId,
        'status': OrderStatus.accepted.name, // Автоматически переводим в 'accepted'
      });
    } catch (e) {
      print('Ошибка при назначении мастера на заказ $orderId: $e');
      rethrow;
    }
  }

  // --- 5. Обновление местоположения мастера ---
  Future<void> updateMasterLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'masterLocation': {
          'latitude': latitude,
          'longitude': longitude,
        },
        // Обновляем время, чтобы клиент видел, когда мастер в последний раз публиковал координаты
        'masterLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Ошибка при обновлении местоположения мастера для заказа $orderId: $e');
      // В этом случае можно проигнорировать, чтобы не сбивать основной процесс трекинга
    }
  }

  // --- 6. Подтверждение выполнения заказа клиентом ---
  /// Переводит статус в 'clientCompleted', готовит к отзыву.
  Future<void> clientConfirmedCompletion(String orderId) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'status': OrderStatus.clientCompleted.name,
      });
      print('Заказ $orderId подтвержден клиентом.');
    } catch (e) {
      print('Ошибка при подтверждении выполнения заказа клиентом $orderId: $e');
      rethrow;
    }
  }

  // --- 7. Окончательное завершение заказа мастером ---
  /// Переводит статус в 'completed'. Используется после подтверждения клиента и, возможно, оплаты.
  Future<void> masterFinalComplete(String orderId) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'status': OrderStatus.completed.name,
        // Здесь можно добавить логику, например, обновление рейтинга мастера (пока заглушка)
      });
      print('Заказ $orderId окончательно завершен мастером.');
    } catch (e) {
      print('Ошибка при окончательном завершении заказа $orderId: $e');
      rethrow;
    }
  }

  // --- 8. Отмена заказа ---
  /// Позволяет отменить заказ. Может использоваться клиентом до начала работы или мастером в случае форс-мажора.
  Future<void> cancelOrder(String orderId) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'status': OrderStatus.cancelled.name,
      });
      print('Заказ $orderId отменен.');
    } catch (e) {
      print('Ошибка при отмене заказа $orderId: $e');
      rethrow;
    }
  }

  // --- 9. Получение списка заказов для Клиента или Мастера ---
  Stream<List<OrderModel>> getOrdersForUser(String userId, bool isMaster) {
    Query query = _ordersCollection;

    // Фильтр: если это мастер, ищем его ID, если клиент - его ID
    if (isMaster) {
      query = query.where('masterId', isEqualTo: userId);
    } else {
      query = query.where('clientId', isEqualTo: userId);
    }

    // Сортировка по времени создания (новые сверху)
    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();
    });
  }

  // --- 10. Получение потока новых заказов (для мастеров) ---
  Stream<List<OrderModel>> getNewOrdersStream() {
    Query query = _ordersCollection
    // Фильтруем только по статусу 'newOrder'
        .where('status', isEqualTo: OrderStatus.newOrder.name)
        .orderBy('createdAt', descending: true); // Сортировка по времени создания

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();
    });
  }


  // --- 11. Сохранение отзыва/рейтинга и окончательное завершение заказа ---
  /// Сохраняет отзыв/рейтинг мастера и переводит заказ в окончательный статус 'completed'.
  Future<void> rateMasterAndCompleteOrder({
    required String orderId,
    required double rating,
    String? feedback,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        // Сохраняем отзыв клиента
        'masterRating': rating, // Клиент оценивает мастера
        'masterFeedback': feedback,
        // Окончательно завершаем заказ (этот статус можно использовать как триггер для обновления среднего рейтинга мастера)
        'status': OrderStatus.completed.name,
      });

      // Здесь в реальном приложении была бы логика обновления среднего рейтинга мастера
      print('Заказ $orderId завершен. Рейтинг $rating, Отзыв: $feedback');

    } catch (e) {
      print('Ошибка при завершении заказа и сохранении отзыва $orderId: $e');
      rethrow;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Перечисление возможных статусов заказа.
enum OrderStatus {
  newOrder(0xFF009688, 'Новый'), // Teal
  accepted(0xFF2196F3, 'Принят Мастером'), // Blue
  arrived(0xFF4CAF50, 'Мастер Прибыл'), // Green
  inProgress(0xFFFF9800, 'В Работе'), // Orange
  // НОВЫЙ СТАТУС: Клиент подтвердил выполнение, готов оставить отзыв
  clientCompleted(0xFF795548, 'Клиент Подтвердил'), // Brown
  completed(0xFF673AB7, 'Завершен'), // Deep Purple - Окончательный статус после оплаты/отзыва
  cancelled(0xFFF44336, 'Отменен'); // Red

  // Цвет для отображения в UI
  final int colorValue;
  // Заголовок для отображения в UI
  final String displayTitle;

  const OrderStatus(this.colorValue, this.displayTitle);
}

/// Расширение для преобразования строки в enum и обратно
extension OrderStatusExtension on OrderStatus {
  String get name => toString().split('.').last;

  Color get color => Color(colorValue);
  String get localizedName => displayTitle;

  static OrderStatus fromName(String name) {
    try {
      return OrderStatus.values.firstWhere((e) => e.name == name);
    } catch (e) {
      // Если статус не найден, по умолчанию используем newOrder
      return OrderStatus.newOrder;
    }
  }
}

// --- Класс OrderModel: Модель данных заказа ---
class OrderModel {
  final String id;
  final String clientId;
  final String category;
  final String description;
  // Местоположение клиента
  final double latitude;
  final double longitude;
  final OrderStatus status;
  final String? masterId;
  // Местоположение мастера (обновляется в реальном времени)
  final double? masterLatitude;
  final double? masterLongitude;
  // Время последнего обновления местоположения мастера
  final DateTime? masterLocationUpdatedAt;

  // Поля для ОТЗЫВА О КЛИЕНТЕ (от мастера)
  final double? clientRating;
  final String? clientFeedback;

  // НОВЫЕ ПОЛЯ для ОТЗЫВА О МАСТЕРЕ (от клиента)
  final double? masterRating;
  final String? masterFeedback;

  OrderModel({
    required this.id,
    required this.clientId,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.masterId,
    this.masterLatitude,
    this.masterLongitude,
    this.masterLocationUpdatedAt,
    // Поля для оценки клиента
    this.clientRating,
    this.clientFeedback,
    // Поля для оценки мастера (НОВЫЕ)
    this.masterRating,
    this.masterFeedback,
  });

  // --- Фабричный конструктор для создания объекта из документа Firestore ---
  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Парсинг времени обновления местоположения мастера
    final Timestamp? masterLocationTs = data['masterLocationUpdatedAt'] as Timestamp?;

    // Примечание: В вашем исходном коде координаты были плоскими полями.
    // Если они хранятся как вложенные Map, этот парсинг нужно будет изменить.
    return OrderModel(
      id: doc.id,
      clientId: data['clientId'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatusExtension.fromName(data['status'] as String? ?? ''),
      masterId: data['masterId'] as String?,
      masterLatitude: (data['masterLatitude'] as num?)?.toDouble(),
      masterLongitude: (data['masterLongitude'] as num?)?.toDouble(),
      masterLocationUpdatedAt: masterLocationTs?.toDate(),
      // Поля для оценки клиента (ПАРСИНГ СУЩЕСТВУЮЩИХ ПОЛЕЙ)
      clientRating: (data['clientRating'] as num?)?.toDouble(),
      clientFeedback: data['clientFeedback'] as String?,
      // Поля для оценки мастера (ПАРСИНГ НОВЫХ ПОЛЕЙ)
      masterRating: (data['masterRating'] as num?)?.toDouble(),
      masterFeedback: data['masterFeedback'] as String?,
    );
  }

  /// Метод для преобразования объекта в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'category': category,
      'description': description,
      'latitude': latitude, // Сохраняем как плоское поле (согласно исходной логике)
      'longitude': longitude,
      'status': status.name,
      'masterId': masterId,
      'masterLatitude': masterLatitude,
      'masterLongitude': masterLongitude,
      // masterLocationUpdatedAt обновляется только при трекинге (используется FieldValue.serverTimestamp())
      // Поля для оценки клиента
      'clientRating': clientRating,
      'clientFeedback': clientFeedback,
      // Поля для оценки мастера (НОВЫЕ)
      'masterRating': masterRating,
      'masterFeedback': masterFeedback,
    };
  }

  // Метод для создания копии модели с обновленными полями
  OrderModel copyWith({
    String? id,
    String? clientId,
    String? category,
    String? description,
    double? latitude,
    double? longitude,
    OrderStatus? status,
    String? masterId,
    double? masterLatitude,
    double? masterLongitude,
    DateTime? masterLocationUpdatedAt,
    double? clientRating,
    String? clientFeedback,
    double? masterRating,
    String? masterFeedback,
  }) {
    return OrderModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      category: category ?? this.category,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      masterId: masterId ?? this.masterId,
      masterLatitude: masterLatitude ?? this.masterLatitude,
      masterLongitude: masterLongitude ?? this.masterLongitude,
      masterLocationUpdatedAt: masterLocationUpdatedAt ?? this.masterLocationUpdatedAt,
      clientRating: clientRating ?? this.clientRating,
      clientFeedback: clientFeedback ?? this.clientFeedback,
      masterRating: masterRating ?? this.masterRating,
      masterFeedback: masterFeedback ?? this.masterFeedback,
    );
  }
}
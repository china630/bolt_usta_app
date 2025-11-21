import 'package:cloud_firestore/cloud_firestore.dart';

// Список возможных ролей пользователя
enum UserRole {
  client, // Клиент, создающий заказы
  master, // Верифицированный мастер, принимающий заказы
  pendingMaster, // Заявка на мастера на рассмотрении
  unknown // Неизвестная роль (по умолчанию)
}

// Расширение для удобной работы с ролями
extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.client:
        return 'client';
      case UserRole.master:
        return 'master';
      case UserRole.pendingMaster:
        return 'pendingMaster';
      case UserRole.unknown:
        return 'unknown';
    }
  }
}

// --- Класс AppUser: Модель данных пользователя ---
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  // Поля для мастера
  final List<String> specializations;
  final String? verificationReason; // Причина/опыт для заявки на верификацию

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = UserRole.client, // По умолчанию - клиент
    this.specializations = const [],
    this.verificationReason,
  });

  // --- Фабричный конструктор для создания объекта из документа Firestore ---
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // Преобразование строки роли в enum
    UserRole userRole = UserRole.unknown;
    final roleString = data['role'] as String?;
    if (roleString != null) {
      if (roleString == UserRole.client.name) {
        userRole = UserRole.client;
      } else if (roleString == UserRole.master.name) {
        userRole = UserRole.master;
      } else if (roleString == UserRole.pendingMaster.name) {
        userRole = UserRole.pendingMaster;
      }
    }

    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'Новый пользователь',
      role: userRole,
      // Преобразование списка, если он существует
      specializations: (data['specializations'] is List)
          ? List<String>.from(data['specializations'] as List)
          : const [],
      verificationReason: data['verificationReason'] as String?,
    );
  }

  // --- Метод для преобразования объекта в Map для сохранения в Firestore ---
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'specializations': specializations,
      'verificationReason': verificationReason,
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Добавлен импорт
import '../models/user_model.dart';

// Глобальные переменные, предоставляемые средой Canvas.
// Используем try-catch для безопасного доступа к глобальным переменным в Flutter
String get _appId {
  try {
    // ignore: undefined_identifier
    return __app_id;
  } catch (e) {
    return 'default-app-id';
  }
}

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Базовый путь для приватных пользовательских данных
  // Используется: /artifacts/{appId}/users/{userId}/user_data/profile
  CollectionReference<Map<String, dynamic>> _userCollection(String userId) {
    return _db.collection('artifacts/$_appId/users/$userId/user_data');
  }

  // --- 1. Создание или обновление профиля (вызывается при регистрации/логине) ---
  Future<void> createOrUpdateUser({
    required String uid,
    required String email,
    required String displayName,
    UserRole role = UserRole.client,
    List<String> specializations = const [],
    String? verificationReason,
  }) async {
    final userRef = _userCollection(uid).doc('profile');

    final AppUser newUser = AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      role: role,
      specializations: specializations,
      verificationReason: verificationReason,
    );

    // Добавляем timestamp для отслеживания создания/обновления
    final userData = newUser.toFirestore();
    userData['updatedAt'] = FieldValue.serverTimestamp();

    await userRef.set(userData, SetOptions(merge: true));
  }

  // --- 2. Получение потока данных пользователя (AppUser) ---
  /// Получает поток данных AppUser для указанного UID.
  Stream<AppUser> getUserStream(String uid) {
    return _userCollection(uid).doc('profile').snapshots().map((snapshot) {
      // Сначала пытаемся создать AppUser из документа Firestore
      if (snapshot.exists) {
        return AppUser.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
      }

      // Если документа нет (например, только что зарегистрировались, но еще не выбрали роль),
      // создаем базовый объект AppUser с ролью unknown.
      // Используем текущего пользователя Firebase Auth для получения email.
      final user = FirebaseAuth.instance.currentUser;
      return AppUser(
        uid: uid,
        email: user?.email ?? 'anonymous',
        displayName: user?.displayName ?? 'Новый пользователь',
        role: UserRole.unknown,
      );
    });
  }

  // --- НОВЫЙ МЕТОД: Обновление только роли пользователя ---
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    final userRef = _userCollection(userId).doc('profile');
    // Обновляем только поле 'role', используя .name для получения строкового значения enum
    await userRef.update({'role': newRole.name});
  }

  // --- 4. Обновление полей мастера (специализации и верификация) ---
  Future<void> updateMasterFields(
      String userId, {
        required List<String> specializations,
        required String verificationReason,
        UserRole newRole = UserRole.pendingMaster,
      }) async {
    final userRef = _userCollection(userId).doc('profile');

    await userRef.update({
      'role': newRole.name,
      'specializations': specializations,
      'verificationReason': verificationReason,
    });
  }

  // --- 5. Получение имени пользователя (displayName) по ID ---
  Future<String> getDisplayName(String userId) async {
    if (userId.isEmpty) {
      return 'Неизвестный Пользователь';
    }
    try {
      final doc = await _userCollection(userId).doc('profile').get();
      final data = doc.data();
      if (data != null && data.containsKey('displayName')) {
        return data['displayName'] as String;
      }
      return 'Пользователь (ID: $userId)';
    } catch (e) {
      print('Ошибка при получении имени пользователя $userId: $e');
      return 'Ошибка загрузки имени';
    }
  }

}
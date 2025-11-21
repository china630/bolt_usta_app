import 'package:geolocator/geolocator.dart';

/// Сервис для получения текущего географического местоположения пользователя.
/// Класс помещается в 'services', так как инкапсулирует сложную логику
/// работы с внешним API и обработкой разрешений.
class LocationService {

  /// Общий метод для проверки, включены ли службы геолокации.
  Future<bool> _checkServiceEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Служба выключена. Возвращаем false и выбрасываем исключение с описанием.
      return Future.error(
          'Службы геолокации отключены. Пожалуйста, включите их.');
    }
    return true;
  }

  /// 1. Обрабатывает разрешения для КЛИЕНТА.
  /// Требует разрешения "только при использовании" для разовой фиксации местоположения.
  Future<bool> handleClientPermission() async {
    await _checkServiceEnabled();

    // 2. Проверяем текущий статус разрешения приложения
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Разрешение не дано, запрашиваем его у пользователя
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Пользователь отказал после запроса.
        return Future.error(
            'Разрешение на доступ к местоположению было отклонено. Невозможно создать заказ.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Пользователь навсегда запретил доступ к местоположению.
      return Future.error(
          'Разрешение на доступ к местоположению навсегда отклонено. Пожалуйста, измените настройки приложения вручную.');
    }

    // Разрешения в порядке.
    return true;
  }

  /// 2. Обрабатывает разрешения для МАСТЕРА.
  /// Требует более высокого уровня разрешения (InUse или Always) для постоянного отслеживания.
  Future<bool> handleMasterPermission() async {
    await _checkServiceEnabled();

    LocationPermission permission = await Geolocator.checkPermission();

    // Если разрешение Denied (отклонено) или DeniedForever (отклонено навсегда),
    // или разрешено только для разового использования, запрашиваем лучшее.
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.whileInUse) {

      // Запрашиваем разрешение
      permission = await Geolocator.requestPermission();

      // Проверяем, достаточно ли предоставленное разрешение
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return Future.error(
            'Для работы в режиме Мастера требуется разрешение на доступ к местоположению "Во время использования приложения".');
      }
    }

    // Разрешения в порядке.
    return true;
  }

  /// Получает текущее местоположение пользователя (широта и долгота).
  Future<Position> getCurrentLocation() async {
    try {
      // Проверяем и запрашиваем разрешения (используем клиентский метод)
      final isPermitted = await handleClientPermission();

      if (!isPermitted) {
        throw Exception(
            'Не удалось получить разрешение на доступ к местоположению.');
      }

      // Получаем позицию. Используем низкую точность, чтобы быстрее получить результат.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        // Ограничиваем время ожидания
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      // Перебрасываем исключение дальше
      rethrow;
    }
  }
}
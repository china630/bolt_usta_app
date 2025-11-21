import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bolt_usta_app/models/order_model.dart';
import 'package:bolt_usta_app/services/location_service.dart';
import 'package:bolt_usta_app/services/order_service.dart';
import 'package:bolt_usta_app/services/user_service.dart';
import 'package:bolt_usta_app/routes.dart';

// Инициализация сервисов
final OrderService _orderService = OrderService();
final LocationService _locationService = LocationService();
final UserService _userService = UserService(); // Инициализация UserService

/// Экран для мастера, где он может отслеживать свое местоположение
/// относительно места заказа, публиковать координаты и менять статус.
class MasterOrderMapViewScreen extends StatefulWidget {
  final OrderModel initialOrder;

  const MasterOrderMapViewScreen({
    super.key,
    required this.initialOrder,
  });

  @override
  State<MasterOrderMapViewScreen> createState() =>
      _MasterOrderMapViewScreenState();
}

class _MasterOrderMapViewScreenState extends State<MasterOrderMapViewScreen> {
  // Контроллер карты
  GoogleMapController? _mapController;

  // Набор маркеров
  Set<Marker> _markers = {};

  // Поток для получения обновлений заказа
  late Stream<OrderModel> _orderStream;

  // Таймер для автоматического обновления локации мастера в Firestore
  Timer? _locationUpdateTimer;

  // Состояние загрузки для кнопок
  bool _isLoading = false;

  // Подписка на изменение местоположения
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLocationPublishing = false; // Флаг, указывающий, публикуется ли локация

  // Начальная позиция камеры - центр карты
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(40.4093, 49.8671), // Баку, Азербайджан
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    // Инициализируем поток заказа
    _orderStream = _orderService.getOrderStream(widget.initialOrder.id);

    // Проверяем, нужно ли сразу начать публикацию локации (если статус принят)
    if (widget.initialOrder.status == OrderStatus.accepted ||
        widget.initialOrder.status == OrderStatus.arrived ||
        widget.initialOrder.status == OrderStatus.inProgress
    ) {
      _startLocationPublishing();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationUpdateTimer?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  /// Обновляет набор маркеров на карте
  void _updateMarkers(OrderModel order) {
    final newMarkers = <Marker>{};

    // Маркер клиента (адрес заказа)
    newMarkers.add(
      Marker(
        markerId: const MarkerId('clientLocation'),
        position: LatLng(order.latitude, order.longitude),
        infoWindow: InfoWindow(
          title: 'Адрес Заказа',
          snippet: 'Категория: ${order.category}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Маркер мастера (если координаты доступны)
    if (order.masterLatitude != null &&
        order.masterLongitude != null &&
        order.masterId != null) {
      final masterPosition = LatLng(order.masterLatitude!, order.masterLongitude!);
      newMarkers.add(
        Marker(
          markerId: const MarkerId('masterLocation'),
          position: masterPosition,
          infoWindow: const InfoWindow(title: 'Ваше Местоположение'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Обновляем состояние
    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  /// Обновляет камеру, чтобы вместить оба маркера (если мастер назначен)
  void _updateCamera(OrderModel order) async {
    if (_mapController == null || _markers.isEmpty) return;

    final List<LatLng> points = [];
    points.add(LatLng(order.latitude, order.longitude)); // Точка клиента

    if (order.masterLatitude != null && order.masterLongitude != null) {
      points.add(LatLng(order.masterLatitude!, order.masterLongitude!)); // Точка мастера
    }

    if (points.length == 1) {
      // Если только один маркер, просто центрируем на нем
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
    } else if (points.length > 1) {
      // Если два маркера, строим границы и центрируем
      final LatLngBounds bounds = _createBounds(points);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50), // 50 - padding
      );
    }
  }

  /// Вспомогательная функция для создания границ карты
  LatLngBounds _createBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
      minLat = minLat > point.latitude ? point.latitude : minLat;
      maxLat = maxLat < point.latitude ? point.latitude : maxLat;
      minLon = minLon > point.longitude ? point.longitude : minLon;
      maxLon = maxLon < point.longitude ? point.longitude : maxLon;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  /// Начинает публикацию местоположения мастера
  Future<void> _startLocationPublishing() async {
    if (_isLocationPublishing) return;

    // 1. Запрос разрешения и проверка сервисов
    bool permissionGranted = await _locationService.checkAndRequestPermission();
    if (!permissionGranted) {
      if (mounted) {
        _showSnackbar('Для отслеживания местоположения требуется разрешение.');
      }
      return;
    }

    // 2. Получение текущего местоположения и немедленное обновление Firestore
    Position? initialPosition;
    try {
      initialPosition = await _locationService.getCurrentLocation();
      if (initialPosition != null) {
        await _orderService.updateMasterLocation(
          orderId: widget.initialOrder.id,
          latitude: initialPosition.latitude,
          longitude: initialPosition.longitude,
        );
      }
    } catch (e) {
      print('Ошибка получения начальной локации: $e');
    }

    // 3. Запуск потока обновления локации в реальном времени
    // Используем LocationSettings для экономии батареи (каждые 10 секунд и/или 10 метров)
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    // Отменяем предыдущую подписку, если она была
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings)
        .listen((Position position) {
      if (position.isMocked) {
        print("Игнорируем фиктивное местоположение");
        return;
      }
      // Обновление локации в Firestore
      _orderService.updateMasterLocation(
        orderId: widget.initialOrder.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }, onError: (e) {
      print('Ошибка в потоке местоположения: $e');
      if (mounted) {
        _showSnackbar('Ошибка обновления местоположения: $e');
      }
    });

    if (mounted) {
      setState(() {
        _isLocationPublishing = true;
      });
      _showSnackbar('Публикация местоположения начата.');
    }
  }

  /// Останавливает публикацию местоположения мастера
  void _stopLocationPublishing() {
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLocationPublishing = false;
      });
      _showSnackbar('Публикация местоположения остановлена.');
    }
  }

  /// Обработка изменения статуса заказа
  Future<void> _onStatusChange(OrderStatus newStatus) async {
    if (_isLoading) return;

    // Специальная обработка для принятия заказа
    if (newStatus == OrderStatus.accepted) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        _showSnackbar('Ошибка: ID мастера не найден.');
        return;
      }
      if (mounted) setState(() => _isLoading = true);

      try {
        await _orderService.acceptOrder(widget.initialOrder.id, currentUserId);
        // После принятия сразу начинаем публикацию локации
        await _startLocationPublishing();
        _showSnackbar('Заказ принят! Начинаем отслеживание.');
      } catch (e) {
        _showSnackbar('Ошибка при принятии заказа: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Специальная обработка для отмены
    if (newStatus == OrderStatus.cancelled) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await _orderService.cancelOrder(widget.initialOrder.id);
        _stopLocationPublishing(); // Останавливаем публикацию при отмене
        _showSnackbar('Заказ отменен.');
        // Возвращаемся на главный экран
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        _showSnackbar('Ошибка при отмене заказа: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Специальная обработка для 'completed'
    if (newStatus == OrderStatus.completed) {
      // Это окончательное завершение мастером после того, как клиент подтвердил (clientCompleted)
      if (mounted) setState(() => _isLoading = true);
      try {
        // Обновляем статус на "Завершен"
        await _orderService.updateOrderStatus(widget.initialOrder.id, newStatus);
        _stopLocationPublishing(); // Останавливаем публикацию
        _showSnackbar('Заказ окончательно завершен!');
        // Возвращаемся на главный экран
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        _showSnackbar('Ошибка при завершении заказа: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Общая обработка для статусов 'arrived' и 'inProgress'
    if (newStatus == OrderStatus.arrived || newStatus == OrderStatus.inProgress) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await _orderService.updateOrderStatus(widget.initialOrder.id, newStatus);
        // Не останавливаем публикацию, пока заказ не завершен
        _showSnackbar('Статус изменен на ${newStatus.localizedName}');
      } catch (e) {
        _showSnackbar('Ошибка при изменении статуса: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }
  }


  /// Вспомогательная функция для отображения Snackbar.
  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Построение панели управления внизу экрана.
  Widget _buildControlPanel(OrderModel order) {
    final bool isNew = order.status == OrderStatus.newOrder;
    final bool isAccepted = order.status == OrderStatus.accepted;
    final bool isArrived = order.status == OrderStatus.arrived;
    final bool isInProgress = order.status == OrderStatus.inProgress;
    final bool isClientCompleted = order.status == OrderStatus.clientCompleted;
    final bool isFinished = order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled;

    // Проверяем, что текущий мастер принял этот заказ
    final isMyOrder = order.masterId == FirebaseAuth.instance.currentUser?.uid;

    if (isFinished) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: order.status.color.withOpacity(0.95),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Заказ ${order.status.localizedName}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                order.status == OrderStatus.completed
                    ? 'Этот заказ был успешно завершен и оценен клиентом.'
                    : 'Этот заказ был отменен.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок и статус
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Заказ: ${order.category}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: order.status.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.localizedName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Описание: ${order.description}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const Divider(height: 20),

            // Кнопки действий (динамические)
            Row(
              children: [
                if (isNew)
                // Кнопка 1: Принять Заказ (Только для статуса New)
                  _ActionButton(
                    title: 'Принять',
                    icon: Icons.check_circle_outline,
                    color: Colors.teal,
                    onPressed: _isLoading ? null : () => _onStatusChange(OrderStatus.accepted),
                    isLoading: _isLoading,
                  ),

                if (isNew && !isMyOrder)
                // Пустой Expanded, чтобы выровнять кнопку отмены
                  const Spacer(),


                if (isAccepted && isMyOrder)
                // Кнопка 2: Мастер Прибыл (Только для статуса Accepted)
                  _ActionButton(
                    title: 'Прибыл',
                    icon: Icons.location_on_outlined,
                    color: Colors.blue,
                    onPressed: _isLoading ? null : () => _onStatusChange(OrderStatus.arrived),
                    isLoading: _isLoading,
                  ),

                if (isArrived && isMyOrder)
                // Кнопка 3: Начать Работу (Только для статуса Arrived)
                  _ActionButton(
                    title: 'Начать Работу',
                    icon: Icons.play_arrow_outlined,
                    color: Colors.orange,
                    onPressed: _isLoading ? null : () => _onStatusChange(OrderStatus.inProgress),
                    isLoading: _isLoading,
                  ),

                if (isInProgress && isMyOrder)
                // Кнопка 4: Завершить Работу (Мастер ждет подтверждения клиента)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ожидайте подтверждения клиента',
                        style: TextStyle(fontSize: 12, color: Colors.indigo.shade400, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      _ActionButton(
                        title: 'Работа Выполнена',
                        icon: Icons.task_alt_outlined,
                        color: Colors.indigo,
                        // Мастер просто ждет, пока клиент не переведет в clientCompleted
                        onPressed: null,
                        isLoading: false,
                      ),
                    ],
                  ),

                if (isClientCompleted && isMyOrder)
                // Кнопка 5: Окончательно Завершить (После подтверждения клиента)
                  _ActionButton(
                    title: 'Окончательно Завершить',
                    icon: Icons.done_all,
                    color: Colors.deepPurple,
                    onPressed: _isLoading ? null : () => _onStatusChange(OrderStatus.completed),
                    isLoading: _isLoading,
                  ),

                // Пространство между кнопками
                const SizedBox(width: 10),

                // Кнопка отмены (видна всегда, кроме завершенных)
                if (isNew || isAccepted || isArrived || isInProgress)
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => _onStatusChange(OrderStatus.cancelled),
                      child: Text(
                        'Отменить заказ',
                        style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),

            // Индикатор публикации локации
            if (_isLocationPublishing && isMyOrder && (isAccepted || isArrived || isInProgress || isClientCompleted))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gps_fixed, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Ваше местоположение публикуется в реальном времени.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта Заказа'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<OrderModel>(
        stream: _orderStream,
        initialData: widget.initialOrder,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки заказа: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Заказ не найден.'));
          }

          final order = snapshot.data!;

          // Обновляем маркеры при получении новых данных
          _updateMarkers(order);
          // Обновляем камеру при получении новых данных
          _updateCamera(order);

          return Stack(
            children: [
              // 1. Google Map (Занимает все доступное пространство)
              GoogleMap(
                initialCameraPosition: _initialCameraPosition,
                mapType: MapType.normal,
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  // Обновляем камеру сразу после создания карты, чтобы показать оба маркера, если мастер уже назначен
                  _updateCamera(order);
                },
                myLocationEnabled: true, // Показываем местоположение мастера
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),

              // 2. Панель управления (Прикреплена снизу)
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildControlPanel(order),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Вспомогательный виджет для кнопки действия.
class _ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
            height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 5,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
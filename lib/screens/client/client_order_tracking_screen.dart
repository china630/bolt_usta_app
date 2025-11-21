import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bolt_usta_app/models/order_model.dart';
import 'package:bolt_usta_app/services/order_service.dart';
import 'package:bolt_usta_app/services/user_service.dart';
import 'package:bolt_usta_app/routes.dart';

// Инициализация сервисов
final OrderService _orderService = OrderService();
final UserService _userService = UserService();

/// Экран отслеживания заказа для клиента.
/// Отображает местоположение мастера и места назначения на карте в реальном времени.
class ClientOrderTrackingScreen extends StatefulWidget {
  final OrderModel initialOrder;

  const ClientOrderTrackingScreen({
    super.key,
    required this.initialOrder,
  });

  @override
  State<ClientOrderTrackingScreen> createState() =>
      _ClientOrderTrackingScreenState();
}

class _ClientOrderTrackingScreenState extends State<ClientOrderTrackingScreen> {
  // Контроллер карты для управления камерой
  GoogleMapController? _mapController;

  // Набор маркеров на карте
  Set<Marker> _markers = {};

  // Поток для получения обновлений заказа
  late Stream<OrderModel> _orderStream;

  // Начальная позиция камеры (центр)
  late CameraPosition _initialCameraPosition;

  // Флаг для кнопки "Подтвердить Выполнение"
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем поток заказа по ID
    _orderStream = _orderService.streamOrder(widget.initialOrder.id);

    // Центрируем камеру на местоположении клиента
    _initialCameraPosition = CameraPosition(
      target: LatLng(widget.initialOrder.latitude!, widget.initialOrder.longitude!),
      zoom: 15,
    );
  }

  /// Обновление маркеров на карте
  void _updateMarkers(OrderModel order) {
    final newMarkers = <Marker>{};

    // Маркер клиента/места назначения (обязательный)
    if (order.latitude != null && order.longitude != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(order.latitude!, order.longitude!),
          infoWindow: const InfoWindow(title: 'Место назначения'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Маркер мастера (только если мастер назначен)
    if (order.masterLatitude != null && order.masterLongitude != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('master'),
          position: LatLng(order.masterLatitude!, order.masterLongitude!),
          infoWindow: const InfoWindow(title: 'Местоположение Мастера'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    // Обновляем состояние только если маркеры изменились
    if (newMarkers.length != _markers.length ||
        !newMarkers.every(_markers.contains)) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  /// Обновление камеры, чтобы показать все маркеры
  void _updateCamera(OrderModel order) {
    if (_mapController == null || _markers.isEmpty) return;

    // Список координат для включения в границы
    List<LatLng> points = [];
    if (order.latitude != null && order.longitude != null) {
      points.add(LatLng(order.latitude!, order.longitude!));
    }
    if (order.masterLatitude != null && order.masterLongitude != null) {
      points.add(LatLng(order.masterLatitude!, order.masterLongitude!));
    }

    if (points.length == 1) {
      // Если только одна точка, центрируем на ней и увеличиваем масштаб
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: points.first,
            zoom: 14,
          ),
        ),
      );
    } else if (points.length >= 2) {
      // Если две или более точек, строим границы, чтобы показать их все
      final bounds = LatLngBounds(
        southwest: LatLng(
          points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
          points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
          points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
        ),
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100), // 100 - отступ
      );
    }
  }

  /// Обработчик нажатия кнопки "Подтвердить выполнение"
  Future<void> _confirmCompletion(String orderId) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      // Переводим заказ в статус 'clientCompleted'
      await _orderService.updateOrderStatus(
          orderId: orderId, newStatus: OrderStatus.clientCompleted);
      // Успешное выполнение будет обработано через StreamBuilder,
      // который перестроит виджет и покажет кнопку оценки.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при подтверждении: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  /// Построение панели управления внизу экрана
  Widget _buildControlPanel(OrderModel order) {
    // Стиль для информационных текстов
    final infoTextStyle = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade700);

    // Стиль для заголовков
    final titleTextStyle =
    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Статус заказа
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Статус Заказа:', style: infoTextStyle),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.localizedName,
                  style: TextStyle(
                    color: order.status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1),

          // 2. Отображение мастера и его контактов
          FutureBuilder<String>(
            future: _userService.getUserName(order.masterId),
            builder: (context, snapshot) {
              final masterName = snapshot.data ?? 'Назначение...';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Мастер:', style: infoTextStyle),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.masterId == null
                            ? 'Ожидание назначения'
                            : masterName,
                        style: titleTextStyle,
                      ),
                      if (order.masterId != null)
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.teal),
                          onPressed: () {
                            // TODO: Реализовать звонок мастеру
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Звонок мастеру... (Заглушка)')),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // 3. Кнопки действий в зависимости от статуса
          if (order.status == OrderStatus.inProgress)
            ElevatedButton.icon(
              icon: _isUpdatingStatus
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isUpdatingStatus
                  ? 'Подтверждение...'
                  : 'Подтвердить Выполнение Работ'),
              onPressed: _isUpdatingStatus ? null : () => _confirmCompletion(order.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          else if (order.status == OrderStatus.clientCompleted)
          // БЛОК: Статус, требующий оценки
            ElevatedButton.icon(
              icon: const Icon(Icons.star_half_rounded),
              label: const Text('Оценить Мастера и Завершить Заказ'),
              onPressed: () {
                // Перенаправляем на экран рейтинга, передавая модель заказа
                Navigator.of(context).pushNamed(
                  Routes.clientRating.name,
                  arguments: order,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          else if (order.status == OrderStatus.completed)
            // Окончательно завершенный заказ
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Заказ успешно завершен. Спасибо!',
                    style: TextStyle(
                        color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else if (order.status == OrderStatus.cancelled)
              // Отмененный заказ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Заказ был отменен.',
                      style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ №${widget.initialOrder.id.substring(0, 6)}...'),
        backgroundColor: Colors.teal.shade400,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<OrderModel>(
        stream: _orderStream,
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
                myLocationEnabled: true, // Показываем местоположение клиента
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
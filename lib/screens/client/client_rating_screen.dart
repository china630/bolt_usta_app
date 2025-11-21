import 'package:flutter/material.dart';
import 'package:bolt_usta_app/models/order_model.dart';
import 'package:bolt_usta_app/routes.dart';
import 'package:bolt_usta_app/services/order_service.dart';

// Инициализация сервиса заказов
final OrderService _orderService = OrderService();

/// Экран для оставления отзыва и оценки мастера клиентом.
class ClientRatingScreen extends StatefulWidget {
  final OrderModel order;

  const ClientRatingScreen({
    super.key,
    required this.order,
  });

  @override
  State<ClientRatingScreen> createState() => _ClientRatingScreenState();
}

class _ClientRatingScreenState extends State<ClientRatingScreen> {
  double _rating = 0.0;
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  /// Виджет для отображения интерактивных звезд рейтинга.
  Widget _buildRatingBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return IconButton(
          icon: Icon(
            starIndex <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber,
            size: 40,
          ),
          onPressed: () {
            setState(() {
              _rating = starIndex.toDouble();
            });
          },
        );
      }),
    );
  }

  /// Обработчик отправки рейтинга и отзыва.
  Future<void> _submitRating() async {
    // Рейтинг должен быть больше 0.0
    if (_rating == 0.0) {
      _showSnackbar('Пожалуйста, поставьте оценку от 1 до 5 звезд.', isError: true);
      return;
    }

    if (_isLoading) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      await _orderService.rateMasterAndCompleteOrder(
        orderId: widget.order.id,
        rating: _rating,
        feedback: _feedbackController.text.trim().isEmpty ? null : _feedbackController.text.trim(),
      );

      _showSnackbar('Спасибо! Отзыв отправлен, заказ завершен.');

      // Возвращаемся на главный экран клиента
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.clientHome,
              (route) => route.settings.name == Routes.clientHome,
        );
      }
    } catch (e) {
      _showSnackbar('Произошла ошибка при отправке отзыва: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Вспомогательная функция для отображения Snackbar.
  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.teal,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оставить Отзыв'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(Icons.rate_review, size: 80, color: Colors.teal),
            ),
            const SizedBox(height: 20),
            const Text(
              'Оцените работу мастера',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Заказ на "${widget.order.category}" успешно выполнен. Ваша оценка поможет другим пользователям.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),

            // Рейтинг (Звезды)
            _buildRatingBar(),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Ваша оценка: ${_rating.toStringAsFixed(0)} из 5',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 30),

            // Поле для отзыва
            Text(
              'Дополнительный отзыв (необязательно)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _feedbackController,
              decoration: InputDecoration(
                hintText: 'Опишите Ваш опыт работы с мастером...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 40),

            // Кнопка отправки
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitRating,
              icon: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.send_rounded),
              label: const Text('Отправить Отзыв и Завершить Заказ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
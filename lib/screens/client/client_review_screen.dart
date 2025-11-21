import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // Используем пакет для рейтинга
import 'package:on_demand_service_app/models/order_model.dart';
import 'package:on_demand_service_app/routes.dart';
import 'package:on_demand_service_app/services/order_service.dart';

// Инициализация сервисов
final OrderService _orderService = OrderService();

/// Экран для клиента, где он может оценить работу мастера и оставить отзыв.
class ClientReviewScreen extends StatefulWidget {
  final String orderId;

  const ClientReviewScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<ClientReviewScreen> createState() => _ClientReviewScreenState();
}

class _ClientReviewScreenState extends State<ClientReviewScreen> {
  double _rating = 0.0;
  String _feedback = '';
  bool _isLoading = false;
  final _feedbackController = TextEditingController();

  /// Обработчик отправки отзыва.
  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      _showMessage('Пожалуйста, поставьте оценку!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _orderService.submitReview(
        orderId: widget.orderId,
        rating: _rating,
        feedback: _feedback.trim(),
      );

      // Сообщение об успехе и возврат на главный экран клиента
      _showMessage('Спасибо за ваш отзыв! Заказ успешно завершен.', isError: false);

      // Возвращаемся на главный экран клиента, удаляя все экраны отслеживания
      // и ожидания из стека навигации.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.settings.name == Routes.clientHome);
      }
    } catch (e) {
      print('Ошибка при отправке отзыва: $e');
      _showMessage('Не удалось отправить отзыв. Попробуйте еще раз.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оставить отзыв'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Заголовок
            const Text(
              'Как вы оцениваете работу мастера?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // 2. Виджет для выбора рейтинга
            Center(
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
            ),
            const SizedBox(height: 40),

            // 3. Поле для текстового отзыва
            const Text(
              'Ваш комментарий:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _feedbackController,
              onChanged: (value) => _feedback = value,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Опишите свой опыт работы с мастером...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                contentPadding: const EdgeInsets.all(15),
              ),
            ),
            const SizedBox(height: 50),

            // 4. Кнопка отправки
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Отправить отзыв и завершить', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
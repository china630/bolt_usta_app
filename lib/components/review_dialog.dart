import 'package:flutter/material.dart';

/// Диалог для ввода оценки и отзыва клиента.
class ReviewDialog extends StatefulWidget {
  final String masterName;

  const ReviewDialog({
    super.key,
    required this.masterName,
  });

  // Статический метод для отображения диалога и получения результата
  static Future<Map<String, dynamic>?> show(
      BuildContext context, String masterName) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReviewDialog(masterName: masterName),
    );
  }

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double _rating = 5.0; // Начальная оценка - 5 звезд
  final TextEditingController _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _submitReview() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      // Возвращаем оценку и отзыв
      Navigator.of(context).pop({
        'rating': _rating,
        'feedback': _feedbackController.text.trim(),
      });
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // Строит звездочки для выбора рейтинга
  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starRating = index + 1.0;
        final isSelected = starRating <= _rating;
        return IconButton(
          icon: Icon(
            isSelected ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber,
            size: 40,
          ),
          onPressed: () {
            setState(() {
              _rating = starRating;
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: Text(
          'Оцените работу мастера ${widget.masterName}',
          textAlign: TextAlign.center,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStarRating(),
              Text('$_rating из 5.0',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              TextFormField(
                controller: _feedbackController,
                decoration: const InputDecoration(
                  labelText: 'Ваш отзыв',
                  hintText: 'Поделитесь своими впечатлениями (необязательно)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitReview,
                  icon: _isLoading
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Отправить оценку'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Список всех доступных категорий (должен быть синхронизирован с client_order_creation_screen)
const List<String> allCategories = [
  'Сантехника',
  'Электрика',
  'Уборка',
  'Ремонт техники',
  'Сборка мебели',
  'Другое'
];

class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  List<String> _specializations = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSpecializations();
  }

  // --- Загрузка специализаций мастера из Firestore ---
  Future<void> _loadSpecializations() async {
    if (user == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь не авторизован.')),
        );
      }
      return;
    }

    try {
      // ПРИМЕЧАНИЕ: В реальном приложении здесь следует использовать __app_id и userId для корректного пути
      // Но для простоты и в соответствии с предыдущими примерами, используем прямой путь:
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();

      if (doc.exists && doc.data() != null) {
        // Предполагаем, что специализации хранятся в поле 'specializations' как List<String>
        final data = doc.data()!;
        if (data.containsKey('specializations') && data['specializations'] is List) {
          setState(() {
            _specializations = List<String>.from(data['specializations']);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки специализаций: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Сохранение специализаций в Firestore ---
  Future<void> _saveSpecializations() async {
    if (user == null || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // ПРИМЕЧАНИЕ: В реальном приложении здесь следует использовать __app_id и userId для корректного пути
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
        {'specializations': _specializations},
        SetOptions(merge: true), // Используем merge, чтобы не перезаписывать другие поля
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Специализации успешно обновлены!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // --- Удаление специализации ---
  void _removeSpecialization(String category) {
    setState(() {
      _specializations.remove(category);
    });
    // Автоматическое сохранение после изменения для лучшего UX
    _saveSpecializations();
  }

  // --- Добавление специализации ---
  void _addSpecialization(String category) {
    if (!_specializations.contains(category)) {
      setState(() {
        _specializations.add(category);
      });
      // Автоматическое сохранение после изменения для лучшего UX
      _saveSpecializations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Профиль Мастера'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveSpecializations,
            tooltip: 'Сохранить изменения',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Информация о пользователе ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 40, color: Colors.teal),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ваш ID:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          Text(
                            user?.uid ?? 'Неизвестный пользователь',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Текущие специализации ---
            const Text(
              'Мои Текущие Специализации',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const Divider(color: Colors.teal),

            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _specializations.map((category) {
                return Chip(
                  label: Text(category),
                  backgroundColor: Colors.teal.shade100,
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeSpecialization(category),
                );
              }).toList(),
            ),

            if (_specializations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  'У вас пока нет специализаций. Добавьте их ниже!',
                  style: TextStyle(color: Colors.red[400], fontStyle: FontStyle.italic),
                ),
              ),

            const SizedBox(height: 30),

            // --- Добавление специализаций ---
            const Text(
              'Доступные Категории (Нажмите, чтобы добавить)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const Divider(color: Colors.blueGrey),

            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: allCategories.where((category) {
                // Фильтруем категории, которые уже есть у мастера
                return !_specializations.contains(category);
              }).map((category) {
                return ActionChip(
                  label: Text(category),
                  avatar: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () => _addSpecialization(category),
                  backgroundColor: Colors.blueGrey.shade50,
                  side: BorderSide(color: Colors.blueGrey.shade200),
                  elevation: 2,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
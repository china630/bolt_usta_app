import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'master_profile_settings_screen.dart';

class MasterDashboardScreen extends StatefulWidget {
  const MasterDashboardScreen({super.key});

  @override
  State<MasterDashboardScreen> createState() => _MasterDashboardScreenState();
}

class _MasterDashboardScreenState extends State<MasterDashboardScreen> {
  final String? ustaUid = FirebaseAuth.instance.currentUser?.uid;

  // ----------------------------------------------------
  // Функция: Переключение статуса (Mövcud/Mövcud Deyil)
  // ----------------------------------------------------
  void _toggleStatus(bool isAvailable) {
    if (ustaUid == null) return;
    FirebaseFirestore.instance.collection('users').doc(ustaUid).update({
      'status': isAvailable ? 'free' : 'busy',
    });
  }

  // ----------------------------------------------------
  // UI - Строитель для отображения данных мастера
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (ustaUid == null) {
      return const Scaffold(body: Center(child: Text('Giriş səhvi.')));
    }

    // Слушаем данные профиля мастера в реальном времени
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(ustaUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isAvailable = data?['status'] == 'free';
        final views = data?['views_count'] ?? 0;
        final calls = data?['calls_count'] ?? 0;
        final saves = data?['saves_count'] ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Usta Paneli (Дашборд)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterProfileSettingsScreen()));
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Переключатель Статуса
              _buildStatusToggle(isAvailable, context),
              const Divider(height: 30),

              // 2. Секция Статистики
              const Text('Statistika (Статистика)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildStatsGrid(views, calls, saves),
              const Divider(height: 30),

              // 3. Секция Новых Заказов (Bolt)
              const Text('Yeni Sifarişlər (Bolt)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // Здесь будет StreamBuilder для коллекции 'orders'
              Center(child: Text(isAvailable ? 'Yeni sifariş gözlənilir...' : 'Mövcud Deyil: Zəhmət olmasa statusu dəyişin.')),
            ],
          ),
        );
      },
    );
  }

  // Виджет для переключателя
  Widget _buildStatusToggle(bool isAvailable, BuildContext context) {
    return Card(
      color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAvailable ? 'Mövcud (Свободен)' : 'Mövcud Deyil (Недоступен)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            Switch(
              value: isAvailable,
              onChanged: _toggleStatus,
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  // Виджет для сетки статистики
  Widget _buildStatsGrid(int views, int calls, int saves) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.0,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard('Baxışlar', views),
        _buildStatCard('Zənglər', calls),
        _buildStatCard('Yadda Saxlanılıb', saves),
      ],
    );
  }

  // Виджет для отдельной карточки статистики
  Widget _buildStatCard(String title, int count) {
    return Card(
      elevation: 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
        ],
      ),
    );
  }
}
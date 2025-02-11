import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  _OrderDetailPageState createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? order;
  bool isLoading = true;
  String? errorMessage;
  String? token;
  String? telegramId;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTokenAndTelegramId();
  }

  double get totalProgress {
    if (order == null || order!.positions.isEmpty) return 0.0;
    int totalCount = 0;
    int totalScanned = 0;
    for (var position in order!.positions) {
      totalCount += position.count;
      totalScanned += position.scanned;
    }
    return totalCount > 0 ? totalScanned / totalCount : 0.0;
  }

  String get progressPercentage {
    return '${(totalProgress * 100).toStringAsFixed(1)}%';
  }

  Future<void> _loadTokenAndTelegramId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('access_token');
      telegramId = prefs.getString('id_telegram');
    });
    fetchOrderDetail();
  }

  Future<void> fetchOrderDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://uztexsoft.uz/api/orders/${widget.orderId}/details/'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          order = Order.fromJson(data);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Ошибка при загрузке деталей заказа';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка сети: $e';
        isLoading = false;
      });
    }
  }

  Future<void> sendFile() async {
    if (telegramId == null || telegramId!.isEmpty) {
      _showErrorMessage('Пожалуйста, установите свой Telegram ID в профиле.');
      return;
    }

    final url = 'https://uztexsoft.uz/api/orders/${widget.orderId}/details/excel/';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Excel файл успешно отправлен через Telegram');
      } else {
        setState(() {
          errorMessage = 'Ошибка отправки Excel файла: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка: $e';
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<Position> get filteredPositions {
    if (searchQuery.isEmpty) {
      return order?.positions ?? [];
    }
    return order?.positions
        .where((position) =>
    position.part_number.toLowerCase().contains(searchQuery.toLowerCase()) ||
        position.size.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList() ??
        [];
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Детали заказа ${widget.orderId}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Прогресс: $progressPercentage',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: sendFile,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: totalProgress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: fetchOrderDetail,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Ошибка: $errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        )
            : order == null
            ? const Center(
          child: Text(
            'Нет данных о заказе',
            style: TextStyle(color: Colors.red),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Поиск по артикулу и размеру',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredPositions.length,
                  itemBuilder: (context, index) {
                    final position = filteredPositions[index];
                    final progress = position.scanned / position.count;
                    final isComplete = position.scanned == position.count;

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: isComplete
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.shopping_cart, color: Colors.orange),
                        title: Text(
                          'Размер: ${position.size}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Артикул изделия: ${position.part_number}'),
                            Text('Цвет: ${position.color}'),
                            Text('Количество: ${numberFormat.format(position.count)} шт'),
                            Row(
                              children: [
                                const Icon(Icons.done_all, color: Colors.green),
                                const SizedBox(width: 5),
                                Text('Сканировано: ${numberFormat.format(position.scanned)} шт'),
                              ],
                            ),
                            if (!isComplete)
                              Row(
                                children: [
                                  const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Осталось: ${numberFormat.format(position.count - position.scanned)} шт',
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 15,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Order {
  final List<Position> positions;

  Order({required this.positions});

  factory Order.fromJson(Map<String, dynamic> json) {
    var positionsList = json['positions'] as List;
    List<Position> positions = positionsList.map((pos) => Position.fromJson(pos)).toList();
    return Order(positions: positions);
  }
}

class Position {
  final String part_number;
  final String color;
  final String size;
  final int count;
  final int scanned;

  Position({
    required this.part_number,
    required this.color,
    required this.size,
    required this.count,
    required this.scanned,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      part_number: json['part_number'],
      color: json['color'],
      size: json['size'],
      count: json['count'],
      scanned: json['scanned'],
    );
  }
}
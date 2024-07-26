import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'orders_page.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  OrderDetailPage({required this.orderId});

  @override
  _OrderDetailPageState createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? order;
  bool isLoading = true;
  String? errorMessage;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('access_token');
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
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
    final url = 'https://uztexsoft.uz/api/orders/${widget.orderId}/details/excel/';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
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
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Детали заказа ${widget.orderId}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              fetchOrderDetail();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text('Ошибка: $errorMessage',
                style: TextStyle(color: Colors.red)),
          ],
        ),
      )
          : order == null
          ? Center(
        child: Text('Нет данных о заказе',
            style: TextStyle(color: Colors.red)),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: order!.positions.length,
                itemBuilder: (context, index) {
                  final position = order!.positions[index];
                  final progress =
                      position.scanned / position.count;
                  final isComplete =
                      position.scanned == position.count;

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: isComplete
                          ? Icon(Icons.check_circle,
                          color: Colors.green)
                          : Icon(Icons.shopping_cart,
                          color: Colors.deepPurple),
                      title: Text(
                        'Размер: ${position.size}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text('Цвет: ${position.color}',
                              style: TextStyle(
                                  fontFamily: 'Roboto')),
                          Text(
                              'Количество: ${numberFormat.format(position.count)} шт'),
                          Row(
                            children: [
                              Icon(Icons.done_all,
                                  color: Colors.green),
                              SizedBox(width: 5),
                              Text(
                                  'Сканировано: ${position.scanned} шт'),
                            ],
                          ),
                          if (!isComplete)
                            Row(
                              children: [
                                Icon(
                                    Icons
                                        .remove_circle_outline,
                                    color: Colors.red),
                                SizedBox(width: 5),
                                Text(
                                    'Осталось: ${position.count - position.scanned} шт'),
                              ],
                            ),
                          SizedBox(height: 10),
                          ClipRRect(
                            borderRadius:
                            BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor:
                              Colors.grey[300],
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  Colors.deepPurple),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.send,
                            color: Colors.deepPurple),
                        onPressed: sendFile,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

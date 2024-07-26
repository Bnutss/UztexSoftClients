import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'order_detail_page.dart';

class OrderPosition {
  final int id;
  final String size;
  final String color;
  final int count;
  final String customerOrderNumber;
  final bool isCompleted;
  final String codeObjectCorrelation;
  final DateTime createdAt;
  final int scanned;
  final int remaining;

  OrderPosition({
    required this.id,
    required this.size,
    required this.color,
    required this.count,
    required this.customerOrderNumber,
    required this.isCompleted,
    required this.codeObjectCorrelation,
    required this.createdAt,
    required this.scanned,
    required this.remaining,
  });

  factory OrderPosition.fromJson(Map<String, dynamic> json) {
    return OrderPosition(
      id: json['id'] ?? 0,
      size: json['size'].toString(),
      color: utf8.decode(json['color'].toString().runes.toList()),
      count: json['count'] ?? 0,
      customerOrderNumber: json['customer_order_number'].toString(),
      isCompleted: json['is_completed'] ?? false,
      codeObjectCorrelation: json['code_object_correlation'].toString(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      scanned: json['scanned'] ?? 0,
      remaining: json['remaining'] ?? 0,
    );
  }
}

class Order {
  final String orderId;
  final String specification;
  final String vendorModel;
  final bool isCompleted;
  final List<OrderPosition> positions;
  final int quantity;

  Order({
    required this.orderId,
    required this.specification,
    required this.vendorModel,
    required this.isCompleted,
    required this.positions,
    required this.quantity,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var positionsJson = json['positions'] as List<dynamic>?;
    List<OrderPosition> positionsList = positionsJson != null
        ? positionsJson.map((i) => OrderPosition.fromJson(i)).toList()
        : [];

    return Order(
      orderId: json['order_id'] ?? '',
      specification: utf8.decode(json['specification'].toString().runes.toList()),
      vendorModel: utf8.decode(json['vendor_model'].toString().runes.toList()),
      isCompleted: json['is_completed'] ?? false,
      positions: positionsList,
      quantity: json['quantity'] ?? 0,
    );
  }
}

class OrderRepository {
  final String apiUrl = 'http://uztexsoft.uz/api/orders/';

  Future<List<Order>> fetchOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Order.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Учетные данные не были предоставлены.');
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<Order> fetchOrderDetail(String orderId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$apiUrl$orderId/details/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      return Order.fromJson(body);
    } else if (response.statusCode == 401) {
      throw Exception('Учетные данные не были предоставлены.');
    } else {
      throw Exception('Failed to load order detail');
    }
  }
}

class OrdersPage extends StatefulWidget {
  final OrderRepository orderRepository = OrderRepository();

  OrdersPage({Key? key}) : super(key: key);

  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Order> allOrders = [];
  List<Order> filteredOrders = [];
  String searchModel = '';
  bool? filterStatus;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      allOrders = await widget.orderRepository.fetchOrders();
      filteredOrders = allOrders;
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void filterOrders() {
    List<Order> orders = allOrders;
    if (searchModel.isNotEmpty) {
      orders = orders.where((order) => order.vendorModel.toLowerCase().contains(searchModel.toLowerCase())).toList();
    }
    if (filterStatus != null) {
      orders = orders.where((order) => order.isCompleted == filterStatus).toList();
    }
    setState(() {
      filteredOrders = orders;
    });
  }

  void showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Фильтр по статусу'),
          content: Container(
            width: double.maxFinite,
            child: DropdownButtonFormField<bool?>(
              value: filterStatus,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              ),
              hint: Text('Выберите статус'),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text('Все'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Row(
                    children: [
                      Icon(Icons.pending, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('В процессе'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Готово'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  filterStatus = value;
                });
                filterOrders();
                Navigator.of(context).pop();
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  void navigateToOrderDetail(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailPage(orderId: order.orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Заказы',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Поиск по модели',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchModel = value;
                });
                filterOrders();
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text('Ошибка: $errorMessage', style: TextStyle(color: Colors.red)),
                ],
              ),
            )
                : filteredOrders.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, color: Colors.grey, size: 64),
                  SizedBox(height: 16),
                  Text('Ничего не найдено', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Icon(
                      order.isCompleted ? Icons.check_circle : Icons.pending,
                      color: order.isCompleted ? Colors.green : Colors.orange,
                    ),
                    title: Text(
                      'Заказ № ${order.orderId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description, size: 16.0, color: Colors.deepPurple),
                            SizedBox(width: 4),
                            Text('Спецификация: ${order.specification}'),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.model_training, size: 16.0, color: Colors.deepPurple),
                            SizedBox(width: 4),
                            Text('Модель: ${order.vendorModel}'),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(order.isCompleted ? Icons.check : Icons.timelapse, size: 16.0, color: Colors.deepPurple),
                            SizedBox(width: 4),
                            Text('Статус: ${order.isCompleted ? "Завершено" : "В процессе"}'),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.format_list_numbered, size: 16.0, color: Colors.deepPurple),
                            SizedBox(width: 4),
                            Text('Количество: ${numberFormat.format(order.quantity)} шт'),
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.deepPurple,
                    ),
                    onTap: () => navigateToOrderDetail(order),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

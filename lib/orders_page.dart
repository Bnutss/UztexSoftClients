import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'order_detail_page.dart';
import 'package:badges/badges.dart' as custom_badges;
import 'package:pull_to_refresh/pull_to_refresh.dart';

class OrderPosition {
  final int id;
  final String size;
  final String partNumber;
  final String color;
  final int count;
  final String customerOrderNumber;
  final bool isCompleted;
  final String codeObjectCorrelation;
  final DateTime createdAt;
  final int scanned;
  final int remaining;

  const OrderPosition({
    required this.id,
    required this.partNumber,
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

  factory OrderPosition.fromJson(Map json) {
    return OrderPosition(
      id: json['id'] ?? 0,
      size: json['size'].toString(),
      partNumber: json['part_number'].toString(),
      color: json['color'].toString(),
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
  final List positions;
  final int quantity;
  final double scannedPercentage;

  const Order({
    required this.orderId,
    required this.specification,
    required this.vendorModel,
    required this.isCompleted,
    required this.positions,
    required this.quantity,
    required this.scannedPercentage,
  });

  factory Order.fromJson(Map json) {
    var positionsJson = json['positions'] as List?;
    List positionsList = positionsJson != null
        ? positionsJson.map((i) => OrderPosition.fromJson(i)).toList()
        : [];
    return Order(
      orderId: json['order_id'] ?? '',
      specification: json['specification'].toString(),
      vendorModel: json['vendor_model'].toString(),
      isCompleted: json['is_completed'] ?? false,
      positions: positionsList,
      quantity: json['quantity'] ?? 0,
      scannedPercentage: (json['scanned_percentage'] ?? 0.0).toDouble(),
    );
  }
}

// Repository
class OrderRepository {
  static const String _apiUrl = 'https://uztexsoft.uz/api/orders/';

  Future<List<Order>> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final response = await http.get(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List body = json.decode(utf8.decode(response.bodyBytes));
      return body.map((item) => Order.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Учетные данные не были предоставлены.');
    } else {
      throw Exception('Не удалось загрузить заказы.');
    }
  }

  Future<Order> fetchOrderDetail(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final response = await http.get(
      Uri.parse('$_apiUrl$orderId/details/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      Map body = json.decode(utf8.decode(response.bodyBytes));
      return Order.fromJson(body);
    } else if (response.statusCode == 401) {
      throw Exception('Учетные данные не были предоставлены.');
    } else {
      throw Exception('Не удалось загрузить детали заказа.');
    }
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OrderRepository _orderRepository = OrderRepository();
  final _numberFormat = NumberFormat('#,##0', 'ru_RU');
  List _allOrders = [];
  List _filteredOrders = [];
  String _searchModel = '';
  bool? _filterStatus;
  bool _isLoading = false;
  String? _errorMessage;

  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _allOrders = await _orderRepository.fetchOrders();
      _filteredOrders = _allOrders;
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
      _refreshController.refreshCompleted();
    }
  }

  void _filterOrders() {
    var orders = _allOrders;
    if (_searchModel.isNotEmpty) {
      orders = orders.where((order) =>
          order.vendorModel.toLowerCase().contains(_searchModel.toLowerCase())
      ).toList();
    }
    if (_filterStatus != null) {
      orders = orders.where((order) => order.isCompleted == _filterStatus).toList();
    }
    setState(() => _filteredOrders = orders);
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 100) return Colors.green;
    if (percentage >= 75) return Colors.green.shade700;
    if (percentage >= 50) return Colors.orange;
    if (percentage >= 25) return Colors.orange.shade700;
    return Colors.red;
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(orderId: order.orderId),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: order.isCompleted
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          order.isCompleted ? Icons.check_circle : Icons.pending,
                          color: order.isCompleted ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Заказ № ${order.orderId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.specification,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.model_training, 'Артикул', order.vendorModel),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.format_list_numbered,
                    'Количество',
                    '${_numberFormat.format(order.quantity)} шт',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Прогресс сканирования',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.scannedPercentage)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${order.scannedPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: _getStatusColor(order.scannedPercentage),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: LinearProgressIndicator(
                value: order.scannedPercentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  _getStatusColor(order.scannedPercentage),
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Заказы',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
        actions: [
          custom_badges.Badge(
            position: custom_badges.BadgePosition.topEnd(top: 0, end: 3),
            badgeContent: Text(
              _allOrders.length.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              onPressed: () {},
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: SmartRefresher(
        enablePullDown: true,
        controller: _refreshController,
        onRefresh: _fetchOrders,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Поиск по модели',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() => _searchModel = value);
                  _filterOrders();
                },
              ),
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Ошибка: $_errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey[400], size: 64),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _filteredOrders.length,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Фильтр по статусу'),
        content: SizedBox(
          width: double.maxFinite,
          child: DropdownButtonFormField<bool?>(
            value: _filterStatus,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
            hint: const Text('Выберите статус'),
            isExpanded: true,
            items: const [
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
              setState(() => _filterStatus = value);
              _filterOrders();
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
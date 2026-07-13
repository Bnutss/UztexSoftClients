import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_detail_page.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';

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

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _allOrders = await _orderRepository.fetchOrders();
      _filteredOrders = List.from(_allOrders);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
      _refreshController.refreshCompleted();
    }
  }

  void _filterOrders() {
    var orders = List.from(_allOrders);
    if (_searchModel.isNotEmpty) {
      orders = orders.where((order) =>
        order.vendorModel.toLowerCase().contains(_searchModel.toLowerCase()) ||
        order.specification.toLowerCase().contains(_searchModel.toLowerCase()) ||
        order.orderId.toLowerCase().contains(_searchModel.toLowerCase())
      ).toList();
    }
    if (_filterStatus != null) {
      orders = orders.where((order) => order.isCompleted == _filterStatus).toList();
    }
    setState(() => _filteredOrders = orders);
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 100) return const Color(0xFF43A047);
    if (percentage >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFA726), Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Заказы',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_allOrders.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showFilterDialog,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Поиск заказа...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) {
                        setState(() => _searchModel = value);
                        _filterOrders();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_filterStatus != null || _searchModel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Text(
                    'Фильтры:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_filterStatus != null)
                    _buildFilterChip(
                      label: _filterStatus! ? 'Готово' : 'В процессе',
                      onRemove: () {
                        setState(() => _filterStatus = null);
                        _filterOrders();
                      },
                    ),
                  if (_searchModel.isNotEmpty)
                    _buildFilterChip(
                      label: '"$_searchModel"',
                      onRemove: () {
                        setState(() => _searchModel = '');
                        _filterOrders();
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: SmartRefresher(
              enablePullDown: true,
              header: const ClassicHeader(
                completeText: 'Обновлено',
                refreshingText: 'Загрузка...',
                idleText: 'Потяните вниз',
                releaseText: 'Отпустите',
                failedText: 'Ошибка',
              ),
              controller: _refreshController,
              onRefresh: _fetchOrders,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFE53935),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE53935)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.all(20),
        itemBuilder: (context, index) => _buildShimmerCard(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Ошибка загрузки',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _fetchOrders,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFA726), Color(0xFFE53935)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Повторить',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Пусто',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Заказы не найдены',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredOrders.length,
      padding: const EdgeInsets.all(20),
      itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.scannedPercentage);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OrderDetailPage(orderId: order.orderId)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          order.isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          color: statusColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Заказ № ${order.orderId}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.specification,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${order.scannedPercentage.toStringAsFixed(0)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Flexible(child: _buildInfoTag(Icons.style_rounded, order.vendorModel)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _buildInfoTag(
                          Icons.inventory_rounded,
                          '${_numberFormat.format(order.quantity)} шт',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: LinearProgressIndicator(
                value: order.scannedPercentage / 100,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Фильтр',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            _buildFilterOption(
              value: null,
              title: 'Все заказы',
              icon: Icons.all_inclusive_rounded,
              color: const Color(0xFF6366F1),
            ),
            _buildFilterOption(
              value: false,
              title: 'В процессе',
              icon: Icons.schedule_rounded,
              color: const Color(0xFFFFA726),
            ),
            _buildFilterOption(
              value: true,
              title: 'Готово',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF43A047),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required bool? value,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _filterStatus == value;

    return GestureDetector(
      onTap: () {
        setState(() => _filterStatus = value);
        _filterOrders();
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

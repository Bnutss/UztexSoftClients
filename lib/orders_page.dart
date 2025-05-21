import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_detail_page.dart';
import 'package:badges/badges.dart' as custom_badges;
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

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  final OrderRepository _orderRepository = OrderRepository();
  final _numberFormat = NumberFormat('#,##0', 'ru_RU');
  List _allOrders = [];
  List _filteredOrders = [];
  String _searchModel = '';
  bool? _filterStatus;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _fetchOrders();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      _animationController.reset();
      _animationController.forward();
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
    if (percentage >= 100) return Colors.green;
    if (percentage >= 75) return Colors.green.shade700;
    if (percentage >= 50) return Colors.orange;
    if (percentage >= 25) return Colors.orange.shade700;
    return Colors.red;
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailPage(orderId: order.orderId),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status and order number
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: order.isCompleted
                                ? Colors.green.withOpacity(0.1)
                                : const Color(0xFFFF9800).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            order.isCompleted ? Icons.check_circle_outline : Icons.pending_outlined,
                            color: order.isCompleted ? Colors.green : const Color(0xFFFF9800),
                            size: 26,
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.specification,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.scannedPercentage).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${order.scannedPercentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              color: _getStatusColor(order.scannedPercentage),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Order details
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.style_outlined,
                            label: 'Артикул',
                            value: order.vendorModel,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.format_list_numbered_outlined,
                            label: 'Количество',
                            value: '${_numberFormat.format(order.quantity)} шт',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Progress label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Прогресс сканирования',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${order.scannedPercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            color: _getStatusColor(order.scannedPercentage),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Progress indicator
              Container(
                height: 8,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  color: Color(0xFFEEEEEE),
                ),
                child: Row(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width *
                          (order.scannedPercentage / 100) * 0.9, // Adjust for margins
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: order.scannedPercentage >= 100
                              ? [Colors.green.shade400, Colors.green.shade700]
                              : [const Color(0xFFFF9800), const Color(0xFFE53935)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFFE53935),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Градиентный фон
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFE53935)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Основной контент
          SafeArea(
            child: Column(
              children: [
                // Верхняя панель с заголовком и кнопками
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Заказы',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: custom_badges.Badge(
                          position: custom_badges.BadgePosition.topEnd(top: 0, end: 3),
                          badgeStyle: const custom_badges.BadgeStyle(
                            badgeColor: Colors.green,
                            padding: EdgeInsets.all(6),
                          ),
                          badgeContent: Text(
                            _allOrders.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                            onPressed: () {},
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.filter_list, color: Colors.white),
                          onPressed: _showFilterDialog,
                          tooltip: 'Фильтр',
                        ),
                      ),
                    ],
                  ),
                ),

                // Поле поиска
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: TextField(
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Поиск по модели или номеру',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFE53935)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (value) {
                        setState(() => _searchModel = value);
                        _filterOrders();
                      },
                    ),
                  ),
                ),

                // Статус фильтра
                if (_filterStatus != null || _searchModel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Text(
                          'Активные фильтры:',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_filterStatus != null)
                          _buildFilterChip(
                            label: _filterStatus! ? 'Готово' : 'В процессе',
                            color: _filterStatus! ? Colors.green : Colors.orange,
                            onRemove: () {
                              setState(() => _filterStatus = null);
                              _filterOrders();
                            },
                          ),
                        if (_searchModel.isNotEmpty)
                          _buildFilterChip(
                            label: '"$_searchModel"',
                            color: const Color(0xFFE53935),
                            onRemove: () {
                              setState(() => _searchModel = '');
                              _filterOrders();
                            },
                          ),
                      ],
                    ),
                  ),

                // Содержимое списка
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: SmartRefresher(
                      enablePullDown: true,
                      header: const ClassicHeader(
                        refreshStyle: RefreshStyle.Follow,
                        completeText: 'Обновлено',
                        refreshingText: 'Обновление...',
                        idleText: 'Потяните вниз для обновления',
                        releaseText: 'Отпустите для обновления',
                        failedText: 'Ошибка обновления',
                        completeIcon: Icon(Icons.done, color: Colors.green),
                      ),
                      controller: _refreshController,
                      onRefresh: _fetchOrders,
                      child: _buildContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        itemBuilder: (context, index) => _buildShimmerCard(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ошибка загрузки',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_outlined,
                color: Colors.grey[400],
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ничего не найдено',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Измените параметры поиска или сбросьте фильтры',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_filterStatus != null || _searchModel.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _filterStatus = null;
                    _searchModel = '';
                  });
                  _filterOrders();
                },
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Сбросить фильтры'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: ListView.builder(
        itemCount: _filteredOrders.length,
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Фильтр по статусу',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption(
                value: null,
                title: 'Все заказы',
                subtitle: 'Показать все заказы',
                icon: Icons.all_inclusive,
                iconColor: Colors.deepPurple,
              ),
              _buildFilterOption(
                value: false,
                title: 'В процессе',
                subtitle: 'Заказы в работе',
                icon: Icons.pending_outlined,
                iconColor: Colors.orange,
              ),
              _buildFilterOption(
                value: true,
                title: 'Готово',
                subtitle: 'Завершенные заказы',
                icon: Icons.check_circle_outline,
                iconColor: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required bool? value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _filterStatus == value;

    return Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () {
      setState(() => _filterStatus = value);
      _filterOrders();
      Navigator.of(context).pop();
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
    border: Border(
    bottom: BorderSide(
    color: Colors.grey[200]!,
    width: 1,
    ),
    ),
    ),
    child: Row(
    children: [
    Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
    color: iconColor.withOpacity(0.1),
    shape: BoxShape.circle,
    ),
    child: Icon(
    icon,
    color: iconColor,
    size: 24,
    ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    title,
    style: GoogleFonts.poppins(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: Colors.grey[800],
    ),
    ),
    Text(
    subtitle,
    style: GoogleFonts.poppins(
    color: Colors.grey[600],
    fontSize: 12,
    ),
    ),
    ],
    ),
    ),
      if (isSelected)
        const Icon(
          Icons.check_circle,
          color: Color(0xFFE53935),
          size: 24,
        ),
    ],
    ),
    ),
        ),
    );
  }
}

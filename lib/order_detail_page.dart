import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  _OrderDetailPageState createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> with SingleTickerProviderStateMixin {
  Order? order;
  bool isLoading = true;
  String? errorMessage;
  String? token;
  String? telegramId;
  String searchQuery = '';
  bool isSendingFile = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

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
    _loadTokenAndTelegramId();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      token = prefs.getString('access_token') ?? '';
      telegramId = prefs.getString('id_telegram') ?? '';
    });
    fetchOrderDetail();
  }

  Future<void> fetchOrderDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (token == null || token!.isEmpty) {
        throw Exception('Токен не найден');
      }

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
        _animationController.reset();
        _animationController.forward();
      } else {
        setState(() {
          errorMessage = 'Ошибка при загрузке деталей заказа: ${response.statusCode}';
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

    setState(() {
      isSendingFile = true;
    });

    final url = 'https://uztexsoft.uz/api/orders/${widget.orderId}/details/excel/';
    try {
      if (token == null || token!.isEmpty) {
        throw Exception('Токен не найден');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      );

      setState(() {
        isSendingFile = false;
      });

      if (response.statusCode == 200) {
        _showSuccessMessage('Excel файл успешно отправлен через Telegram');
      } else {
        _showErrorMessage('Ошибка отправки Excel файла: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isSendingFile = false;
      });
      _showErrorMessage('Ошибка: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
        position.size.toLowerCase().contains(searchQuery.toLowerCase()) ||
        position.color.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList() ??
        [];
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 1.0) return Colors.green;
    if (percentage >= 0.75) return Colors.green.shade700;
    if (percentage >= 0.5) return const Color(0xFFFF9800);
    if (percentage >= 0.25) return Colors.orange.shade700;
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'ru_RU');

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Заказ №${widget.orderId}',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(totalProgress).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Прогресс: $progressPercentage',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: isSendingFile
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: isSendingFile ? null : sendFile,
                          tooltip: 'Отправить Excel файл',
                        ),
                      ),
                    ],
                  ),
                ),

                // Индикатор прогресса
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Container(
                        height: 10,
                        width: MediaQuery.of(context).size.width * 0.9 * totalProgress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: totalProgress >= 1.0
                                ? [Colors.green.shade400, Colors.green.shade700]
                                : [Colors.orange, Colors.red],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Поле поиска
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
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
                        hintText: 'Поиск по артикулу, размеру или цвету',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFE53935)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),

                // Количество позиций
                if (!isLoading && order != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Всего позиций: ${order!.positions.length}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Найдено: ${filteredPositions.length}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Содержимое позиций
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: RefreshIndicator(
                      onRefresh: fetchOrderDetail,
                      child: _buildContent(numberFormat),
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

  Widget _buildContent(NumberFormat numberFormat) {
    if (isLoading) {
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
        itemBuilder: (context, index) => _buildShimmerCard(),
      );
    }

    if (errorMessage != null) {
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
                errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: fetchOrderDetail,
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

    if (order == null) {
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
              'Нет данных о заказе',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    if (filteredPositions.isEmpty) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Попробуйте изменить параметры поиска',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: ListView.builder(
        itemCount: filteredPositions.length,
        padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final position = filteredPositions[index];
          final progress = position.count > 0 ? position.scanned / position.count : 0.0;
          final isComplete = position.scanned == position.count;

          return _buildPositionCard(position, progress, isComplete, numberFormat);
        },
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildPositionCard(Position position, double progress, bool isComplete, NumberFormat numberFormat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status and size
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isComplete
                            ? Colors.green.withOpacity(0.1)
                            : const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isComplete ? Icons.check_circle_outline : Icons.pending_outlined,
                        color: isComplete ? Colors.green : const Color(0xFFFF9800),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Размер: ${position.size}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Артикул: ${position.part_number}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
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
                        color: _getStatusColor(progress).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          color: _getStatusColor(progress),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Details
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.color_lens_outlined,
                        label: 'Цвет',
                        value: position.color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.format_list_numbered_outlined,
                        label: 'Количество',
                        value: '${numberFormat.format(position.count)} шт',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Scanning progress
                Row(
                  children: [
                    Expanded(
                      child: _buildScanningItem(
                        icon: Icons.check_circle_outline,
                        label: 'Сканировано',
                        value: '${numberFormat.format(position.scanned)} шт',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildScanningItem(
                        icon: Icons.remove_circle_outline,
                        label: 'Осталось',
                        value: '${numberFormat.format(position.count - position.scanned)} шт',
                        color: Colors.red,
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
                  width: MediaQuery.of(context).size.width * progress * 0.9, // Adjust for margins
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: progress >= 1.0
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

  Widget _buildScanningItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class Order {
  final List<Position> positions;

  Order({required this.positions});

  factory Order.fromJson(Map<String, dynamic> json) {
    var positionsList = json['positions'] as List? ?? [];
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
      part_number: json['part_number'] ?? '',
      color: json['color'] ?? '',
      size: json['size'] ?? '',
      count: json['count'] ?? 0,
      scanned: json['scanned'] ?? 0,
    );
  }
}
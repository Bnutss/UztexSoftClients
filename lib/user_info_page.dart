import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class UserInfoPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserInfoPage({Key? key, required this.userData}) : super(key: key);

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> with SingleTickerProviderStateMixin {
  late TextEditingController _emailController;
  late TextEditingController _telegramIdController;
  late String _token;
  bool _isLoading = false;
  bool _isEditing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  static const platform = MethodChannel('com.example.uztexsoftclients/telegram');

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userData['email']);
    _telegramIdController = TextEditingController(text: widget.userData['userprofile']?['id_telegram'] ?? '');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadTokenAndRefreshData();
  }

  Future<void> _loadTokenAndRefreshData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token') ?? '';
    _refreshUserData(showSnackbar: false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _telegramIdController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshUserData({bool showSnackbar = true}) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('https://uztexsoft.uz/api/user/');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final userData = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _emailController.text = userData['email'];
          _telegramIdController.text = userData['userprofile']?['id_telegram'] ?? '';
        });
        if (showSnackbar) {
          _showSuccessMessage('Данные успешно обновлены');
        }
      } else {
        if (showSnackbar) {
          _showErrorMessage('Ошибка обновления данных');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (showSnackbar) {
        _showErrorMessage('Ошибка сети: $e');
      }
    }
  }

  Future<void> _updateUserData() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('https://uztexsoft.uz/api/user/update/');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'email': _emailController.text,
          'userprofile': {
            'id_telegram': _telegramIdController.text,
          },
        }),
      );

      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('id_telegram', _telegramIdController.text);

        setState(() {
          widget.userData['email'] = _emailController.text;
          if (widget.userData['userprofile'] == null) {
            widget.userData['userprofile'] = {};
          }
          widget.userData['userprofile']['id_telegram'] = _telegramIdController.text;
        });
        _showSuccessMessage('Данные успешно сохранены');
      } else {
        _showErrorMessage('Ошибка обновления данных');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage('Ошибка сети: $e');
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
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _launchTelegramMyIdBot() async {
    const url = 'tg://resolve?domain=myidbot&start=getid';
    try {
      await platform.invokeMethod('openTelegram', {'url': url});
    } on PlatformException catch (e) {
      _showErrorMessage('Не удалось открыть Telegram: ${e.message}');
    }
  }

  void _launchTelegramUztexsoftBot() async {
    const url = 'tg://resolve?domain=uztexsoftbot&start=start';
    try {
      await platform.invokeMethod('openTelegram', {'url': url});
    } on PlatformException catch (e) {
      _showErrorMessage('Не удалось открыть Telegram: ${e.message}');
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
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

          // Декоративные элементы
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Основное содержимое
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
                          'Профиль',
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
                        child: IconButton(
                          icon: Icon(
                            _isEditing ? Icons.close : Icons.edit,
                            color: Colors.white,
                          ),
                          onPressed: _toggleEditMode,
                          tooltip: _isEditing ? 'Отменить' : 'Редактировать',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => _refreshUserData(),
                          tooltip: 'Обновить',
                        ),
                      ),
                    ],
                  ),
                ),

                // Содержимое профиля
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 16.0),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Аватар пользователя
                            Hero(
                              tag: 'userAvatar',
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF9800), Color(0xFFE53935)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Имя пользователя
                            Text(
                              widget.userData['username'] ?? 'Пользователь',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              widget.userData['customer']?['name'] ?? 'Гость',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Информационные карточки
                            _buildSectionTitle('Основная информация'),
                            _buildInfoCard(
                              title: 'Имя пользователя',
                              value: widget.userData['username'] ?? 'Не указано',
                              icon: Icons.account_circle_outlined,
                              isEditable: false,
                            ),
                            _buildInfoCard(
                              title: 'Электронная почта',
                              controller: _emailController,
                              icon: Icons.email_outlined,
                              isEditable: _isEditing,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _buildInfoCard(
                              title: 'Компания',
                              value: widget.userData['customer']?['name'] ?? 'Не указано',
                              icon: Icons.business_outlined,
                              isEditable: false,
                            ),
                            const SizedBox(height: 24),

                            // Telegram информация
                            _buildSectionTitle('Telegram'),
                            _buildInfoCard(
                              title: 'ID Telegram',
                              controller: _telegramIdController,
                              icon: Icons.send_outlined,
                              isEditable: _isEditing,
                              keyboardType: TextInputType.number,
                            ),

                            if (_isEditing) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _launchTelegramMyIdBot,
                                      icon: const Icon(Icons.person_search_outlined),
                                      label: const Text('Узнать ID'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF9800),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _launchTelegramUztexsoftBot,
                                      icon: const Icon(Icons.open_in_new_outlined),
                                      label: const Text('Открыть бота'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE53935),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            if (_isEditing) ...[
                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _updateUserData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE53935),
                                    foregroundColor: Colors.white,
                                    elevation: 5,
                                    shadowColor: Colors.redAccent.withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'СОХРАНИТЬ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Индикатор загрузки
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    String? value,
    TextEditingController? controller,
    required IconData icon,
    required bool isEditable,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFE53935),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            isEditable && controller != null
                ? TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Введите $title',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400],
                ),
              ),
            )
                : Text(
              value ?? controller?.text ?? 'Не указано',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
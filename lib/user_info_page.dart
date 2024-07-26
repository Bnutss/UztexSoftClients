import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class UserInfoPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserInfoPage({Key? key, required this.userData}) : super(key: key);

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  late TextEditingController _emailController;
  late TextEditingController _telegramIdController;
  late String _token;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userData['email']);
    _telegramIdController = TextEditingController(text: widget.userData['userprofile']['id_telegram'] ?? '');
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
    super.dispose();
  }

  Future<void> _refreshUserData({bool showSnackbar = true}) async {
    final url = Uri.parse('http://uztexsoft.uz/api/user/');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode == 200) {
      final userData = json.decode(response.body);
      setState(() {
        _emailController.text = userData['email'];
        _telegramIdController.text = userData['userprofile']['id_telegram'] ?? '';
      });
      if (showSnackbar) {
        _showSnackBar('Данные успешно обновлены', Colors.green);
      }
    } else {
      if (showSnackbar) {
        _showSnackBar('Ошибка обновления данных', Colors.red);
      }
    }
  }

  Future<void> _updateUserData() async {
    final url = Uri.parse('http://uztexsoft.uz/api/user/update/');
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

    if (response.statusCode == 200) {
      setState(() {
        widget.userData['email'] = _emailController.text;
        widget.userData['userprofile']['id_telegram'] = _telegramIdController.text;
      });
      _showSnackBar('Данные успешно обновлены', Colors.green);
    } else {
      _showSnackBar('Ошибка обновления данных', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _launchTelegramBot() async {
    const url = 'https://t.me/uztexsoftbot?start=start';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showSnackBar('Не удалось открыть Telegram', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о пользователе', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _refreshUserData(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUserInfoCard(
              icon: Icons.person,
              label: 'Имя пользователя',
              value: widget.userData['username'],
              isEditable: false,
            ),
            _buildUserInfoCard(
              icon: Icons.email,
              label: 'Почта',
              controller: _emailController,
              isEditable: true,
            ),
            _buildUserInfoCard(
              icon: Icons.telegram,
              label: 'ID Телеграмм',
              controller: _telegramIdController,
              isEditable: true,
              showTelegramButton: true,
            ),
            _buildUserInfoCard(
              icon: Icons.business,
              label: 'Клиент',
              value: widget.userData['customer']?['name'],
              isEditable: false,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateUserData,
        child: const Icon(Icons.save, color: Colors.white),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildUserInfoCard({
    required IconData icon,
    required String label,
    String? value,
    TextEditingController? controller,
    required bool isEditable,
    bool showTelegramButton = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple),
                const SizedBox(width: 10.0),
                Text(
                  label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (showTelegramButton) ...[
                  Spacer(),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepPurple),
                    onPressed: _launchTelegramBot,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10.0),
            isEditable
                ? TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.all(10.0),
              ),
            )
                : Text(
              value ?? 'Не указано',
              style: const TextStyle(fontSize: 16),
            ),
            if (showTelegramButton) ...[
              const SizedBox(height: 10.0),
              Center(
                child: Text(
                  'Запустите бота для отправки данных по заказу',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'user_info_page.dart';
import 'confidentiality_page.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;

  const SettingsPage({Key? key, required this.userData, required this.token}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки приложения', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 20),
              _buildSettingsSection(
                context,
                'Учетная запись',
                [
                  _buildSettingsItem(
                    context,
                    icon: Icons.account_circle,
                    title: 'Профиль',
                    subtitle: 'Редактировать профиль',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserInfoPage(userData: widget.userData),
                        ),
                      );
                    },
                  ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.lock,
                    title: 'Конфиденциальность',
                    subtitle: 'Настройки конфиденциальности',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConfidentialityPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Text(
              'Версия 1.0.1',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.blueGrey[700]),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: Icon(Icons.chevron_right, color: Colors.blueGrey[700]),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'info_page.dart';
import 'orders_page.dart';

class MenuPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String token;

  const MenuPage({Key? key, required this.userData, required this.token}) : super(key: key);

  void _logout(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage(userData: userData, token: token)),
    );
  }

  void _openOrdersPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrdersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Главное меню',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.info, color: Colors.white),
            onPressed: () => _openSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: () => _openOrdersPage(context),
                  icon: const Icon(Icons.assignment, color: Colors.white),
                  label: const Text(
                    'Заказы',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

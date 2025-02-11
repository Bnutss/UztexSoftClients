import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, dynamic> _localConfig = {
    'appTitle': 'UztexSoft Clients',
  };

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  void _fetchConfig() async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _localConfig['appTitle'] = 'UztexSoft Updated Clients';
      });
    } catch (e) {
      print('Failed to fetch config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _localConfig['appTitle'] ?? 'UztexSoft Clients',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'), // Russian locale
      ],
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; 
import 'package:google_fonts/google_fonts.dart';

import 'db/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/inventory_home.dart';
import 'screens/splash_screen.dart';
import 'screens/category_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    runApp(const MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    ));

    await initializeApp();
  }, (error, stack) {
  });
}

Future<void> initializeApp() async {
  try {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.init();

    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('userId');
    final bool isDarkMode = prefs.getBool('isDarkMode') ?? false;

    runApp(MyApp(
      isLoggedIn: userId != null,
      dbHelper: dbHelper,
      isDarkMode: isDarkMode,
    ));
  } catch (e) {

    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text('Failed to initialize app', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text('Error: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await initializeApp();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    ));
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final DatabaseHelper dbHelper;
  final bool isDarkMode;

  const MyApp({
    Key? key,
    required this.isLoggedIn,
    required this.dbHelper,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    _initThemeMode();
  }
  
  Future<void> _initThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeModeString = prefs.getString('themeMode');
    
    if (themeModeString != null) {
      setState(() {
        if (themeModeString == 'system') {
          _themeMode = ThemeMode.system;
        } else if (themeModeString == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.light;
        }
      });
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.system 
                                      ? 'system' 
                                      : (mode == ThemeMode.dark ? 'dark' : 'light'));
    await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
  }

  void _toggleTheme(ThemeMode mode) async {
    _setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2C6BED); // Modern blue
    const Color secondaryColor = Color(0xFF38B28C); // Fresh teal
    const Color lightSurfaceColor = Color(0xFFF8F9FA);
    const Color darkSurfaceColor = Color(0xFF121212);
    
    final textTheme = GoogleFonts.montserratTextTheme();
    
    return MaterialApp(
      title: 'Inventory Management',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: lightSurfaceColor,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
        ),
        textTheme: textTheme,
        scaffoldBackgroundColor: lightSurfaceColor,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(primaryColor),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            padding: MaterialStateProperty.all<EdgeInsets>(
              const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: darkSurfaceColor,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: darkSurfaceColor,
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade800,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      themeMode: _themeMode,
      home: widget.isLoggedIn
          ? InventoryHomePage(
              dbHelper: widget.dbHelper,
              toggleTheme: _toggleTheme,
              isDarkMode: _themeMode == ThemeMode.dark,
              themeMode: _themeMode,
            )
          : LoginScreen(dbHelper: widget.dbHelper),
      routes: {
        '/login': (context) => LoginScreen(dbHelper: widget.dbHelper),
        '/signup': (context) => SignupScreen(dbHelper: widget.dbHelper),
        '/home': (context) => InventoryHomePage(
              dbHelper: widget.dbHelper,
              toggleTheme: _toggleTheme,
              isDarkMode: _themeMode == ThemeMode.dark,
              themeMode: _themeMode,
            ),
        '/categories': (context) => CategoryScreen(dbHelper: widget.dbHelper),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
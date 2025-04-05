// inventory_home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// New imports for UI modernization
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:lottie/lottie.dart';
import 'package:animations/animations.dart';

import '../db/database_helper.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../models/category.dart';
import 'item_form.dart';
import 'category_screen.dart';
import 'account_settings_screen.dart';
import 'sales_report_screen.dart';

class InventoryHomePage extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final Function(ThemeMode) toggleTheme;
  final bool isDarkMode;
  final ThemeMode themeMode;

  const InventoryHomePage({
    Key? key,
    required this.dbHelper,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.themeMode,
  }) : super(key: key);

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Item> _items = [];
  User? _currentUser;
  bool _isLoading = true;
  String _searchQuery = '';
  int? _selectedCategoryId;
  List<Category> _categories = [];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  // Animation controllers
  final List<bool> _animatedItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUserAndItems();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId != null) {
        _currentUser = await widget.dbHelper.getUserById(userId);
        await _loadCategories();
        await _loadItems();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await widget.dbHelper.getCategories();
      setState(() {});
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadItems() async {
    if (_currentUser != null) {
      _items = await widget.dbHelper.getItems(
        userId: _currentUser!.id,
        categoryId: _selectedCategoryId,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      setState(() {});
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      PermissionStatus status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        return false;
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
        return false;
      }
    }
    return true;
  }

  Future<void> _generatePdfReport() async {
    try {
      // First check permissions
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required')),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating PDF report...')),
        );
      }

      final pdf = pw.Document();

      // Calculate inventory statistics
      final totalItems = _items.length;
      final totalCategories = _categories.length;
      final totalValue = _calculateTotalValue();
      final lowStockItems = _items.where((item) => item.quantity < 10).toList();

      // Group items by category
      final categoryMap = <String, List<Item>>{};
      for (final item in _items) {
        String categoryName = 'Uncategorized';
        if (item.categoryId != null) {
          final category = _categories.firstWhere(
            (c) => c.id == item.categoryId,
            orElse: () => Category(name: 'Uncategorized'),
          );
          categoryName = category.name;
        }

        if (!categoryMap.containsKey(categoryName)) {
          categoryMap[categoryName] = [];
        }
        categoryMap[categoryName]!.add(item);
      }

      // Cover page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'INVENTORY REPORT',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    _currentUser?.username ?? 'Inventory Management',
                    style: const pw.TextStyle(fontSize: 20),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated on ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'at ${DateFormat('hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Summary page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text('Inventory Summary'),
                ),
                pw.SizedBox(height: 20),

                // Summary table
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Metric',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Value',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    _buildSummaryRow('Total Items', totalItems.toString()),
                    _buildSummaryRow('Total Categories', totalCategories.toString()),
                    _buildSummaryRow('Total Inventory Value', '\$${totalValue.toStringAsFixed(2)}'),
                    _buildSummaryRow('Low Stock Items', lowStockItems.length.toString()),
                  ],
                ),

                pw.SizedBox(height: 30),

                pw.Text(
                  'Category Distribution',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                // Category distribution
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Category',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Items',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Value',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    ...categoryMap.entries.map((entry) {
                      final categoryValue = entry.value.fold(
                        0.0,
                        (sum, item) => sum + (item.price * item.quantity),
                      );
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(entry.key),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(entry.value.length.toString()),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('\$${categoryValue.toStringAsFixed(2)}'),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Low stock items page
      if (lowStockItems.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Text('Low Stock Items'),
                  ),
                  pw.Paragraph(
                    text: 'Items with quantity less than 10 units',
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table.fromTextArray(
                    context: context,
                    border: null,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    headerHeight: 25,
                    cellHeight: 40,
                    headerStyle: pw.TextStyle(
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    cellStyle: const pw.TextStyle(color: PdfColors.black),
                    headers: ['Item', 'Category', 'Quantity', 'Price'],
                    data: lowStockItems
                      .map(
                        (item) => [
                          item.name,
                          _getCategoryName(item.categoryId) ?? 'N/A',
                          item.quantity.toString(),
                          '\$${item.price.toStringAsFixed(2)}',
                        ],
                      )
                      .toList(),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Category-wise inventory pages
      for (final entry in categoryMap.entries) {
        final categoryName = entry.key;
        final categoryItems = entry.value;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Text('Category: $categoryName'),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Paragraph(
                    text: 'Total Items: ${categoryItems.length}',
                  ),
                  pw.Paragraph(
                    text: 'Total Value: \$${categoryItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity)).toStringAsFixed(2)}',
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table.fromTextArray(
                    context: context,
                    border: null,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    headerHeight: 25,
                    cellHeight: 40,
                    headerStyle: pw.TextStyle(
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    cellStyle: const pw.TextStyle(color: PdfColors.black),
                    headers: ['Item', 'Quantity', 'Unit Price', 'Total Value'],
                    data: categoryItems
                      .map(
                        (item) => [
                          item.name,
                          item.quantity.toString(),
                          '\$${item.price.toStringAsFixed(2)}',
                          '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                        ],
                      )
                      .toList(),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Full inventory list
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Complete Inventory List'),
            ),
            pw.Paragraph(
              text: 'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              border: null,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              headerHeight: 25,
              cellHeight: 40,
              headerStyle: pw.TextStyle(
                color: PdfColors.black,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(color: PdfColors.black),
              headers: ['Item', 'Category', 'Quantity', 'Unit Price', 'Total Value'],
              data: _items
                .map(
                  (item) => [
                    item.name,
                    _getCategoryName(item.categoryId) ?? 'N/A',
                    item.quantity.toString(),
                    '\$${item.price.toStringAsFixed(2)}',
                    '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                  ],
                )
                .toList(),
            ),
          ],
        ),
      );

      // Save the file
      var directory = '/storage/emulated/0/Inventory_App';
      if (Platform.isAndroid) {
        final dir = Directory(directory);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      final fileName = 'inventory_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final path = '$directory/$fileName';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $path'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: ${e.toString()}')),
        );
      }
    }
  }

  pw.TableRow _buildSummaryRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value),
        ),
      ],
    );
  }

  String? _getCategoryName(int? categoryId) {
    if (categoryId == null) return null;

    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(name: 'Unknown'),
    );

    return category.name;
  }

  void _toggleTheme() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: widget.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  widget.toggleTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: widget.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  widget.toggleTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: widget.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  widget.toggleTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Inventory Management',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ).animate().fadeIn(duration: 600.ms),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              _showUserProfileModal();
            },
          ).animate().scale(delay: 200.ms),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdfReport,
          ).animate().scale(delay: 300.ms),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : IndexedStack(
              index: _tabController.index,
              children: [
                _buildItemsTab().animate().fadeIn(duration: 400.ms),
                _buildDashboardTab().animate().fadeIn(duration: 400.ms),
                _buildSettingsTab().animate().fadeIn(duration: 400.ms),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabController.index,
        onTap: (index) {
          setState(() {
            _tabController.index = index;
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://assets10.lottiefiles.com/packages/lf20_usmfx6bp.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your inventory...',
            style: GoogleFonts.montserrat(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_tabController.index != 0) return const SizedBox.shrink();
    
    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 500),
      transitionType: ContainerTransitionType.fadeThrough,
      openBuilder: (context, _) => ItemFormScreen(
        dbHelper: widget.dbHelper,
        userId: _currentUser!.id!,
        onItemSaved: () {
          _loadItems();
        },
      ),
      closedElevation: 6.0,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      closedColor: Theme.of(context).colorScheme.primary,
      closedBuilder: (context, openContainer) {
        return SizedBox(
          height: 56,
          width: 56,
          child: Center(
            child: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        );
      },
    ).animate().scale(delay: 400.ms);
  }

  void _showUserProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _currentUser?.username.substring(0, 1).toUpperCase() ?? 'U',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.username ?? 'User',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentUser?.email ?? 'Email not available',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn().slide(begin: const Offset(0, 0.5)),
              const SizedBox(height: 24),
              _buildProfileOption(
                icon: Icons.settings,
                title: 'Account Settings',
                onTap: () {
                  Navigator.pop(context);
                  if (_currentUser != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountSettingsScreen(
                          dbHelper: widget.dbHelper,
                          user: _currentUser!,
                        ),
                      ),
                    ).then((_) {
                      _loadUserAndItems();
                    });
                  }
                },
              ),
              _buildProfileOption(
                icon: Icons.logout,
                title: 'Logout',
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutConfirmation();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slide(begin: const Offset(0, 0.3));
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout Confirmation',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout from your account?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.montserrat(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _items.isEmpty
              ? _buildEmptyState()
              : _buildItemsList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _searchFocusNode.unfocus();
              setState(() {
                _searchQuery = value;
              });
              _loadItems();
            },
            decoration: InputDecoration(
              hintText: 'Search inventory...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade100
                  : Colors.grey.shade800,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _loadItems();
                      },
                    )
                  : null,
            ),
            style: GoogleFonts.montserrat(),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    'All Categories',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: _selectedCategoryId == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategoryId = null;
                    });
                    _loadItems();
                  },
                  backgroundColor: Theme.of(context).cardColor,
                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                ).animate().fadeIn(delay: 100.ms).slide(begin: const Offset(0, 0.5)),
                const SizedBox(width: 8),
                ..._categories.map((category) {
                  final categoryColor = category.color != null
                      ? Color(int.parse(category.color!.replaceAll('#', '0xFF')))
                      : Theme.of(context).colorScheme.primary;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        category.name,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: _selectedCategoryId == category.id ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedCategoryId == category.id,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryId = selected ? category.id : null;
                        });
                        _loadItems();
                      },
                      backgroundColor: Theme.of(context).cardColor,
                      selectedColor: categoryColor.withOpacity(0.2),
                      checkmarkColor: categoryColor,
                    ).animate().fadeIn(delay: 100.ms * (_categories.indexOf(category) + 1)).slide(begin: const Offset(0, 0.5)),
                  );
                }),
                const SizedBox(width: 8),
                ActionChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Manage',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                    ],
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryScreen(dbHelper: widget.dbHelper),
                      ),
                    ).then((_) {
                      _loadCategories();
                      _loadItems();
                    });
                  },
                  backgroundColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey.shade200
                      : Colors.grey.shade800,
                ).animate().fadeIn(delay: 100.ms * (_categories.length + 1)).slide(begin: const Offset(0, 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://assets2.lottiefiles.com/packages/lf20_qm8403ke.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 24),
          Text(
            'No items found',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategoryId != null
                ? 'Try changing your search or filter'
                : 'Start by adding your first inventory item',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty && _selectedCategoryId == null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ItemFormScreen(
                      dbHelper: widget.dbHelper,
                      userId: _currentUser!.id!,
                      onItemSaved: () {
                        _loadItems();
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(
                'Add Item',
                style: GoogleFonts.montserrat(),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    // Ensure all items have animation state
    while (_animatedItems.length < _items.length) {
      _animatedItems.add(false);
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCategories();
        await _loadItems();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          // Trigger animation after a delay based on index
          Future.delayed(Duration(milliseconds: 50 * index), () {
            if (mounted && index < _animatedItems.length) {
              setState(() {
                _animatedItems[index] = true;
              });
            }
          });
          
          return _buildItemCard(index);
        },
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final isAnimated = index < _animatedItems.length ? _animatedItems[index] : false;
    
    // Find the category color if available
    Color itemColor = Theme.of(context).colorScheme.primary;
    if (item.categoryId != null) {
      final category = _categories.firstWhere(
        (c) => c.id == item.categoryId,
        orElse: () => Category(name: 'Unknown'),
      );

      if (category.color != null) {
        // Convert hex color string to Color
        itemColor = Color(
          int.parse(category.color!.replaceAll('#', '0xFF')),
        );
      }
    }

    return Dismissible(
      key: Key(item.id.toString()),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Confirm Delete',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete ${item.name}?',
              style: GoogleFonts.montserrat(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.montserrat(),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.montserrat(),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await widget.dbHelper.deleteItem(item.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.name} deleted',
              style: GoogleFonts.montserrat(),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                // You would need to implement an undo feature here
                _loadItems();
              },
            ),
          ),
        );
        _loadItems();
      },
      child: OpenContainer(
        transitionDuration: const Duration(milliseconds: 500),
        openBuilder: (context, _) => ItemFormScreen(
          dbHelper: widget.dbHelper,
          userId: _currentUser!.id!,
          item: item,
          onItemSaved: () {
            _loadItems();
          },
        ),
        closedElevation: 0,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        closedColor: Colors.transparent,
        closedBuilder: (context, openContainer) {
          return Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: openContainer,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Category color indicator and item initial
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: itemColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          item.name.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: itemColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCategoryName(item.categoryId) ?? 'Uncategorized',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildItemAttribute(
                                icon: Icons.inventory_2_outlined,
                                value: item.quantity.toString(),
                                color: _getQuantityColor(item.quantity),
                              ),
                              const SizedBox(width: 16),
                              _buildItemAttribute(
                                icon: Icons.attach_money,
                                value: '\$${item.price.toStringAsFixed(2)}',
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Total value
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade100
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'total value',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ).animate(target: isAnimated ? 1 : 0)
            .fade(duration: 400.ms)
            .slide(begin: const Offset(0.5, 0), duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildItemAttribute({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getQuantityColor(int quantity) {
    if (quantity <= 5) return Colors.red;
    if (quantity <= 10) return Colors.orange;
    return Colors.green;
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCategories();
        await _loadItems();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInventorySummaryCard(),
            const SizedBox(height: 20),
            _buildLowStockCard(),
            const SizedBox(height: 20),
            _buildCategoryChartCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inventory Summary',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.2, duration: 400.ms),
            const SizedBox(height: 24),
            StaggeredGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                StaggeredGridTile.fit(
                  crossAxisCellCount: 1,
                  child: _buildSummaryTile(
                    title: 'Total Items',
                    value: _items.length.toString(),
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                    delay: 0,
                  ),
                ),
                StaggeredGridTile.fit(
                  crossAxisCellCount: 1,
                  child: _buildSummaryTile(
                    title: 'Categories',
                    value: _categories.length.toString(),
                    icon: Icons.category,
                    color: Colors.green,
                    delay: 100,
                  ),
                ),
                StaggeredGridTile.fit(
                  crossAxisCellCount: 2,
                  child: _buildSummaryTile(
                    title: 'Total Value',
                    value: '\$${_calculateTotalValue().toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    color: Colors.amber,
                    isWide: true,
                    delay: 200,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.3, duration: 400.ms);
  }

  Widget _buildSummaryTile({
    required String title,
    required String value, 
    required IconData icon,
    required Color color,
    bool isWide = false,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (!isWide)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: color,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: isWide ? 28 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slide(delay: Duration(milliseconds: delay));
  }

  Widget _buildLowStockCard() {
    final lowStockItems = _items.where((item) => item.quantity < 10).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Low Stock Items',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${lowStockItems.length} items',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            lowStockItems.isEmpty
                ? _buildEmptyLowStockState()
                : SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: lowStockItems.length,
                      itemBuilder: (context, index) {
                        final item = lowStockItems[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ItemFormScreen(
                                  dbHelper: widget.dbHelper,
                                  userId: _currentUser!.id!,
                                  item: item,
                                  onItemSaved: () {
                                    _loadItems();
                                  },
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _getQuantityColor(item.quantity).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.quantity.toString(),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _getQuantityColor(item.quantity),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _getCategoryName(item.categoryId) ?? 'Uncategorized',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${item.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX(delay: Duration(milliseconds: 100 * index));
                      },
                    ),
                  ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, duration: 400.ms);
  }

  double _calculateTotalValue() {
    return _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  Widget _buildEmptyLowStockState() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'All items are well stocked',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildCategoryChartCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory by Category',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _buildCategoryChart(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, duration: 400.ms);
  }

  Widget _buildCategoryChart() {
    // Group items by category and calculate value
    final categoryMap = <String, double>{};
    final categoryColorMap = <String, Color>{};

    for (final item in _items) {
      String categoryName;
      Color categoryColor = Theme.of(context).colorScheme.primary; // Default color

      if (item.categoryId != null) {
        // Find the category
        final category = _categories.firstWhere(
          (c) => c.id == item.categoryId,
          orElse: () => Category(name: 'Uncategorized'),
        );

        categoryName = category.name;

        // Get the color if available
        if (category.color != null) {
          categoryColor = Color(
            int.parse(category.color!.replaceAll('#', '0xFF')),
          );
        }
      } else {
        categoryName = 'Uncategorized';
      }

      final value = item.price * item.quantity;

      if (categoryMap.containsKey(categoryName)) {
        categoryMap[categoryName] = categoryMap[categoryName]! + value;
      } else {
        categoryMap[categoryName] = value;
        categoryColorMap[categoryName] = categoryColor;
      }
    }

    // No data case
    if (categoryMap.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No category data to display',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 300.ms);
    }

    // Convert map to list of sections
    final sections = <PieChartSectionData>[];
    int index = 0;

    categoryMap.forEach((category, value) {
      final color = categoryColorMap[category] ?? Theme.of(context).colorScheme.primary;
      
      // Use a delay based on index for animation
      Future.delayed(Duration(milliseconds: 100 * index), () {
        if (mounted) {
          setState(() {});
        }
      });

      sections.add(
        PieChartSectionData(
          color: color,
          value: value,
          title: '$category\n\$${value.toStringAsFixed(0)}',
          radius: 100,
          titleStyle: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: _BadgeIcon(
            color: color,
            iconData: Icons.circle,
          ),
          badgePositionPercentageOffset: 1.2,
        ),
      );
      index++;
    });

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        startDegreeOffset: -90,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            // Handle touch interactions if needed
          },
        ),
        centerSpaceColor: Colors.transparent,
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsCard(
          title: 'Account Settings',
          subtitle: _currentUser != null ? _currentUser!.username : '',
          icon: Icons.account_circle,
          iconColor: Colors.blue,
          onTap: () {
            if (_currentUser != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountSettingsScreen(
                    dbHelper: widget.dbHelper,
                    user: _currentUser!,
                  ),
                ),
              ).then((_) {
                _loadUserAndItems();
              });
            }
          },
          delay: 0,
        ),
        _buildSettingsCard(
          title: 'Theme Settings',
          subtitle: _getThemeModeText(),
          icon: Icons.dark_mode,
          iconColor: Colors.purple,
          onTap: _toggleTheme,
          delay: 100,
        ),
        _buildSettingsCard(
          title: 'Manage Categories',
          subtitle: 'Add, edit, or delete categories',
          icon: Icons.category,
          iconColor: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryScreen(dbHelper: widget.dbHelper),
              ),
            ).then((_) {
              _loadCategories();
              _loadItems();
            });
          },
          delay: 200,
        ),
        _buildSettingsCard(
          title: 'Reports',
          subtitle: 'Export and analyze data',
          icon: Icons.bar_chart,
          iconColor: Colors.orange,
          onTap: _generatePdfReport,
          delay: 300,
        ),
        _buildSettingsCard(
          title: 'Sales Reports',
          subtitle: 'View and analyze sales transactions',
          icon: Icons.point_of_sale,
          iconColor: Colors.teal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SalesReportScreen(
                  dbHelper: widget.dbHelper,
                  userId: _currentUser!.id!,
                ),
              ),
            );
          },
          delay: 400,
        ),
        _buildSettingsCard(
          title: 'About',
          subtitle: 'App information',
          icon: Icons.info,
          iconColor: Colors.amber,
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Inventory Management',
              applicationVersion: '1.0.0',
              applicationIcon: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              children: [
                Text(
                  'A comprehensive inventory management application built with Flutter.',
                  style: GoogleFonts.montserrat(),
                ),
              ],
            );
          },
          delay: 500,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: Text(
            'Logout',
            style: GoogleFonts.montserrat(),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            _showLogoutConfirmation();
          },
        ).animate().fade(delay: 600.ms).scale(delay: 600.ms),
      ],
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required int delay,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideX(begin: 0.3, delay: Duration(milliseconds: delay));
  }

  String _getThemeModeText() {
    switch (widget.themeMode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }
}

class _BadgeIcon extends StatelessWidget {
  final Color color;
  final IconData iconData;

  const _BadgeIcon({
    required this.color,
    required this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              spreadRadius: 2,
              color: color.withOpacity(0.3),
            ),
          ],
        ),
        width: 20,
        height: 20,
      ),
    );
  }
}

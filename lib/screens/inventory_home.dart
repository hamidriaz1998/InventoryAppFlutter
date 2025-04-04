// inventory_home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../db/database_helper.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../models/category.dart';
import 'item_form.dart';
import 'category_screen.dart';

class InventoryHomePage extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final Function toggleTheme;
  final bool isDarkMode;

  const InventoryHomePage({
    Key? key,
    required this.dbHelper,
    required this.toggleTheme,
    required this.isDarkMode,
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

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserAndItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

      final pdf = pw.Document();

      // Add a page to the PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build:
              (pw.Context context) => [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Inventory Report',
                    style: pw.TextStyle(fontSize: 24),
                  ),
                ),
                pw.Paragraph(
                  text:
                      'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  context: context,
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                  headerHeight: 25,
                  cellHeight: 40,
                  headerStyle: pw.TextStyle(
                    color: PdfColors.black,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: const pw.TextStyle(color: PdfColors.black),
                  headers: ['Item', 'Category', 'Quantity', 'Price'],
                  data:
                      _items
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
        ),
      );

      // Use a more reliable way to save the file
      // Directory? directory;
      var directory = '/storage/emulated/0/Inventory_App';
      // if path does not exist on android create it
      if (Platform.isAndroid) {
        final dir = Directory(directory);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      // if (Platform.isAndroid) {
      //   // For Android, use the downloads directory
      //   directory = await getExternalStorageDirectory();

      //   // If cannot access external storage, fall back to app documents directory
      //   if (directory == null) {
      //     directory = await getApplicationDocumentsDirectory();
      //   }
      // } else {
      //   // For iOS and other platforms
      //   directory = await getApplicationDocumentsDirectory();
      // }

      final path = '$directory/inventory_report.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: ${file.path}'),
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

  String? _getCategoryName(int? categoryId) {
    if (categoryId == null) return null;

    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(name: 'Unknown'),
    );

    return category.name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('User Profile'),
                      content:
                          _currentUser == null
                              ? const Text('Loading user data...')
                              : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Username: ${_currentUser!.username}'),
                                  Text('Email: ${_currentUser!.email}'),
                                  Text(
                                    'Joined: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(_currentUser!.createdAt))}',
                                  ),
                                ],
                              ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Close'),
                        ),
                        TextButton(
                          onPressed: _logout,
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdfReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Items'),
            Tab(icon: Icon(Icons.analytics), text: 'Dashboard'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildItemsTab(),
                  _buildDashboardTab(),
                  _buildSettingsTab(),
                ],
              ),
      floatingActionButton:
          _tabController.index == 0
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => ItemFormScreen(
                            dbHelper: widget.dbHelper,
                            userId: _currentUser!.id!,
                            onItemSaved: () {
                              _loadItems();
                            },
                          ),
                    ),
                  );
                },
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
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
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _loadItems();
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int?>(
                hint: const Text('Category'),
                value: _selectedCategoryId,
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                  _loadItems();
                },
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ..._categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.category),
                tooltip: 'Manage Categories',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              CategoryScreen(dbHelper: widget.dbHelper),
                    ),
                  ).then((_) {
                    _loadCategories();
                    _loadItems();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _items.isEmpty
                  ? const Center(
                    child: Text(
                      'No items found',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                  : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];

                      // Find the category color if available
                      Color itemColor = Colors.blue.shade100;
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
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: Text(
                                    'Are you sure you want to delete ${item.name}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () =>
                                              Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                          );
                        },
                        onDismissed: (direction) async {
                          await widget.dbHelper.deleteItem(item.id!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${item.name} deleted')),
                          );
                          _loadItems();
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: itemColor,
                              child: Text(
                                item.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              'Category: ${_getCategoryName(item.categoryId) ?? 'N/A'}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Qty: ${item.quantity}'),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ItemFormScreen(
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
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard(
                        title: 'Total Items',
                        value: _items.length.toString(),
                        icon: Icons.inventory_2,
                        color: Colors.blue,
                      ),
                      _buildSummaryCard(
                        title: 'Categories',
                        value: _categories.length.toString(),
                        icon: Icons.category,
                        color: Colors.green,
                      ),
                      _buildSummaryCard(
                        title: 'Total Value',
                        value: '\$${_calculateTotalValue().toStringAsFixed(2)}',
                        icon: Icons.attach_money,
                        color: Colors.amber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Low Stock Items',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 200, child: _buildLowStockList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory by Category',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 300, child: _buildCategoryChart()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockList() {
    final lowStockItems = _items.where((item) => item.quantity < 10).toList();

    if (lowStockItems.isEmpty) {
      return const Center(child: Text('No low stock items'));
    }

    return ListView.builder(
      itemCount: lowStockItems.length,
      itemBuilder: (context, index) {
        final item = lowStockItems[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Text(
              item.quantity.toString(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
          title: Text(item.name),
          subtitle: Text(
            'Category: ${_getCategoryName(item.categoryId) ?? 'N/A'}',
          ),
          trailing: Text('\$${item.price.toStringAsFixed(2)}'),
        );
      },
    );
  }

  Widget _buildCategoryChart() {
    // Group items by category and calculate value
    final categoryMap = <String, double>{};
    final categoryColorMap = <String, Color>{};

    for (final item in _items) {
      String categoryName;
      Color categoryColor = Colors.blue; // Default color

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
      return const Center(child: Text('No data to display'));
    }

    // Convert map to list of sections
    final sections = <PieChartSectionData>[];

    categoryMap.forEach((category, value) {
      final color = categoryColorMap[category] ?? Colors.blue;

      sections.add(
        PieChartSectionData(
          color: color,
          value: value,
          title: '$category\n\$${value.toStringAsFixed(0)}',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return PieChart(
      PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2),
    );
  }

  double _calculateTotalValue() {
    return _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Account Settings'),
            subtitle:
                _currentUser != null ? Text(_currentUser!.username) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to account settings
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Manage notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to notifications settings
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: Text(widget.isDarkMode ? 'Enabled' : 'Disabled'),
            trailing: Switch(
              value: widget.isDarkMode,
              onChanged: (value) {
                widget.toggleTheme();
              },
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Manage Categories'),
            subtitle: const Text('Add, edit, or delete categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CategoryScreen(dbHelper: widget.dbHelper),
                ),
              ).then((_) {
                _loadCategories();
                _loadItems();
              });
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reports'),
            subtitle: const Text('Export and analyze data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _generatePdfReport,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            subtitle: const Text('Contact support and FAQ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to help
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('App information'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Inventory Management',
                applicationVersion: '1.0.0',
                applicationIcon: const FlutterLogo(size: 50),
                children: [
                  const Text(
                    'A comprehensive inventory management application built with Flutter.',
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _logout,
        ),
      ],
    );
  }
}

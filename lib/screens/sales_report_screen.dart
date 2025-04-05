import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../db/database_helper.dart';

class SalesReportScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final int userId;

  const SalesReportScreen({
    super.key,
    required this.dbHelper,
    required this.userId,
  });

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _salesData = [];
  double _totalSales = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await widget.dbHelper.getSalesTransactions(
        startDate: _dateRange.start,
        endDate: _dateRange.end,
      );
      
      final totalAmount = await widget.dbHelper.getTotalSalesAmount(
        startDate: _dateRange.start,
        endDate: _dateRange.end,
      );
      
      setState(() {
        _salesData = transactions;
        _totalSales = totalAmount;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sales data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final ThemeData theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final newRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: isDark ? const Color(0xFF242424) : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black87,
            ),
            dialogBackgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (newRange != null) {
      setState(() {
        _dateRange = newRange;
      });
      _loadSalesData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales Report',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ).animate().scale(delay: 200.ms),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_usmfx6bp.json',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading sales data...',
                    style: GoogleFonts.montserrat(fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSalesData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Summary Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sales Summary',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(
                                    '${DateFormat('MMM d').format(_dateRange.start)} - '
                                    '${DateFormat('MMM d').format(_dateRange.end)}',
                                    style: GoogleFonts.montserrat(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: _selectDateRange,
                                ),
                              ],
                            ).animate().fadeIn().slideY(begin: -0.2, duration: 400.ms),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Total Sales Amount
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Sales',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${_totalSales.toStringAsFixed(2)}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(delay: 100.ms).scale(delay: 100.ms),
                                
                                // Transaction Count
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Transactions',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_salesData.length}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.3, duration: 400.ms),
                    
                    const SizedBox(height: 16),
                    
                    // Sales Chart Card
                    if (_salesData.isNotEmpty) ...[
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sales Trend',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: _buildSalesChart(),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, delay: 300.ms),
                      
                      const SizedBox(height: 24),
                    ],
                    
                    // Recent Sales List
                    Text(
                      'Recent Sales',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    
                    const SizedBox(height: 8),
                    
                    _salesData.isEmpty
                        ? _buildEmptySalesState()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _salesData.length,
                            itemBuilder: (context, index) {
                              final sale = _salesData[index];
                              final date = DateTime.parse(sale['date']);
                              final amount = sale['total_amount'] ?? 0.0;
                              
                              return Card(
                                margin: EdgeInsets.only(bottom: 8, top: index == 0 ? 8 : 0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.point_of_sale, color: Colors.orange),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Sale - ${sale['quantity']} items',
                                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Text(
                                        '\$${amount.toStringAsFixed(2)}',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${DateFormat('MMM dd, yyyy hh:mm a').format(date)} ${sale['notes'] != null && sale['notes'].toString().isNotEmpty ? ' - ${sale['notes']}' : ''}',
                                    style: GoogleFonts.montserrat(fontSize: 12),
                                  ),
                                ),
                              ).animate().fadeIn(delay: Duration(milliseconds: 500 + (50 * index))).slideX(begin: 0.3, delay: Duration(milliseconds: 500 + (50 * index)));
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptySalesState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://assets2.lottiefiles.com/packages/lf20_ydo1amjm.json',
            width: 180,
            height: 180,
          ),
          const SizedBox(height: 16),
          Text(
            'No sales data found',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different date range',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildSalesChart() {
    if (_salesData.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    // Group sales by date
    final Map<String, double> dailySales = {};
    
    for (var sale in _salesData) {
      final date = DateTime.parse(sale['date']);
      final dateStr = DateFormat('MM/dd').format(date);
      final amount = sale['total_amount'] as double? ?? 0.0;
      
      if (dailySales.containsKey(dateStr)) {
        dailySales[dateStr] = dailySales[dateStr]! + amount;
      } else {
        dailySales[dateStr] = amount;
      }
    }
    
    // Sort dates chronologically
    final sortedDates = dailySales.keys.toList()..sort();
    
    // Prepare line chart data
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailySales[sortedDates[i]]!));
    }
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                  return Text(
                    sortedDates[value.toInt()],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
              reservedSize: 22,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}

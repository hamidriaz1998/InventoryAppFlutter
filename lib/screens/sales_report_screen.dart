import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Sales Summary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(
                                  '${DateFormat('MMM d').format(_dateRange.start)} - '
                                  '${DateFormat('MMM d').format(_dateRange.end)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: _selectDateRange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Sales',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${_totalSales.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Transactions',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_salesData.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_salesData.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: 200,
                          child: _buildSalesChart(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Recent Sales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _salesData.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No sales data for the selected period'),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _salesData.length,
                          itemBuilder: (context, index) {
                            final sale = _salesData[index];
                            final date = DateTime.parse(sale['date']);
                            final amount = sale['total_amount'] ?? 0.0;
                            
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Icon(Icons.point_of_sale, color: Colors.white),
                                ),
                                title: Row(
                                  children: [
                                    Text('Sale - ${sale['quantity']} items'),
                                    const Spacer(),
                                    Text(
                                      '\$${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${DateFormat('MMM dd, yyyy hh:mm a').format(date)} - ${sale['notes'] ?? ''}',
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
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

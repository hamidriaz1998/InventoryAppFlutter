// item_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/item.dart';
import '../models/category.dart';
import 'item_transaction_screen.dart';

class ItemFormScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final int userId;
  final Item? item;
  final Function onItemSaved;

  const ItemFormScreen({
    Key? key,
    required this.dbHelper,
    required this.userId,
    this.item,
    required this.onItemSaved,
  }) : super(key: key);

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _barcodeController = TextEditingController();
  
  // Add focus nodes for each text field
  final _nameFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _barcodeFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isEditing = false;
  String _pageTitle = 'Add Item';
  List<Category> _categories = [];
  Category? _selectedCategory;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    
    if (widget.item != null) {
      _isEditing = true;
      _pageTitle = 'Edit Item';
      _nameController.text = widget.item!.name;
      // Still initialize the quantity controller but won't show the field in UI
      _quantityController.text = widget.item!.quantity.toString();
      _priceController.text = widget.item!.price.toStringAsFixed(2);
      _selectedCategoryId = widget.item!.categoryId;
      
      if (widget.item!.barcode != null) {
        _barcodeController.text = widget.item!.barcode!;
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.dbHelper.getCategories();
      setState(() {
        _categories = categories;
        
        // If editing, try to find the corresponding category
        if (_isEditing && _selectedCategoryId != null) {
          _selectedCategory = _categories.firstWhere(
            (cat) => cat.id == _selectedCategoryId,
            orElse: () => _categories.first,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    
    // Dispose focus nodes
    _nameFocusNode.dispose();
    _quantityFocusNode.dispose();
    _priceFocusNode.dispose();
    _barcodeFocusNode.dispose();
    
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null && _categories.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now().toIso8601String();
      
      if (_isEditing) {
        // Update existing item but preserve the quantity
        final updatedItem = widget.item!.copyWith(
          name: _nameController.text.trim(),
          // Keep original quantity when editing
          quantity: widget.item!.quantity,
          categoryId: _selectedCategory?.id,
          category: _selectedCategory?.name,
          price: double.parse(_priceController.text.trim()),
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          updatedAt: now,
        );
        
        await widget.dbHelper.updateItem(updatedItem);
        
        // Record the transaction for item update
        await widget.dbHelper.recordTransaction(
          updatedItem.id!, 
          widget.userId, 
          'UPDATE', 
          updatedItem.quantity, 
          'Item updated'
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated successfully')),
          );
        }
      } else {
        // Create new item
        final newItem = Item(
          userId: widget.userId,
          name: _nameController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
          categoryId: _selectedCategory?.id,
          price: double.parse(_priceController.text.trim()),
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        
        final itemId = await widget.dbHelper.insertItem(newItem);
        
        // Record the transaction for item creation
        if (itemId > 0) {
          await widget.dbHelper.recordTransaction(
            itemId, 
            widget.userId, 
            'CREATE', 
            newItem.quantity, 
            'Item created'
          );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item added successfully')),
          );
        }
      }

      widget.onItemSaved();
      
      if (mounted) {
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCategoryManagement() {
    Navigator.of(context).pushNamed('/categories').then((_) {
      // Reload categories when we return from category management screen
      _loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Manage Categories',
            onPressed: _showCategoryManagement,
          ),
          if (_isEditing)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'sell') {
                  _showSellItemScreen();
                } else if (value == 'restock') {
                  _showRestockItemScreen();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sell',
                  child: Row(
                    children: [
                      Icon(Icons.point_of_sale, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Sell'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'restock',
                  child: Row(
                    children: [
                      Icon(Icons.add_shopping_cart, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Restock'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  // Skip to price field if editing or category field if new item
                  if (_isEditing) {
                    FocusScope.of(context).requestFocus(_priceFocusNode);
                  } else {
                    FocusScope.of(context).requestFocus(_quantityFocusNode);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Only show quantity field when creating a new item
              if (!_isEditing)
                TextFormField(
                  controller: _quantityController,
                  focusNode: _quantityFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_priceFocusNode);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Quantity must be a number';
                    }
                    if (int.parse(value) < 0) {
                      return 'Quantity cannot be negative';
                    }
                    return null;
                  },
                ),
              
              if (!_isEditing)
                const SizedBox(height: 16),
                
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Category>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: _selectedCategory,
                      items: _categories.map((category) {
                        return DropdownMenuItem<Category>(
                          value: category,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                        // Move focus to price field after selecting category
                        FocusScope.of(context).requestFocus(_priceFocusNode);
                      },
                      hint: const Text('Select Category'),
                      validator: _categories.isNotEmpty ? (value) {
                        if (value == null) {
                          return 'Please select a category';
                        }
                        return null;
                      } : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    tooltip: 'Add New Category',
                    onPressed: _showCategoryManagement,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                focusNode: _priceFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_barcodeFocusNode);
                },
                decoration: const InputDecoration(
                  labelText: 'Price (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Price must be a number';
                  }
                  if (double.parse(value) < 0) {
                    return 'Price cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcodeController,
                focusNode: _barcodeFocusNode,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  // Submit the form when done is pressed on barcode field
                  _submitForm();
                },
                decoration: const InputDecoration(
                  labelText: 'Barcode (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 20),
              
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.point_of_sale),
                          label: const Text('SELL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _showSellItemScreen,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('RESTOCK'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _showRestockItemScreen,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              if (_isEditing)
                _buildTransactionHistory(),
                
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_isEditing ? 'UPDATE ITEM' : 'ADD ITEM'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSellItemScreen() {
    if (widget.item == null || widget.item!.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stock available to sell'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ItemTransactionScreen(
          dbHelper: widget.dbHelper,
          item: widget.item!,
          userId: widget.userId,
          transactionType: TransactionType.sale,
          onTransactionComplete: widget.onItemSaved,
        ),
      ),
    );
  }

  void _showRestockItemScreen() {
    if (widget.item == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ItemTransactionScreen(
          dbHelper: widget.dbHelper,
          item: widget.item!,
          userId: widget.userId,
          transactionType: TransactionType.restock,
          onTransactionComplete: widget.onItemSaved,
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.dbHelper.getItemTransactions(widget.item!.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final transactions = snapshot.data ?? [];
        
        if (transactions.isEmpty) {
          return const SizedBox();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final type = transaction['transaction_type'] as String;
                  final quantity = transaction['quantity'] as int;
                  final hasPrice = transaction['unit_price'] != null;
                  final unitPrice = transaction['unit_price'] as double?;
                  final totalAmount = transaction['total_amount'] as double?;
                  
                  String subtitle = 'Quantity: $quantity';
                  if (hasPrice && unitPrice != null) {
                    subtitle += ' - Unit: \$${unitPrice.toStringAsFixed(2)}';
                  }
                  if (transaction['notes'] != null) {
                    subtitle += ' - ${transaction['notes']}';
                  }
                  
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        _getTransactionIcon(type),
                        color: _getTransactionColor(type),
                      ),
                      title: Row(
                        children: [
                          Text(type),
                          if (totalAmount != null) ...[
                            const Spacer(),
                            Text(
                              '\$${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(subtitle),
                      trailing: Text(
                        DateFormat('MMM dd, yyyy').format(
                          DateTime.parse(transaction['date']),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CREATE':
        return Icons.add_circle;
      case 'UPDATE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      case 'SALE':
        return Icons.point_of_sale;
      case 'RESTOCK':
        return Icons.add_shopping_cart;
      default:
        return Icons.sync;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type.toUpperCase()) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'SALE':
        return Colors.orange;
      case 'RESTOCK':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
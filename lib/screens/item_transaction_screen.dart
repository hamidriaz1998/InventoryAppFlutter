import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/item.dart';

enum TransactionType { sale, restock }

class ItemTransactionScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final Item item;
  final int userId;
  final TransactionType transactionType;
  final Function onTransactionComplete;

  const ItemTransactionScreen({
    Key? key,
    required this.dbHelper,
    required this.item,
    required this.userId,
    required this.transactionType,
    required this.onTransactionComplete,
  }) : super(key: key);

  @override
  State<ItemTransactionScreen> createState() => _ItemTransactionScreenState();
}

class _ItemTransactionScreenState extends State<ItemTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Add focus nodes
  final _quantityFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  
  bool _isProcessing = false;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.item.price.toStringAsFixed(2);
    _calculateTotal();
    
    _quantityController.addListener(_calculateTotal);
    _priceController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    
    // Dispose focus nodes
    _quantityFocusNode.dispose();
    _priceFocusNode.dispose();
    _notesFocusNode.dispose();
    
    super.dispose();
  }

  void _calculateTotal() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _totalAmount = quantity * price;
    });
  }

  Future<void> _processTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final quantity = int.parse(_quantityController.text);
      final price = double.parse(_priceController.text);
      final notes = _notesController.text.trim();
      
      // Determine new quantity based on transaction type
      int newQuantity;
      if (widget.transactionType == TransactionType.sale) {
        newQuantity = widget.item.quantity - quantity;
        
        // Record the sale transaction
        await widget.dbHelper.sellItem(
          widget.item.id!, 
          widget.userId, 
          quantity, 
          price, 
          notes.isEmpty ? 'Item sold' : notes
        );
      } else {
        newQuantity = widget.item.quantity + quantity;
        
        // Record the restock transaction
        await widget.dbHelper.restockItem(
          widget.item.id!, 
          widget.userId, 
          quantity, 
          price, 
          notes.isEmpty ? 'Item restocked' : notes
        );
      }
      
      // Update the item quantity
      final updatedItem = widget.item.copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      await widget.dbHelper.updateItem(updatedItem);
      
      // Call the onTransactionComplete callback to update the parent
      widget.onTransactionComplete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transactionType == TransactionType.sale
                  ? 'Sale completed successfully'
                  : 'Restock completed successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSale = widget.transactionType == TransactionType.sale;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isSale ? 'Sell Item' : 'Restock Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item details card
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Stock: ${widget.item.quantity}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Current Price: \$${widget.item.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Transaction form
              TextFormField(
                controller: _quantityController,
                focusNode: _quantityFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_priceFocusNode);
                },
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                  helperText: isSale 
                      ? 'Maximum: ${widget.item.quantity}' 
                      : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Quantity must be greater than 0';
                  }
                  
                  if (isSale && quantity > widget.item.quantity) {
                    return 'Not enough stock available';
                  }
                  
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Price field - readonly for sales, editable for restock
              TextFormField(
                controller: _priceController,
                focusNode: _priceFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_notesFocusNode);
                },
                decoration: InputDecoration(
                  labelText: 'Unit Price (\$)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  helperText: isSale ? 'Fixed selling price' : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                readOnly: isSale,
                enabled: !isSale,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Price must be greater than 0';
                  }
                  
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocusNode,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isProcessing) _processTransaction();
                },
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 24),
              
              // Total amount display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processTransaction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    backgroundColor: isSale 
                        ? Colors.green 
                        : Theme.of(context).colorScheme.primary,
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator()
                      : Text(
                          isSale ? 'COMPLETE SALE' : 'COMPLETE RESTOCK',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

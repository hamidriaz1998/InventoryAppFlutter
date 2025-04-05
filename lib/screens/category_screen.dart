import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../db/database_helper.dart';
import '../models/category.dart';

class CategoryScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const CategoryScreen({Key? key, required this.dbHelper}) : super(key: key);

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<Category>> _categoriesFuture;
  
  @override
  void initState() {
    super.initState();
    _refreshCategories();
  }
  
  void _refreshCategories() {
    setState(() {
      _categoriesFuture = widget.dbHelper.getCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No categories found'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final category = snapshot.data![index];
                Color categoryColor = Colors.grey;
                if (category.color != null) {
                  try {
                    categoryColor = Color(int.parse(category.color!.replaceAll('#', '0xFF')));
                  } catch (e) {
                    // Use default color if parsing fails
                  }
                }
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryColor,
                    child: Text(
                      category.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(category.name),
                  subtitle: category.description != null 
                      ? Text(category.description!) 
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showCategoryDialog(category: category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteCategory(category.id!),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Future<void> _showCategoryDialog({Category? category}) async {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController = TextEditingController(text: category?.description ?? '');
    
    // Add focus nodes
    final nameFocusNode = FocusNode();
    final descriptionFocusNode = FocusNode();
    
    // Default color
    Color selectedColor = category?.color != null 
        ? Color(int.parse(category!.color!.replaceAll('#', '0xFF'))) 
        : Colors.blue;
    
    try {
      return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(category == null ? 'Add Category' : 'Edit Category'),
                content: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          focusNode: nameFocusNode,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(descriptionFocusNode);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          focusNode: descriptionFocusNode,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Color: '),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return StatefulBuilder(
                                      builder: (context, setState) {
                                        return AlertDialog(
                                          title: const Text('Pick a color'),
                                          content: SingleChildScrollView(
                                            child: ColorPicker(
                                              pickerColor: selectedColor,
                                              onColorChanged: (Color color) {
                                                setState(() {
                                                  selectedColor = color;
                                                });
                                              },
                                            ),
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              child: const Text('Select'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: selectedColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final colorHex = '#${selectedColor.value.toRadixString(16).substring(2)}';
                        
                        if (category == null) {
                          // Create new category
                          await widget.dbHelper.insertCategory(
                            Category(
                              name: nameController.text,
                              description: descriptionController.text,
                              color: colorHex,
                            ),
                          );
                        } else {
                          // Update existing category
                          await widget.dbHelper.updateCategory(
                            Category(
                              id: category.id,
                              name: nameController.text,
                              description: descriptionController.text,
                              color: colorHex,
                            ),
                          );
                        }
                        
                        Navigator.pop(context);
                        _refreshCategories();
                      }
                    },
                    child: Text(category == null ? 'Add' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Make sure to dispose focus nodes
      nameFocusNode.dispose();
      descriptionFocusNode.dispose();
    }
  }
  
  Future<void> _deleteCategory(int id) async {
    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
          'Are you sure you want to delete this category? Items in this category will be uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      await widget.dbHelper.deleteCategory(id);
      _refreshCategories();
    }
  }
}
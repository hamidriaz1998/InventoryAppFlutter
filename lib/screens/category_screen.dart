import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        title: Text(
          'Categories',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading categories...',
                    style: GoogleFonts.montserrat(fontSize: 16),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading categories',
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.network(
                    'https://assets6.lottiefiles.com/packages/lf20_ydo1amjm.json',
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No categories found',
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first category',
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Add Category',
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
          } else {
            // Display categories in a columnar list view
            return RefreshIndicator(
              onRefresh: () async {
                _refreshCategories();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final category = snapshot.data![index];
                  // Parse color from hex string
                  Color categoryColor = Theme.of(context).colorScheme.primary;
                  if (category.color != null) {
                    categoryColor = Color(
                      int.parse(category.color!.replaceAll('#', '0xFF')),
                    );
                  }
                  
                  return Dismissible(
                    key: Key(category.id.toString()),
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
                            'Are you sure you want to delete ${category.name}?',
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
                      await widget.dbHelper.deleteCategory(category.id!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${category.name} deleted',
                            style: GoogleFonts.montserrat(),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () {
                              _refreshCategories();
                            },
                          ),
                        ),
                      );
                      _refreshCategories();
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () => _showCategoryDialog(category: category),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Category color indicator and initial
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    category.name.substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: categoryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Category details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.name,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (category.description != null && 
                                        category.description!.isNotEmpty)
                                      const SizedBox(height: 4),
                                    if (category.description != null && 
                                        category.description!.isNotEmpty)
                                      Text(
                                        category.description!,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              // Drag indicator
                              Icon(
                                Icons.drag_handle,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index))
                      .slideX(begin: 0.2, delay: Duration(milliseconds: 50 * index)),
                  );
                },
              ),
            );
          }
        },
      ),
      floatingActionButton: OpenContainer(
        transitionDuration: const Duration(milliseconds: 500),
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (context, _) {
          return _CategoryFormScreen(
            onSave: (categoryData) {
              _showCategoryDialog(categoryData: categoryData);
            },
          );
        },
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
      ).animate().scale(delay: 400.ms),
    );
  }
  
  Future<void> _showCategoryDialog({Category? category, Map<String, dynamic>? categoryData}) async {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?.name ?? categoryData?['name'] ?? '');
    final descriptionController = TextEditingController(text: category?.description ?? categoryData?['description'] ?? '');
    
    // Add focus nodes
    final nameFocusNode = FocusNode();
    final descriptionFocusNode = FocusNode();
    
    // Default color
    Color selectedColor = category?.color != null 
        ? Color(int.parse(category!.color!.replaceAll('#', '0xFF'))) 
        : Colors.blue;
    
    try {
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
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
                                    return AlertDialog(
                                      title: const Text('Pick a color'),
                                      content: SingleChildScrollView(
                                        child: ColorPicker(
                                          pickerColor: selectedColor,
                                          onColorChanged: (Color color) {
                                            selectedColor = color;
                                          },
                                        ),
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('Select'),
                                          onPressed: () {
                                            // Update the color in the parent dialog when selected
                                            setDialogState(() {
                                              selectedColor = selectedColor;
                                            });
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
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
      // Dispose controllers and focus nodes
      nameController.dispose();
      descriptionController.dispose();
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

class _CategoryFormScreen extends StatelessWidget {
  final Function(Map<String, dynamic>) onSave;

  const _CategoryFormScreen({Key? key, required this.onSave}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Category'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            onSave({'name': 'New Category', 'description': 'Description'});
            Navigator.pop(context);
          },
          child: const Text('Save Category'),
        ),
      ),
    );
  }
}
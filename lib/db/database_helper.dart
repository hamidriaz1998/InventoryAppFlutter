import 'database_service.dart';
import 'repositories/user_repository.dart';
import 'repositories/item_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/transaction_repository.dart';
import '../models/user.dart';
import '../models/item.dart';
import '../models/category.dart';

/// A facade class that delegates to specific repositories
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  
  // Repositories
  final UserRepository _userRepository = UserRepository();
  final ItemRepository _itemRepository = ItemRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();
  
  // Private constructor
  DatabaseHelper._privateConstructor();

  // Initialize the database
  Future<void> init() async {
    await DatabaseService.instance.init();
  }

  // User operations
  Future<User?> getUserById(int id) => _userRepository.getUserById(id);
  Future<User?> getUser(String username) => _userRepository.getUser(username);
  Future<int> insertUser(User user) => _userRepository.insertUser(user);
  Future<int> updateUser(User user) => _userRepository.updateUser(user);
  String hashPassword(String password) => _userRepository.hashPassword(password);
  Future<bool> validateUser(String username, String password) => 
      _userRepository.validateUser(username, password);

  // Item operations
  Future<int> insertItem(Item item) => _itemRepository.insertItem(item);
  Future<List<Item>> getItems({int? userId, String? category, String? searchQuery, int? categoryId}) => 
      _itemRepository.getItems(userId: userId, category: category, searchQuery: searchQuery, categoryId: categoryId);
  Future<Item?> getItem(int id) => _itemRepository.getItem(id);
  Future<int> updateItem(Item item) => _itemRepository.updateItem(item);
  Future<int> deleteItem(int id) => _itemRepository.deleteItem(id);
  Future<List<Map<String, dynamic>>> getLowStockItems(int userId, int threshold) => 
      _itemRepository.getLowStockItems(userId, threshold);
  Future<List<Map<String, dynamic>>> getInventoryValueByCategory(int userId) => 
      _itemRepository.getInventoryValueByCategory(userId);

  // Category operations
  Future<int> insertCategory(Category category) => _categoryRepository.insertCategory(category);
  Future<List<Category>> getCategories() => _categoryRepository.getCategories();
  Future<Category?> getCategory(int id) => _categoryRepository.getCategory(id);
  Future<int> updateCategory(Category category) => _categoryRepository.updateCategory(category);
  Future<int> deleteCategory(int id) => _categoryRepository.deleteCategory(id);

  // Transaction operations
  Future<int> recordTransaction(int itemId, int userId, String type, int quantity, String notes) => 
      _transactionRepository.recordTransaction(itemId, userId, type, quantity, notes);
  Future<List<Map<String, dynamic>>> getItemTransactions(int itemId) => 
      _transactionRepository.getItemTransactions(itemId);
}
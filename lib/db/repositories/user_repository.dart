import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../database_service.dart';
import '../../models/user.dart';

class UserRepository {
  final DatabaseService _databaseService = DatabaseService.instance;

  Future<User?> getUserById(int id) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUser(String username) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<int> insertUser(User user) async {
    final db = await _databaseService.database;
    return db.insert('users', user.toMap());
  }

  Future<int> updateUser(User user) async {
    final db = await _databaseService.database;
    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> validateUser(String username, String password) async {
    final user = await getUser(username);
    if (user == null) return false;
    
    final passwordHash = hashPassword(password);
    return user.passwordHash == passwordHash;
  }
}

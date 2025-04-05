import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/user.dart';

class AccountSettingsScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final User user;

  const AccountSettingsScreen({
    Key? key,
    required this.dbHelper,
    required this.user,
  }) : super(key: key);

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Profile form controllers
  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;

  // Password form controllers
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();

      // Check if username is already taken by another user
      if (username != widget.user.username) {
        final existingUser = await widget.dbHelper.getUser(username);
        if (existingUser != null && existingUser.id != widget.user.id) {
          setState(() {
            _errorMessage = "Username already exists";
            _isLoading = false;
          });
          return;
        }
      }

      // Update the user profile
      final updatedUser = User(
        id: widget.user.id,
        username: username,
        passwordHash: widget.user.passwordHash, // Keep the same password
        email: email,
        createdAt: widget.user.createdAt,
      );

      final result = await widget.dbHelper.updateUser(updatedUser);
      
      if (result > 0) {
        setState(() {
          _successMessage = "Profile updated successfully";
        });
      } else {
        setState(() {
          _errorMessage = "Failed to update profile";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      // Verify current password
      final currentPasswordHash = widget.dbHelper.hashPassword(currentPassword);
      if (currentPasswordHash != widget.user.passwordHash) {
        setState(() {
          _errorMessage = "Current password is incorrect";
          _isLoading = false;
        });
        return;
      }

      // Hash the new password
      final newPasswordHash = widget.dbHelper.hashPassword(newPassword);
      
      // Update the user with new password
      final updatedUser = User(
        id: widget.user.id,
        username: widget.user.username,
        passwordHash: newPasswordHash,
        email: widget.user.email,
        createdAt: widget.user.createdAt,
      );

      final result = await widget.dbHelper.updateUser(updatedUser);
      
      if (result > 0) {
        setState(() {
          _successMessage = "Password changed successfully";
          // Clear password fields
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        setState(() {
          _errorMessage = "Failed to change password";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile', icon: Icon(Icons.person)),
            Tab(text: 'Password', icon: Icon(Icons.lock)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildPasswordTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.red.shade100,
                width: double.infinity,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.green.shade100,
                width: double.infinity,
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Colors.green.shade900),
                ),
              ),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                if (value.length < 4) {
                  return 'Username must be at least 4 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                // Basic email validation
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('SAVE CHANGES'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          children: [
            const Icon(Icons.lock, size: 50),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.red.shade100,
                width: double.infinity,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.green.shade100,
                width: double.infinity,
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Colors.green.shade900),
                ),
              ),
            TextFormField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a new password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your new password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('CHANGE PASSWORD'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('auth_token')) return false;

    // Fetch user profile if token exists
    try {
      final response = await ApiService.get('/auth/me');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = User.fromJson(data);
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Token might be expired or invalid
      await logout();
    }
    return false;
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Supabase returns 'access_token', not 'token'
        final token = data['access_token'] as String?;

        if (token == null) {
          _isLoading = false;
          notifyListeners();
          return 'Login failed: token not found in response.';
        }

        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        // Fetch User Profile
        final profileRes = await ApiService.get('/auth/me');
        if (profileRes.statusCode == 200) {
          final profileData = json.decode(profileRes.body);
          _currentUser = User.fromJson(profileData);
          _isLoading = false;
          notifyListeners();
          return null; // Success
        } else {
          _isLoading = false;
          notifyListeners();
          return 'Failed to fetch user profile.';
        }
      } else {
        _isLoading = false;
        notifyListeners();
        final body = jsonDecode(response.body);
        return body['error'] ?? 'Login failed. Please check your credentials.';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Network error occurred. Please try again.';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _currentUser = null;
    notifyListeners();
  }
}

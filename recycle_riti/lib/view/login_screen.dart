import 'package:firebase_messaging/firebase_messaging.dart'; // Add this import
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false; // Track loading state for login button
  bool _isAutoLoginLoading = true; // Track loading state for auto-login

  @override
  void initState() {
    super.initState();
    _checkAutoLogin(); // Check for saved token and auto-login
  }

  // Check if tokens exist and attempt auto-login
  Future<void> _checkAutoLogin() async {
    try {
      // Check if tokens exist in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final refreshToken = prefs.getString('refreshToken');

      if (accessToken == null || refreshToken == null) {
        print('No tokens found in SharedPreferences');
        // No tokens available, proceed to load saved email
        await _loadSavedEmail();
        if (mounted) {
          setState(() {
            _isAutoLoginLoading = false;
          });
        }
        return;
      }

      print('Tokens found. Access token: $accessToken');
      print('Refresh token: $refreshToken');
      print('Attempting to fetch user profile...');
      // Verify the token by fetching the user profile
      final profile = await AuthService.getUserProfile();
      if (profile['success']) {
        print('Profile fetched successfully: ${profile['user']}');
        print('Navigating to ${profile['user']['role'] == 'agent' ? 'agent' : 'main'}...');
        // Subscribe to FCM topics before navigating
        await _subscribeToFCMTopics(profile['user']);
        // Token is valid, navigate based on role
        if (mounted) {
          final role = profile['user']['role'] ?? 'user';
          Navigator.pushReplacementNamed(
            context,
            role == 'agent' ? '/agent' : '/main',
          );
        }
      } else {
        print('Profile fetch failed: ${profile['message']}');
        // Profile fetch failed, attempt to refresh token
        try {
          print('Attempting to refresh token...');
          await AuthService.refreshAccessToken();
          // Retry fetching the profile after refreshing the token
          final retryProfile = await AuthService.getUserProfile();
          if (retryProfile['success']) {
            print('Profile fetched after token refresh: ${retryProfile['user']}');
            // Subscribe to FCM topics before navigating
            await _subscribeToFCMTopics(retryProfile['user']);
            print('Navigating to ${retryProfile['user']['role'] == 'agent' ? 'agent' : 'main'}...');
            if (mounted) {
              final role = retryProfile['user']['role'] ?? 'user';
              Navigator.pushReplacementNamed(
                context,
                role == 'agent' ? '/agent' : '/main',
              );
            }
          } else {
            print('Profile fetch failed after token refresh: ${retryProfile['message']}');
            // Clear tokens if profile fetch still fails
            await prefs.remove('accessToken');
            await prefs.remove('refreshToken');
            print('Tokens cleared due to profile fetch failure after refresh');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to auto-login: ${retryProfile['message'] ?? 'Unknown error'}. Please login manually.',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(10),
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _isAutoLoginLoading = true;
                        });
                        _checkAutoLogin();
                      }
                    },
                  ),
                ),
              );
            }
            await _loadSavedEmail();
            if (mounted) {
              setState(() {
                _isAutoLoginLoading = false;
              });
            }
          }
        } catch (refreshError) {
          print('Token refresh failed: $refreshError');
          // Clear tokens if refresh fails
          await prefs.remove('accessToken');
          await prefs.remove('refreshToken');
          print('Tokens cleared due to token refresh failure');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to refresh token: ${refreshError.toString().replaceFirst('Exception: ', '')}. Please login manually.',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(10),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _isAutoLoginLoading = true;
                      });
                      _checkAutoLogin();
                    }
                  },
                ),
              ),
            );
          }
          await _loadSavedEmail();
          if (mounted) {
            setState(() {
              _isAutoLoginLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Auto-login failed with error: $e');
      // Only clear tokens if the error is related to session expiration or user not found
      if (e.toString().contains('Session expired') || 
          e.toString().contains('Token') || 
          e.toString().contains('User not found')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        print('Tokens cleared due to auto-login failure: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-login error: ${e.toString().replaceFirst('Exception: ', '')}. Please login manually.',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _isAutoLoginLoading = true;
                  });
                  _checkAutoLogin();
                }
              },
            ),
          ),
        );
      }
      // Proceed to load saved email
      await _loadSavedEmail();
      if (mounted) {
        setState(() {
          _isAutoLoginLoading = false;
        });
      }
    }
  }

  // Load saved email if "Remember Me" was previously checked
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null) {
      _emailController.text = savedEmail;
      _rememberMe = true;
      setState(() {});
    }
  }

  // Save email to SharedPreferences if "Remember Me" is checked
  Future<void> _saveCredentials(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', email); // Save email for auto-fill
      // Tokens are already saved by AuthService.loginUser
    } else {
      await prefs.remove('saved_email');
      // Do not clear tokens here; they should persist after login
    }
  }

  // Subscribe to FCM topics based on user role
  Future<void> _subscribeToFCMTopics(Map<String, dynamic> user) async {
    try {
      String userId = user['id'].toString();
      String role = user['role'].toString().toLowerCase();
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      if (role == 'user') {
        await messaging.subscribeToTopic('user_$userId');
        print('Subscribed to user_$userId');
      } else if (role == 'agent') {
        await messaging.subscribeToTopic('agent_$userId');
        await messaging.subscribeToTopic('agents');
        print('Subscribed to agent_$userId and agents');
      }
    } catch (e) {
      print('Failed to subscribe to FCM topics: $e');
      // Optionally show a SnackBar to inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to set up notifications: $e',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    }
  }

  Future<void> _loginUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      try {
        final data = await AuthService.loginUser(
          _emailController.text,
          _passwordController.text,
        );
        setState(() {
          _isLoading = false; // Hide loading indicator
        });

        if (data['success']) {
          // Save email if "Remember Me" is checked
          await _saveCredentials(_emailController.text);
          // Ensure tokens are saved before proceeding
          final prefs = await SharedPreferences.getInstance();
          final accessToken = prefs.getString('accessToken');
          final refreshToken = prefs.getString('refreshToken');
          if (accessToken == null || refreshToken == null) {
            throw Exception('Tokens not found after login');
          }
          print('Navigating after successful login');
          // Fetch user profile to determine role and subscribe to FCM topics
          final profile = await AuthService.getUserProfile();
          if (profile['success']) {
            // Subscribe to FCM topics before navigating
            await _subscribeToFCMTopics(profile['user']);
            final role = profile['user']['role'] ?? 'user';
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                role == 'agent' ? '/agent' : '/main',
              );
            }
          } else {
            throw Exception('Failed to fetch user profile after login: ${profile['message']}');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['message'] ?? 'Login failed',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(10),
              ),
            );
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
        print('Login error: $e');
        String errorMessage = 'An error occurred during login';
        if (e.toString().contains('Exception')) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent resizing when keyboard appears
      backgroundColor: AppTheme.backgroundColor, // Use AppTheme background color
      body: _isAutoLoginLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Recycle Riti',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Checking login status...',
                    style: TextStyle(fontSize: 16, color: AppTheme.textColor),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header Text (Recycle Riti)
                      Text(
                        'Recycle Riti',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor, // Use AppTheme primary color
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 1),
                      // Lottie Animation as Logo (Centered)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Lottie.network(
                          'https://lottie.host/f19e4d1b-2de1-4072-b86b-06cc60614b43/wn23sce0pa.json',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if the Lottie animation fails to load
                            return Icon(
                              Icons.recycling,
                              size: 120,
                              color: AppTheme.primaryColor, // Use AppTheme primary color
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 1),
                      // Login Title
                      Text(
                        'Login to Continue',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor, // Use AppTheme primary color
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      // Login Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primaryColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[400]!),
                                ),
                                labelStyle: const TextStyle(color: Colors.grey),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email required';
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primaryColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[400]!),
                                ),
                                labelStyle: const TextStyle(color: Colors.grey),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password required';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Remember Me Checkbox
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                  activeColor: AppTheme.primaryColor, // Use AppTheme primary color
                                ),
                                const Text(
                                  'Remember Me',
                                  style: TextStyle(fontSize: 16, color: AppTheme.textColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Login Button with Loading Indicator
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _loginUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor, // Use AppTheme primary color
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Register Link
                            InkWell(
                              onTap: () => Navigator.pushNamed(context, '/signup'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Don’t have an account?',
                                    style: TextStyle(color: AppTheme.textColor, fontSize: 16),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Signup',
                                    style: TextStyle(
                                      color: AppTheme.accentColor, // Use AppTheme accent color
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
import 'package:flutter/material.dart';

class AppTheme {
  // Light theme colors
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color accentColor = Color.fromARGB(255, 253, 195, 6);
  static const Color backgroundColor = Color(0xFFE8F3D6);
  static const Color cardColor = Color(0xFFF5F5F5);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryTextColor = Color(0xFF757575);

  // Custom colors for AppBar and BottomNavigationBar
  static const Color appBarColor = primaryColor; 
  static const Color bottomNavBarColor = primaryColor;

  // Text Styles
  static const TextStyle appBarTitleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textColor,
    letterSpacing: 0.5,
    fontFamily: 'Roboto',
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textColor,
    letterSpacing: 0.3,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 14,
    color: secondaryTextColor,
    letterSpacing: 0.2,
  );

  static const TextStyle actionTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: primaryColor,
    letterSpacing: 0.3,
  );

  // Light theme
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    textTheme: const TextTheme(
      bodyLarge: bodyTextStyle,
      bodyMedium: bodyTextStyle,
      titleLarge: appBarTitleStyle,
      titleMedium: sectionTitleStyle,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
        shadowColor: primaryColor.withOpacity(0.4),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.pressed)) {
              return accentColor;
            }
            return Colors.transparent;
          },
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: appBarColor,
      elevation: 2,
      titleTextStyle: appBarTitleStyle,
      iconTheme: IconThemeData(color: textColor),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bottomNavBarColor,
      selectedItemColor: Colors.black, // Black for selected icons
      unselectedItemColor: Colors.black54, // Slightly faded black for unselected icons
      selectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.black,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: Colors.black54,
      ),
    ),
    cardTheme:  CardTheme(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );
}// 19752
// 6693
// 14178

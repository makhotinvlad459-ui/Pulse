import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, blue, green }

final themeProvider = StateNotifierProvider<ThemeNotifier, AppTheme>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppTheme> {
  ThemeNotifier() : super(AppTheme.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('app_theme');
    if (themeName != null) {
      state = AppTheme.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => AppTheme.light,
      );
    }
  }

  Future<void> _saveTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme.name);
  }

  void setTheme(AppTheme theme) {
    if (state != theme) {
      state = theme;
      _saveTheme(theme);
    }
  }
}

ThemeData getThemeData(AppTheme theme) {
  switch (theme) {
    case AppTheme.light:
      return ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.grey,  // серая кнопка
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        cardColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: Colors.grey.shade800,
          secondary: Colors.grey.shade600,
          surface: Colors.white,
          background: const Color(0xFFF2F2F2),
          onSurface: Colors.black87,
        ),
      );
   case AppTheme.dark:
  return ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.grey,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardColor: Colors.grey[850],      // цвет карточек
    colorScheme: ColorScheme.dark(
      primary: Colors.grey.shade300,
      secondary: Colors.grey.shade500,
      surface: Colors.grey[850]!,     // основа для карточек и вкладок
      background: Colors.grey[900]!,
      onSurface: Colors.white,
    ),
  );
  case AppTheme.blue:
  return ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blueGrey,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.blue.shade50,
    cardColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: Colors.blue.shade700,
      secondary: Colors.blue.shade500,
      surface: Colors.white,
      background: Colors.blue.shade50,
      onSurface: Colors.black87,
    ),
  );
    
    case AppTheme.green:
      return ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardColor: Colors.grey[900],
    colorScheme: ColorScheme.dark(
      primary: Colors.green.shade400,
      secondary: Colors.green.shade600,
      surface: Colors.grey[900]!,
      background: Colors.grey[900]!,
      onSurface: Colors.white,
    ),
  );
  }
}
import 'package:flutter/material.dart';

/// Design tokens lấy trực tiếp từ `:root` của LT-ARC-Web-UI_1.html và
/// LT-ARC-Mobile-UI_1.html (đã duyệt 01/09/2026) — xem plan §6.2.
/// Web và mobile KHÔNG dùng chung 1 ThemeData vì bo góc/tông nền khác nhau
/// trong 2 bản UI gốc.
class AppColors {
  AppColors._();

  static const gold = Color(0xFFB6924F);

  // Web (LT-ARC-Web-UI_1.html)
  static const webBackground = Color(0xFFF6F4EE);
  static const webForeground = Color(0xFF211F1B);
  static const webSidebar = Color(0xFF1B1916);
  static const webSidebarText = Color(0xFFC9C0AE);
  static const webBorder = Color(0xFFE6E0D0);

  /// Badge/stat semantic tokens — quy đổi gần đúng từ `oklch(...)` CSS gốc
  /// sang sRGB (Flutter `Color` không hỗ trợ oklch trực tiếp).
  static const webCardBg = Color(0xFFFFFFFF);
  static const webMutedFg = Color(0xFF8A8378);
  static const webSecondaryBg = Color(0xFFEFE9DC);
  static const webSecondaryFg = Color(0xFF2C2A25);
  static const webMutedBg = Color(0xFFF1EEE6);
  static const webDestructive = Color(0xFFD02C2A);
  static const webSuccess = Color(0xFF2F7D53);
  static const webWarning = Color(0xFFC89A46);
  static const webWarningFg = Color(0xFF332900);

  // Mobile (LT-ARC-Mobile-UI_1.html)
  static const mobileBackground = Color(0xFFF1F2F4);
  static const mobileForeground = Color(0xFF181A1F);
  static const mobileDarkCard = Color(0xFF16181D);
  static const mobileBorder = Color(0xFFEBECEF);
}

class AppTheme {
  AppTheme._();

  static ThemeData mobile() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Montserrat',
      scaffoldBackgroundColor: AppColors.mobileBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gold,
        primary: AppColors.mobileDarkCard,
        secondary: AppColors.gold,
        surface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.mobileBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.mobileForeground,
        elevation: 0,
      ),
    );
  }

  static ThemeData web() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Montserrat',
      scaffoldBackgroundColor: AppColors.webBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gold,
        primary: AppColors.webForeground,
        secondary: AppColors.gold,
        surface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.webBorder),
        ),
      ),
    );
  }
}

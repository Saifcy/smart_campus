import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // colors
  static const Color darkNavy = Color(0xFF242F3E); // dark mode background
  static const Color electricBlue = Color(0xFF4285F4); // Blue
  static const Color mapsGreen = Color(0xFF34A853); // Green
  static const Color mapsYellow = Color(0xFFFBBC05); // Yellow
  static const Color mapsRed = Color(0xFFEA4335); // Red
  static const Color mapsSurface = Color(0xFFF8F9FA); // Light surface
  static const Color mapsDarkSurface = Color(0xFF2D3748); // Dark surface
  
  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [electricBlue, Color(0xFF186EF2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const Gradient secondaryGradient = LinearGradient(
    colors: [mapsGreen, Color(0xFF2E9347)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shared properties
  static const double cornerRadius = 16.0;
  static const double smallCornerRadius = 8.0;
  static const double defaultElevation = 2.0;
  static const double defaultAnimationDuration = 200; // ms

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    primaryColor: electricBlue,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: electricBlue,
      secondary: mapsGreen,
      tertiary: mapsYellow,
      error: mapsRed,
      background: Colors.white,
      surface: mapsSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: defaultElevation,
      shadowColor: Colors.black26,
      iconTheme: const IconThemeData(color: Colors.black87),
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(smallCornerRadius),
        ),
      ),
    ),
    textTheme: GoogleFonts.robotoTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: electricBlue,
        foregroundColor: Colors.white,
        elevation: defaultElevation,
        shadowColor: electricBlue.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        textStyle: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: mapsSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
        borderSide: const BorderSide(color: electricBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      hintStyle: TextStyle(color: Colors.grey[600]),
      errorStyle: const TextStyle(color: mapsRed),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: electricBlue,
      unselectedItemColor: Colors.black54,
      elevation: defaultElevation,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
      unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: defaultElevation,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      elevation: 8,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: electricBlue,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFEEEEEE),
      thickness: 1,
      space: 1,
    ),
    tabBarTheme: TabBarTheme(
      labelColor: electricBlue,
      unselectedLabelColor: Colors.black54,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: electricBlue,
            width: 3.0,
          ),
        ),
      ),
      labelStyle: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    primaryColor: electricBlue,
    scaffoldBackgroundColor: darkNavy,
    colorScheme: ColorScheme.dark(
      primary: electricBlue,
      secondary: mapsGreen,
      tertiary: mapsYellow,
      error: mapsRed,
      background: darkNavy,
      surface: mapsDarkSurface,
      onSurface: Colors.white.withOpacity(0.87),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: mapsDarkSurface,
      foregroundColor: Colors.white,
      elevation: defaultElevation,
      shadowColor: Colors.black45,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(smallCornerRadius),
        ),
      ),
    ),
    textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: electricBlue,
        foregroundColor: Colors.white,
        elevation: defaultElevation,
        shadowColor: electricBlue.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        textStyle: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: mapsDarkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
        borderSide: const BorderSide(color: electricBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      hintStyle: TextStyle(color: Colors.grey[400]),
      errorStyle: const TextStyle(color: mapsRed),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: mapsDarkSurface,
      selectedItemColor: electricBlue,
      unselectedItemColor: Colors.white70,
      elevation: defaultElevation,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
      unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
    ),
    cardTheme: CardTheme(
      color: mapsDarkSurface,
      elevation: defaultElevation,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: mapsDarkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      elevation: 8,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: electricBlue,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3A4556),
      thickness: 1,
      space: 1,
    ),
    tabBarTheme: TabBarTheme(
      labelColor: electricBlue,
      unselectedLabelColor: Colors.white70,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: electricBlue,
            width: 3.0,
          ),
        ),
      ),
      labelStyle: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
} 
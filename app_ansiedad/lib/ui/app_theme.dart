import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tema global de la app. Da el look de la guía a todo lo que no define su
/// propio estilo (diálogos, spinners, inputs, botones, snackbars), para no
/// repetirlo pantalla por pantalla.
class AppTheme {
  AppTheme._();

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(seedColor: AppColors.primario).copyWith(
      primary: AppColors.primario,
      onPrimary: Colors.white,
      surface: AppColors.superficie,
      onSurface: AppColors.texto,
      outline: AppColors.borde,
      error: AppColors.altos,
    );

    final bordeRedondeado = BorderRadius.circular(AppColors.radio);

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: bordeRedondeado,
          side: const BorderSide(color: AppColors.borde),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.superficie,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textoSecundario),
        prefixIconColor: AppColors.textoSecundario,
        suffixIconColor: AppColors.textoSecundario,
        border: OutlineInputBorder(
          borderRadius: bordeRedondeado,
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: bordeRedondeado,
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: bordeRedondeado,
          borderSide: const BorderSide(color: AppColors.primario, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primario,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: bordeRedondeado),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primario),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: bordeRedondeado),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primario),
      dividerTheme: const DividerThemeData(color: AppColors.borde, thickness: 1),
    );
  }
}

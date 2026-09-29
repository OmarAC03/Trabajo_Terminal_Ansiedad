import 'package:flutter/material.dart';

/// Paleta única de la app (GUIA_ESTILO_APP.md, sección 1). Es la misma que
/// `web_portal/src/ui/tokens.css`, para que app y portal se vean como un solo
/// sistema. Las pantallas toman los colores de aquí en vez de repetir hex.
class AppColors {
  AppColors._(); // no instanciable

  // --- Base ---
  static const Color fondo = Color(0xFFF8FAFC);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color texto = Color(0xFF1E293B);
  static const Color textoSecundario = Color(0xFF94A3B8);
  static const Color textoAyuda = Color(0xFF64748B);
  static const Color borde = Color(0xFFE2E8F0);

  // --- Primario ---
  static const Color primario = Color(0xFF2563EB);
  static const Color primarioOscuro = Color(0xFF1D4ED8);
  static const Color primarioMasOscuro = Color(0xFF1E40AF);
  static const Color primarioSuave = Color(0xFFEFF6FF);

  /// Gradiente del encabezado: arriba-izquierda → abajo-derecha.
  static const LinearGradient gradienteEncabezado = LinearGradient(
    colors: [primarioOscuro, primario],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Semáforo (texto visible: Normal / Elevados / Altos / Sin lecturas) ---
  static const Color normal = Color(0xFF16A34A);
  static const Color normalFondo = Color(0xFFF0FDF4);
  static const Color elevados = Color(0xFFD97706);
  static const Color elevadosFondo = Color(0xFFFFFBEB);
  static const Color altos = Color(0xFFDC2626);
  static const Color altosFondo = Color(0xFFFEF2F2);
  static const Color sinLecturas = Color(0xFF94A3B8);
  static const Color sinLecturasFondo = Color(0xFFF1F5F9);

  // --- Forma ---
  static const double radio = 12;
  static const List<BoxShadow> sombra = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

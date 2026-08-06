import 'package:flutter/material.dart';

/// High-contrast futuristic palette (readable on dark glass).
abstract final class AppColors {
  static const voidBlack = Color(0xFF070B14);
  static const deepNavy = Color(0xFF0B1220);
  static const panel = Color(0xE6141E30);
  static const panelSolid = Color(0xFF141E30);
  static const border = Color(0xFF2A3A55);
  static const borderActive = Color(0xFF2DD4BF);

  static const cyan = Color(0xFF2DD4BF);
  static const cyanBright = Color(0xFF5EEAD4);
  static const cyanDim = Color(0xFF115E59);

  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF87171);

  // Legacy aliases used during migration
  static const teal = cyan;
  static const tealDeep = cyanDim;
  static const slate = textPrimary;
  static const mist = deepNavy;
}

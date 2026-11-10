import 'package:flutter/material.dart';

/// Tokens de color del panel.
///
/// Valores equivalentes a los que el panel ya usaba de forma literal; se
/// centralizan aquí para que la capa de formularios y las pantallas compartan
/// la misma paleta (mismo criterio que `UiColors` en Correspondencia).
class UiColors {
  const UiColors._();

  /// Verde institucional.
  static const primary = Color(0xff087443);
  static const primaryDeep = Color(0xff06432e);

  /// Superficies.
  static const background = Color(0xfff6f8f7);
  static const surface = Colors.white;
  static const border = Color(0xffdce8e0);
  static const borderStrong = Color(0xffc6d8cc);

  /// Texto.
  static const textPrimary = Color(0xff18392f);
  static const textSecondary = Color(0xff52675e);
  static const textMuted = Color(0xff7b8e85);

  /// Estados.
  static const danger = Color(0xffb3261e);
  static const successSoft = Color(0xffd9f2e3);
  static const neutralSoft = Color(0xfff1f1ed);
}

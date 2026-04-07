import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s24 = 24;
}

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 300);
  static const Curve curve = Curves.easeOutCubic;
}

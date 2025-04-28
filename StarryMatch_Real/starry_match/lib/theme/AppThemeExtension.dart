import 'package:flutter/material.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final String bgLogin;
  final String bgStart;
  final String bgHome;
  final String bgMain;
  final String bgDashboard;
  final String bgMbti;
  final String bgCriteria;
  final String bgTestSelection;
  final String bgGuidance;
  final String bgEnneagram;
  final String bgEmail;
  final String logo1;
  final String logo2;
  const AppThemeExtension({
    required this.bgLogin,
    required this.bgStart,
    required this.bgHome,
    required this.bgMain,
    required this.bgDashboard,
    required this.bgMbti,
    required this.bgCriteria,
    required this.bgTestSelection,
    required this.bgGuidance,
    required this.bgEnneagram,
    required this.bgEmail,
    required this.logo1,
    required this.logo2,
  });

  @override
  AppThemeExtension copyWith({
    String? bgLogin,
    String? bgStart,
    String? bgHome,
    String? bgMain,
    String? bgDashboard,
    String? bgMbti,
    String? bgCriteria,
    String? bgTestSelection,
    String? bgGuidance,
    String? bgEnneagram,
    String? bgEmail,
    String? logo1,
    String? logo2,
  }) {
    return AppThemeExtension(
      bgLogin: bgLogin ?? this.bgLogin,
      bgStart: bgStart ?? this.bgStart,
      bgHome: bgHome ?? this.bgHome,
      bgMain: bgMain ?? this.bgMain,
      bgDashboard: bgDashboard ?? this.bgDashboard,
      bgMbti: bgMbti ?? this.bgMbti,
      bgCriteria: bgCriteria ?? this.bgCriteria,
      bgTestSelection: bgTestSelection ?? this.bgTestSelection,
      bgGuidance: bgGuidance ?? this.bgGuidance,
      bgEnneagram: bgEnneagram ?? this.bgEnneagram,
      bgEmail: bgEmail ?? this.bgEmail,
      logo1: logo1 ?? this.logo1,
      logo2: logo2 ?? this.logo2,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return this; // ไม่มีการ interpolate เพราะเป็น path ของรูปภาพ
  }
}

import 'package:flutter/cupertino.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF6C5CE7);
  static const primaryLight = Color(0xFFA29BFE);
  static const primaryDark = Color(0xFF4834D4);

  static const success = Color(0xFF00B894);
  static const successLight = Color(0xFF55EFC4);
  static const warning = Color(0xFFFDCB6E);
  static const warningDark = Color(0xFFE17055);
  static const error = Color(0xFFD63031);
  static const errorLight = Color(0xFFFF7675);
  static const info = Color(0xFF0984E3);
  static const infoLight = Color(0xFF74B9FF);

  static const labelLight = Color(0xFF3C3C43);
  static const secondaryLabelLight = Color(0xFF8E8E93);
  static const tertiaryLabelLight = Color(0xFFC7C7CC);
  static const quaternaryLabelLight = Color(0xFFD1D1D6);

  static const labelDark = Color(0xFFFFFFFF);
  static const secondaryLabelDark = Color(0xFFEBEBF5);
  static const tertiaryLabelDark = Color(0xFF8E8E93);
  static const quaternaryLabelDark = Color(0xFF3A3A3C);

  // Explicit semantic label tokens (WCAG AA compliant on black)
  static const labelPrimary = Color(0xFFFFFFFF); // ~100% opacity
  static const labelSecondary = Color(0xFFB3B3B3); // ~70% opacity
  static const labelTertiary = Color(0xFF8E8E93); // ~55% opacity

  static const groupedBackgroundLight = CupertinoColors.systemGroupedBackground;
  static const groupedBackgroundDark = Color(0xFF000000);

  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1C1C1E);

  static const lightText = Color(0xFF000000);
  static const darkText = Color(0xFFFFFFFF);
  static const lightSecondaryText = Color(0xFF8E8E93);
  static const darkSecondaryText = Color(0xFFC7C7CC);
}

class AppTheme {
  AppTheme._();

  static const _primary = AppColors.primary;

  static const _lightTextTheme = CupertinoTextThemeData(
    primaryColor: _primary,
    textStyle: TextStyle(
      color: AppColors.labelLight,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    actionTextStyle: TextStyle(
      color: _primary,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    tabLabelTextStyle: TextStyle(
      color: AppColors.secondaryLabelLight,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    ),
    navTitleTextStyle: TextStyle(
      color: AppColors.labelLight,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    navLargeTitleTextStyle: TextStyle(
      color: AppColors.labelLight,
      fontSize: 34,
      fontWeight: FontWeight.w700,
    ),
    dateTimePickerTextStyle: TextStyle(
      color: AppColors.labelLight,
      fontSize: 21,
      fontWeight: FontWeight.w400,
    ),
    pickerTextStyle: TextStyle(
      color: AppColors.labelLight,
      fontSize: 21,
      fontWeight: FontWeight.w400,
    ),
  );

  static const _darkTextTheme = CupertinoTextThemeData(
    primaryColor: _primary,
    textStyle: TextStyle(
      color: AppColors.labelDark,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    actionTextStyle: TextStyle(
      color: _primary,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    tabLabelTextStyle: TextStyle(
      color: AppColors.secondaryLabelDark,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    ),
    navTitleTextStyle: TextStyle(
      color: AppColors.labelDark,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    navLargeTitleTextStyle: TextStyle(
      color: AppColors.labelDark,
      fontSize: 34,
      fontWeight: FontWeight.w700,
    ),
    dateTimePickerTextStyle: TextStyle(
      color: AppColors.labelDark,
      fontSize: 21,
      fontWeight: FontWeight.w400,
    ),
    pickerTextStyle: TextStyle(
      color: AppColors.labelDark,
      fontSize: 21,
      fontWeight: FontWeight.w400,
    ),
  );

  static CupertinoThemeData get cupertinoLight {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: _primary,
      scaffoldBackgroundColor: AppColors.groupedBackgroundLight,
      textTheme: _lightTextTheme,
    );
  }

  static CupertinoThemeData get cupertinoDark {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: _primary,
      scaffoldBackgroundColor: AppColors.groupedBackgroundDark,
      textTheme: _darkTextTheme,
    );
  }
}

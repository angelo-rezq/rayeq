import 'package:flutter/material.dart';

const royalBackground = Color(0xff100c21),
    royalSurface = Color(0xff211a35),
    royalRaised = Color(0xff2b233e),
    royalGold = Color(0xffe7c35b),
    royalPurple = Color(0xffa174e9),
    royalText = Color(0xfff6f2fd),
    royalMuted = Color(0xffb4aac8),
    royalLine = Color(0xff3b304f);
ThemeData rayeqTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'PlexArabic',
  scaffoldBackgroundColor: royalBackground,
  colorScheme: const ColorScheme.dark(
    primary: royalGold,
    onPrimary: royalBackground,
    secondary: royalPurple,
    surface: royalSurface,
    onSurface: royalText,
    outline: royalLine,
    error: Color(0xffffa4a4),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.75, color: royalText),
    headlineLarge: TextStyle(
      fontSize: 29,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: royalText,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: royalText,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: royalBackground,
    surfaceTintColor: royalBackground,
    foregroundColor: royalText,
    centerTitle: false,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: royalGold,
      foregroundColor: royalBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(
        fontFamily: 'PlexArabic',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: royalGold,
      side: const BorderSide(color: royalLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: royalRaised,
    labelStyle: const TextStyle(color: royalMuted, fontSize: 13),
    hintStyle: const TextStyle(color: royalMuted, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: royalLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: royalLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: royalGold),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: royalSurface,
    indicatorColor: Color(0xff4b3d27),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontFamily: 'PlexArabic', fontSize: 10),
    ),
    height: 76,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: royalRaised,
    selectedColor: royalGold,
    labelStyle: const TextStyle(fontFamily: 'PlexArabic', fontSize: 11),
    secondaryLabelStyle: const TextStyle(color: royalBackground),
    side: const BorderSide(color: royalLine),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  dividerColor: royalLine,
  dialogTheme: DialogThemeData(
    backgroundColor: royalSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  ),
);

class RoyalBackdrop extends StatelessWidget {
  final Widget child;
  const RoyalBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [Color(0xff291645), royalBackground],
        stops: [0, 0.65],
      ),
    ),
    child: child,
  );
}

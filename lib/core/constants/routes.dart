class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String contactDetail = '/contact-detail';
  static const String nfcReceive = '/nfc-receive';

  static const List<String> bottomNavRoutes = [
    home,
    profile,
    history,
  ];

  static String getBottomNavRoute(int index) {
    if (index >= 0 && index < bottomNavRoutes.length) {
      return bottomNavRoutes[index];
    }
    return home;
  }

  static int getBottomNavIndex(String route) {
    final index = bottomNavRoutes.indexOf(route);
    return index >= 0 ? index : -1; // Return -1 for non-nav routes
  }
}
class FocusPageVisibility {
  static bool _isOnFocusPage = false;

  static bool get isOnFocusPage => _isOnFocusPage;

  static void setOnFocusPage(bool value) {
    _isOnFocusPage = value;
  }
}

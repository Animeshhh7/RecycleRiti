import 'package:flutter/foundation.dart';

class BottomNavController with ChangeNotifier {
  int _currentIndex = 0;
  final int _totalTabs;

  BottomNavController({int totalTabs = 4}) : _totalTabs = totalTabs;

  int get currentIndex => _currentIndex;

  void changeIndex(int newIndex) {
    if (newIndex < 0 || newIndex >= _totalTabs) {
      print('BottomNavController: Invalid tab index: $newIndex (must be between 0 and ${_totalTabs - 1})');
      return;
    }
    _currentIndex = newIndex;
    print('BottomNavController: Changed tab index to $_currentIndex');
    notifyListeners();
  }

  void resetIndex() {
    _currentIndex = 0;
    print('BottomNavController: Reset tab index to 0');
    notifyListeners();
  }
}// 28765
// 15226
// 18418
// 9492

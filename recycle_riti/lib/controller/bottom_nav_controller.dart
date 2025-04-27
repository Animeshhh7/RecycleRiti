import 'package:flutter/material.dart';

class BottomNavController extends ChangeNotifier {
  int _currentIndex = 0;
  final int _totalTabs;

  BottomNavController({int totalTabs = 4}) : _totalTabs = totalTabs;

  int get currentIndex => _currentIndex;

  void changeIndex(int newIndex) {
    if (newIndex < 0 || newIndex >= _totalTabs) {
      throw RangeError('Index must be between 0 and ${_totalTabs - 1}');
    }
    _currentIndex = newIndex;
    notifyListeners();
  }

  void resetIndex() {
    _currentIndex = 0;
    notifyListeners();
  }
}
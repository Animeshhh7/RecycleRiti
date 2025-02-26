import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recycle_riti/controller/bottom_nav_controller.dart';
import 'package:recycle_riti/model/page_model.dart';
import 'package:recycle_riti/utils/theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final List<PageModel> pages;

  const CustomBottomNavBar({
    super.key,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    print('CustomBottomNavBar: Building with ${pages.length} tabs');
    final navCtrl = Provider.of<BottomNavController>(context);
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: navCtrl.currentIndex,
        onTap: (idx) {
          navCtrl.changeIndex(idx);
        },
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedFontSize: 14,
        unselectedFontSize: 12,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        selectedLabelStyle: const TextStyle(color: Colors.white),
        unselectedLabelStyle: const TextStyle(color: Colors.white),
        items: pages.map((page) {
          return BottomNavigationBarItem(
            icon: Icon(
              page.ico,
              size: screenWidth < 600 ? 24 : 28,
              color: Colors.white.withOpacity(0.6),
            ),
            activeIcon: Icon(
              page.ico,
              size: screenWidth < 600 ? 24 : 28,
              color: Colors.white,
            ),
            label: page.lbl,
            tooltip: page.lbl,
          );
        }).toList(),
      ),
    );
  }
}// 7720
// 10001

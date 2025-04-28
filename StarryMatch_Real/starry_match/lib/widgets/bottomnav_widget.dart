import 'package:flutter/material.dart';
import 'package:starry_match/Dashboard.dart';
import 'package:starry_match/Directmessage.dart';
import 'package:starry_match/Store.dart';
import 'package:starry_match/guidanceselection.dart';
import 'package:starry_match/home.dart';

class BottomNavWidget extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final String userId;

  const BottomNavWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return BottomAppBar(
      child: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 0, context),
            _buildNavItem(Icons.message, 1, context),
            _buildNavItem(Icons.lightbulb, 2, context),
            _buildNavItem(Icons.store, 3, context),
            _buildNavItem(Icons.dashboard, 4, context),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: 33,
        color: selectedIndex == index
            ? Colors.deepPurple
            : const Color.fromARGB(255, 151, 96, 228),
      ),
      onPressed: () => _onItemTapped(index, context),
    );
  }

  void _onItemTapped(int index, BuildContext context) {
    onItemTapped(index);
     if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(userId: userId),
        ),
      );
    }

    else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DirectMessagePage(userId: userId),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GuidanceSelectionPage(userId: userId),
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StorePage(userId: userId),
        ),
      );
    }
     else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(userId: userId),
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';

import '../services/rider_session.dart';
import '../theme/rider_theme.dart';
import 'delivery_dashboard_page.dart';
import 'pickup_dashboard_page.dart';
import 'profit_dashboard_page.dart';
import 'rider_portal_page.dart';

class RiderShellPage extends StatefulWidget {
  final RiderSession session;
  final int initialTab;

  const RiderShellPage({
    super.key,
    required this.session,
    this.initialTab = 0,
  });

  @override
  State<RiderShellPage> createState() => _RiderShellPageState();
}

class _RiderShellPageState extends State<RiderShellPage> {
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      PickupDashboardPage(session: widget.session),
      DeliveryDashboardPage(session: widget.session),
      ProfitDashboardPage(session: widget.session),
      RiderChatPage(session: widget.session),
      RiderAccountPage(session: widget.session),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: RiderColors.border, width: 1),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: (index) => setState(() => _currentTab = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: RiderColors.teal,
            unselectedItemColor: RiderColors.textSecondary,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Pickups',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_shipping_outlined),
                activeIcon: Icon(Icons.local_shipping),
                label: 'Deliveries',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet),
                label: 'Earnings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                activeIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Messages',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

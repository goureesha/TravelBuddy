import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';
import 'teams_screen.dart';
import 'live_map_screen.dart';
import 'fuel_track_screen.dart';
import 'speed_screen.dart';
import 'blog_screen.dart';
import 'expense_screen.dart';
import 'sos_screen.dart';
import 'checklist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = const [
    _DashboardTab(),
    LiveMapScreen(),
    TeamsScreen(),
    FuelTrackScreen(),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF1A73E8).withOpacity(0.2),
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Teams',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_gas_station_outlined),
              selectedIcon: Icon(Icons.local_gas_station_rounded),
              label: 'Fuel',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════
// TAB: Dashboard
// ══════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hey, ${user?.displayName?.split(' ').first ?? 'Traveler'}!',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Ready to explore?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Quick actions
            Text(
              'Quick Actions',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _quickAction(
                  Icons.speed_rounded,
                  'Speed',
                  const Color(0xFF00BFA5),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeedScreen())),
                ),
                const SizedBox(width: 12),
                _quickAction(
                  Icons.local_gas_station_rounded,
                  'Fuel Track',
                  const Color(0xFFFF6D00),
                  () {
                    // Navigate to Fuel tab
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    homeState?.setState(() => homeState._currentIndex = 3);
                  },
                ),
                const SizedBox(width: 12),
                _quickAction(
                  Icons.group_add_rounded,
                  'Teams',
                  const Color(0xFF1A73E8),
                  () {
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    homeState?.setState(() => homeState._currentIndex = 2);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _quickAction(
                  Icons.auto_stories_rounded,
                  'Blog',
                  const Color(0xFF9C27B0),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlogScreen())),
                ),
                const SizedBox(width: 12),
                _quickAction(
                  Icons.map_rounded,
                  'Live Map',
                  const Color(0xFF2196F3),
                  () {
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    homeState?.setState(() => homeState._currentIndex = 1);
                  },
                ),
                const SizedBox(width: 12),
                _quickAction(
                  Icons.add_location_alt_rounded,
                  'POI',
                  const Color(0xFFFF6D00),
                  () {
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    homeState?.setState(() => homeState._currentIndex = 1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _quickAction(
                  Icons.account_balance_wallet_rounded,
                  'Expenses',
                  const Color(0xFF9C27B0),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen())),
                ),
                const SizedBox(width: 12),
                _quickAction(
                  Icons.sos_rounded,
                  'SOS',
                  const Color(0xFFE53935),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
                ),
                const SizedBox(width: 12),
                _quickAction(
                  Icons.checklist_rounded,
                  'Checklist',
                  const Color(0xFF26A69A),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChecklistScreen())),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Stats cards
            Text(
              'Your Stats',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('0', 'Trips', Icons.route_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('0 km', 'Distance', Icons.straighten_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('0', 'Teams', Icons.people_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('₹0', 'Fuel Cost', Icons.local_gas_station_rounded)),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Map tab now uses LiveMapScreen from live_map_screen.dart

// Teams tab now uses TeamsScreen from teams_screen.dart

// ══════════════════════════════════════
// TAB: Profile
// ══════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 48,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'Traveler',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              user?.email ?? '',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.54),
              ),
            ),
            const SizedBox(height: 32),
            // Sign out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

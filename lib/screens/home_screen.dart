import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../widgets/notification_bell.dart';
import '../services/weather_service.dart';

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
    BlogScreen(),
    TeamsScreen(),
    FuelTrackScreen(),
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
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories_rounded),
              label: 'Post',
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
                // Notification bell
                const NotificationBell(),
                const SizedBox(width: 8),
                // Profile icon
                GestureDetector(
                  onTap: () => _showProfileSheet(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Icon(Icons.person_rounded, color: Colors.white.withOpacity(0.7), size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Weather card
            const _WeatherCard(),
            const SizedBox(height: 24),
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
                  Icons.account_balance_wallet_rounded,
                  'Expenses',
                  const Color(0xFFFF6D00),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen())),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
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
            _LiveStats(),
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

  static void _showProfileSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          CircleAvatar(
            radius: 40,
            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null ? const Icon(Icons.person, size: 36) : null,
          ),
          const SizedBox(height: 14),
          Text(user?.displayName ?? 'Traveler',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(user?.email ?? '',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.54))),
          const SizedBox(height: 24),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// Map tab now uses LiveMapScreen from live_map_screen.dart

// Teams tab now uses TeamsScreen from teams_screen.dart

/// Real-time stats from Firestore
class _LiveStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('members', arrayContains: uid)
          .snapshots(),
      builder: (context, teamSnap) {
        final teamCount = teamSnap.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('trips')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, tripSnap) {
            final tripCount = tripSnap.data?.docs.length ?? 0;

            // Calculate total distance from trips
            double totalKm = 0;
            for (final doc in tripSnap.data?.docs ?? []) {
              final data = doc.data() as Map<String, dynamic>;
              totalKm += (data['distanceKm'] as num?)?.toDouble() ?? 0;
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fuel_logs')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, fuelSnap) {
                double totalFuelCost = 0;
                for (final doc in fuelSnap.data?.docs ?? []) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalFuelCost += (data['totalCost'] as num?)?.toDouble() ?? 0;
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _statCard('$tripCount', 'Trips', Icons.route_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(
                          totalKm > 0 ? '${totalKm.toStringAsFixed(0)} km' : '0 km',
                          'Distance', Icons.straighten_rounded,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _statCard('$teamCount', 'Teams', Icons.people_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(
                          '₹${totalFuelCost.toStringAsFixed(0)}',
                          'Fuel Cost', Icons.local_gas_station_rounded,
                        )),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
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

/// Weather card for dashboard
class _WeatherCard extends StatefulWidget {
  const _WeatherCard();

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> {
  WeatherData? _weather;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted) {
      setState(() {
        _weather = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_weather == null) return const SizedBox.shrink();

    final w = _weather!;
    final bgColors = w.isDay
        ? [const Color(0xFF1A73E8), const Color(0xFF4FC3F7)]
        : [const Color(0xFF1A237E), const Color(0xFF283593)];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bgColors[0].withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 4),
              Text(
                '${w.temperature.toStringAsFixed(0)}${String.fromCharCode(0x00B0)}',
                style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 36,
                  fontWeight: FontWeight.w900, height: 1,
                ),
              ),
              Text(w.condition,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _weatherDetail(Icons.thermostat_rounded, 'Feels ${w.feelsLike.toStringAsFixed(0)}${String.fromCharCode(0x00B0)}'),
              const SizedBox(height: 6),
              _weatherDetail(Icons.water_drop_rounded, '${w.humidity}% humidity'),
              const SizedBox(height: 6),
              _weatherDetail(Icons.air_rounded, '${w.windSpeed.toStringAsFixed(0)} km/h wind'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

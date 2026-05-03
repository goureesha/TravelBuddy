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
import 'trip_log_screen.dart';
import 'settings_screen.dart';
import 'packing_list_screen.dart';
import 'trip_planner_screen.dart';
import 'trip_cost_screen.dart';
import 'document_wallet_screen.dart';
import 'group_expense_screen.dart';
import 'route_optimizer_screen.dart';
import 'trip_sharing_screen.dart';
import 'expense_analytics_screen.dart';
import 'travel_badges_screen.dart';
import 'smart_packing_screen.dart';
import 'discover_places_screen.dart';
import 'travel_journal_screen.dart';
import 'currency_converter_screen.dart';
import 'travel_alerts_screen.dart';
import 'budget_planner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
      key: _scaffoldKey,
      drawer: _buildDrawer(context, user),
      body: Stack(
        children: [
          _pages[_currentIndex],
          // Hamburger menu button - top left
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.menu_rounded, color: Colors.white70, size: 22),
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildDrawer(BuildContext context, User? user) {
    return Drawer(
      backgroundColor: const Color(0xFF161B22),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    backgroundColor: const Color(0xFF1A73E8),
                    child: user?.photoURL == null
                        ? Text(user?.displayName?.isNotEmpty == true ? user!.displayName![0] : '?',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? 'Traveler',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(user?.email ?? '',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            const SizedBox(height: 8),
            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Quick Actions',
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
              ),
            ),
            _drawerItem(Icons.speed_rounded, 'Speedometer', const Color(0xFF00BFA5), () => const SpeedScreen()),
            _drawerItem(Icons.account_balance_wallet_rounded, 'Expenses', const Color(0xFFFF6D00), () => const ExpenseScreen()),
            _drawerItem(Icons.sos_rounded, 'SOS Alert', const Color(0xFFE53935), () => const SosScreen()),
            _drawerItem(Icons.checklist_rounded, 'Checklist', const Color(0xFF26A69A), () => const ChecklistScreen()),
            _drawerItem(Icons.timeline_rounded, 'Trip Log', const Color(0xFF7C4DFF), () => const TripLogScreen()),
            _drawerItem(Icons.luggage_rounded, 'Packing Lists', const Color(0xFFFF7043), () => const PackingListScreen()),
            _drawerItem(Icons.map_rounded, 'Trip Planner', const Color(0xFF1A73E8), () => const TripPlannerScreen()),
            _drawerItem(Icons.receipt_long_rounded, 'Trip Costs', const Color(0xFFEC407A), () => const TripCostScreen()),
            _drawerItem(Icons.folder_rounded, 'Documents', const Color(0xFF8D6E63), () => const DocumentWalletScreen()),
            _drawerItem(Icons.group_work_rounded, 'Split Costs', const Color(0xFF5C6BC0), () => const GroupExpenseScreen()),
            _drawerItem(Icons.alt_route_rounded, 'Route Plan', const Color(0xFF66BB6A), () => const RouteOptimizerScreen()),
            _drawerItem(Icons.share_rounded, 'Share Trips', const Color(0xFFFFB74D), () => const TripSharingScreen()),
            _drawerItem(Icons.bar_chart_rounded, 'Analytics', const Color(0xFF29B6F6), () => const ExpenseAnalyticsScreen()),
            _drawerItem(Icons.emoji_events_rounded, 'Badges', const Color(0xFFFF6D00), () => const TravelBadgesScreen()),
            _drawerItem(Icons.luggage_rounded, 'Smart Pack', const Color(0xFF26A69A), () => const SmartPackingScreen()),
            _drawerItem(Icons.explore_rounded, 'Discover', const Color(0xFFFFB300), () => const DiscoverPlacesScreen()),
            _drawerItem(Icons.auto_stories_rounded, 'Journal', const Color(0xFF7E57C2), () => const TravelJournalScreen()),
            _drawerItem(Icons.currency_exchange_rounded, 'Currency', const Color(0xFF1A73E8), () => const CurrencyConverterScreen()),
            _drawerItem(Icons.notification_important_rounded, 'Alerts', const Color(0xFFE53935), () => const TravelAlertsScreen()),
            _drawerItem(Icons.account_balance_wallet_rounded, 'Budget', const Color(0xFF00897B), () => const BudgetPlannerScreen()),
            const Spacer(),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            _drawerItem(Icons.settings_rounded, 'Settings', Colors.white38, () => const SettingsScreen()),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, Color color, Widget Function() screenBuilder) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
      onTap: () {
        Navigator.pop(context); // close drawer
        Navigator.push(context, MaterialPageRoute(builder: (_) => screenBuilder()));
      },
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
            // Header with padding for menu button
            const SizedBox(height: 44),
            Row(
              children: [
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
                const NotificationBell(),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showProfileSheet(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: user?.photoURL != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(user!.photoURL!, fit: BoxFit.cover),
                          )
                        : Icon(Icons.person_rounded, color: Colors.white.withOpacity(0.7), size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Weather card
            const _WeatherCard(),
            const SizedBox(height: 16),
            // Trip countdown
            _TripCountdown(),
            const SizedBox(height: 24),
            // Recent Activity
            Text(
              'Recent Activity',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            _RecentActivity(),
            const SizedBox(height: 24),
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

/// Trip countdown widget — shows days until next trip
class _TripCountdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('planned_trips')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        DateTime? nextTripDate;
        String? nextTripName;

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final dateStr = data['startDate'] as String?;
          if (dateStr == null) continue;

          // Try parsing common date formats
          DateTime? tripDate;
          try {
            // Try yyyy-MM-dd
            tripDate = DateTime.tryParse(dateStr);
            if (tripDate == null) {
              // Try dd/MM/yyyy
              final parts = dateStr.split('/');
              if (parts.length == 3) {
                tripDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            }
          } catch (_) {}

          if (tripDate != null && tripDate.isAfter(now)) {
            if (nextTripDate == null || tripDate.isBefore(nextTripDate)) {
              nextTripDate = tripDate;
              nextTripName = data['name'] as String? ?? 'Trip';
            }
          }
        }

        if (nextTripDate == null) return const SizedBox.shrink();

        final daysLeft = nextTripDate.difference(now).inDays;
        final hoursLeft = nextTripDate.difference(now).inHours % 24;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: daysLeft <= 3
                  ? [const Color(0xFFFF6D00), const Color(0xFFFF9100)]
                  : [const Color(0xFF7C4DFF), const Color(0xFFB388FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (daysLeft <= 3 ? const Color(0xFFFF6D00) : const Color(0xFF7C4DFF)).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$daysLeft', style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                    Text('days', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nextTripName!, style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      daysLeft == 0
                          ? 'Today! ${hoursLeft}h left'
                          : daysLeft == 1
                              ? 'Tomorrow!'
                              : '$daysLeft days to go',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.flight_takeoff_rounded, color: Colors.white38, size: 24),
            ],
          ),
        );
      },
    );
  }
}

/// Recent activity feed from multiple Firestore collections
class _RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('trip_costs')
          .orderBy('createdAt', descending: true).limit(5)
          .snapshots(),
      builder: (context, costSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(uid).collection('checkpoints')
              .orderBy('timestamp', descending: true).limit(5)
              .snapshots(),
          builder: (context, logSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fuel_logs')
                  .where('userId', isEqualTo: uid)
                  .orderBy('timestamp', descending: true).limit(3)
                  .snapshots(),
              builder: (context, fuelSnap) {
                final List<_ActivityItem> items = [];

                // Cost entries
                for (final doc in costSnap.data?.docs ?? []) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['createdAt'] as Timestamp?;
                  if (ts != null) {
                    items.add(_ActivityItem(
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFFEC407A),
                      title: '${d['category'] ?? 'Expense'} — ₹${(d['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      subtitle: d['note'] as String? ?? '',
                      time: ts.toDate(),
                    ));
                  }
                }

                // Trip log checkpoints
                for (final doc in logSnap.data?.docs ?? []) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts != null) {
                    items.add(_ActivityItem(
                      icon: Icons.location_on_rounded,
                      color: const Color(0xFF7C4DFF),
                      title: d['label'] as String? ?? 'Checkpoint',
                      subtitle: '',
                      time: ts.toDate(),
                    ));
                  }
                }

                // Fuel logs
                for (final doc in fuelSnap.data?.docs ?? []) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts != null) {
                    items.add(_ActivityItem(
                      icon: Icons.local_gas_station_rounded,
                      color: const Color(0xFFFF6D00),
                      title: 'Fuel — ₹${(d['totalCost'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      subtitle: '${(d['liters'] as num?)?.toStringAsFixed(1) ?? '0'} L',
                      time: ts.toDate(),
                    ));
                  }
                }

                items.sort((a, b) => b.time.compareTo(a.time));
                final display = items.take(5).toList();

                if (display.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Center(
                      child: Text('No recent activity yet',
                          style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                    ),
                  );
                }

                return Column(
                  children: display.map((item) {
                    final ago = _timeAgo(item.time);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: item.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item.icon, color: item.color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: GoogleFonts.inter(
                                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (item.subtitle.isNotEmpty)
                                    Text(item.subtitle, style: GoogleFonts.inter(
                                        color: Colors.white30, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(ago, style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime time;
  _ActivityItem({required this.icon, required this.color, required this.title, required this.subtitle, required this.time});
}

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
  List<ForecastDay> _forecast = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await WeatherService.getCurrentWeather();
      final forecast = await WeatherService.getForecast();
      if (mounted) {
        setState(() {
          _weather = data;
          _forecast = forecast;
          _loading = false;
          _error = data == null ? 'Enable location to see weather' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = 'Weather unavailable'; });
      }
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

    if (_weather == null) {
      return GestureDetector(
        onTap: _loadWeather,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                const SizedBox(width: 8),
                Text(_error ?? 'Tap to retry',
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.3), fontSize: 13)),
                const SizedBox(width: 8),
                Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.2), size: 16),
              ],
            ),
          ),
        ),
      );
    }

    final w = _weather!;
    final bgColors = w.isDay
        ? [const Color(0xFF1A73E8), const Color(0xFF4FC3F7)]
        : [const Color(0xFF1A237E), const Color(0xFF283593)];

    final deg = String.fromCharCode(0x00B0);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
      child: Column(
        children: [
          // Current weather
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.icon, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 4),
                  Text(
                    '${w.temperature.toStringAsFixed(0)}$deg',
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
                  _weatherDetail(Icons.thermostat_rounded, 'Feels ${w.feelsLike.toStringAsFixed(0)}$deg'),
                  const SizedBox(height: 6),
                  _weatherDetail(Icons.water_drop_rounded, '${w.humidity}% humidity'),
                  const SizedBox(height: 6),
                  _weatherDetail(Icons.air_rounded, '${w.windSpeed.toStringAsFixed(0)} km/h wind'),
                ],
              ),
            ],
          ),
          // 3-day forecast
          if (_forecast.length > 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Colors.white.withOpacity(0.15), height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _forecast.map((day) {
                final isToday = day.date.day == DateTime.now().day;
                final label = isToday ? 'Today' : dayNames[day.date.weekday - 1];
                return Column(
                  children: [
                    Text(label, style: GoogleFonts.inter(
                      color: isToday ? Colors.white : Colors.white54,
                      fontSize: 11, fontWeight: isToday ? FontWeight.w600 : FontWeight.w400)),
                    const SizedBox(height: 4),
                    Text(day.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('${day.tempMax.toStringAsFixed(0)}$deg',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${day.tempMin.toStringAsFixed(0)}$deg',
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
          ],
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

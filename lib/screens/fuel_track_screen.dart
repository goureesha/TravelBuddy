import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/trip_service.dart';
import '../services/team_service.dart';

class FuelTrackScreen extends StatefulWidget {
  const FuelTrackScreen({super.key});

  @override
  State<FuelTrackScreen> createState() => _FuelTrackScreenState();
}

class _FuelTrackScreenState extends State<FuelTrackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedTeamId; // null = personal/solo mode
  String _selectedLabel = 'Personal';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════
  // MODE PICKER (Personal or Team)
  // ══════════════════════════════════
  void _pickMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select Mode', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            // Personal / Solo option
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF00BFA5),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              title: Text('Personal (Solo Ride)', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Track your own trips', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
              trailing: _selectedTeamId == null ? const Icon(Icons.check_circle, color: Color(0xFF00BFA5)) : null,
              onTap: () {
                setState(() { _selectedTeamId = null; _selectedLabel = 'Personal'; });
                Navigator.pop(ctx);
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            // Team options
            StreamBuilder<QuerySnapshot>(
              stream: TeamService.getMyTeams(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
                final teams = snapshot.data!.docs;
                if (teams.isEmpty) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: teams.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1A73E8),
                        child: Icon(Icons.group, color: Colors.white, size: 20),
                      ),
                      title: Text(data['name'] ?? '', style: GoogleFonts.inter(color: Colors.white)),
                      trailing: _selectedTeamId == doc.id ? const Icon(Icons.check_circle, color: Color(0xFF1A73E8)) : null,
                      onTap: () {
                        setState(() { _selectedTeamId = doc.id; _selectedLabel = data['name'] ?? 'Team'; });
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════
  // START TRIP DIALOG
  // ══════════════════════════════════
  void _showStartTripDialog() {
    final vehicleCtrl = TextEditingController();
    final fuelPriceCtrl = TextEditingController(text: '102');
    final odometerCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Start New Trip', style: GoogleFonts.inter(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(vehicleCtrl, 'Vehicle Name', Icons.directions_car_rounded),
              const SizedBox(height: 12),
              _dialogField(fuelPriceCtrl, 'Fuel Price (₹/L)', Icons.local_gas_station_rounded, isNumber: true),
              const SizedBox(height: 12),
              _dialogField(odometerCtrl, 'Start Odometer (km)', Icons.speed_rounded, isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (vehicleCtrl.text.trim().isEmpty) return;
              await TripService.startTrip(
                teamId: _selectedTeamId,
                vehicleName: vehicleCtrl.text,
                fuelPricePerLiter: double.tryParse(fuelPriceCtrl.text) ?? 102,
                startOdometer: double.tryParse(odometerCtrl.text) ?? 0,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Start Trip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ══════════════════════════════════
  // END TRIP DIALOG
  // ══════════════════════════════════
  void _showEndTripDialog(String tripId) {
    final odometerCtrl = TextEditingController();
    final fuelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('End Trip', style: GoogleFonts.inter(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(odometerCtrl, 'End Odometer (km)', Icons.speed_rounded, isNumber: true),
              const SizedBox(height: 12),
              _dialogField(fuelCtrl, 'Total Fuel Used (L)', Icons.local_gas_station_rounded, isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await TripService.endTrip(
                teamId: _selectedTeamId,
                tripId: tripId,
                endOdometer: double.tryParse(odometerCtrl.text) ?? 0,
                fuelUsedLiters: double.tryParse(fuelCtrl.text) ?? 0,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('End Trip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  // ADD FUEL LOG
  // ══════════════════════════════════
  void _showAddFuelDialog(String tripId) {
    final litersCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '102');
    final stationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Fuel', style: GoogleFonts.inter(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(litersCtrl, 'Liters', Icons.water_drop_rounded, isNumber: true),
              const SizedBox(height: 12),
              _dialogField(priceCtrl, 'Price per Liter (₹)', Icons.currency_rupee_rounded, isNumber: true),
              const SizedBox(height: 12),
              _dialogField(stationCtrl, 'Station Name (optional)', Icons.location_on_rounded),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6D00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (litersCtrl.text.isEmpty) return;
              await TripService.addFuelLog(
                teamId: _selectedTeamId,
                tripId: tripId,
                liters: double.tryParse(litersCtrl.text) ?? 0,
                costPerLiter: double.tryParse(priceCtrl.text) ?? 102,
                stationName: stationCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Add Fuel', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  // BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Fuel & Trips', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _pickMode,
            icon: Icon(
              _selectedTeamId == null ? Icons.person_rounded : Icons.group_rounded,
              size: 18,
              color: const Color(0xFF00BFA5),
            ),
            label: Text(
              _selectedLabel,
              style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 13),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BFA5),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Active Trips', icon: Icon(Icons.play_circle_rounded, size: 20)),
            Tab(text: 'History', icon: Icon(Icons.history_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTrips(),
          _buildTripHistory(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStartTripDialog,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.add_road_rounded, color: Colors.white),
        label: Text('New Trip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ══════════════════════════════════
  // ACTIVE TRIPS TAB
  // ══════════════════════════════════
  Widget _buildActiveTrips() {
    return StreamBuilder<QuerySnapshot>(
      stream: TripService.getActiveTrips(_selectedTeamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final trips = snapshot.data?.docs ?? [];
        if (trips.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_car_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                const SizedBox(height: 12),
                Text('No active trips', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Tap "New Trip" to start tracking', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final doc = trips[index];
            final data = doc.data() as Map<String, dynamic>;
            return _activeTripCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _activeTripCard(String tripId, Map<String, dynamic> data) {
    final vehicle = data['vehicleName'] ?? 'Vehicle';
    final user = data['userName'] ?? '';
    final fuelLogs = (data['fuelLogs'] as List<dynamic>?) ?? [];
    final totalFuelLogged = fuelLogs.fold<double>(0, (sum, log) => sum + ((log['liters'] as num?)?.toDouble() ?? 0));
    final totalFuelCost = fuelLogs.fold<double>(0, (sum, log) => sum + ((log['totalCost'] as num?)?.toDouble() ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2128), Color(0xFF161B22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car_rounded, color: Color(0xFF00BFA5), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('by $user', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00BFA5), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Active', style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _statChip(Icons.local_gas_station_rounded, '${totalFuelLogged.toStringAsFixed(1)} L', 'Fuel'),
              const SizedBox(width: 12),
              _statChip(Icons.currency_rupee_rounded, '₹${totalFuelCost.toStringAsFixed(0)}', 'Cost'),
              const SizedBox(width: 12),
              _statChip(Icons.receipt_long_rounded, '${fuelLogs.length}', 'Stops'),
            ],
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddFuelDialog(tripId),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Add Fuel', style: GoogleFonts.inter(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6D00),
                    side: BorderSide(color: const Color(0xFFFF6D00).withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showEndTripDialog(tripId),
                  icon: const Icon(Icons.stop_rounded, size: 18, color: Colors.white),
                  label: Text('End Trip', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white38, size: 16),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  // TRIP HISTORY TAB
  // ══════════════════════════════════
  Widget _buildTripHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: TripService.getTripHistory(_selectedTeamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allTrips = snapshot.data?.docs ?? [];
        final completed = allTrips.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed').toList();
        if (completed.isEmpty) {
          return Center(
            child: Text('No completed trips yet', style: GoogleFonts.inter(color: Colors.white38)),
          );
        }

        // Calculate totals
        double totalDist = 0, totalFuel = 0, totalCost = 0;
        for (final doc in completed) {
          final d = doc.data() as Map<String, dynamic>;
          totalDist += (d['totalDistanceKm'] as num?)?.toDouble() ?? 0;
          totalFuel += (d['fuelUsedLiters'] as num?)?.toDouble() ?? 0;
          totalCost += (d['totalCost'] as num?)?.toDouble() ?? 0;
        }
        final avgEff = totalFuel > 0 ? totalDist / totalFuel : 0.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Trip Summary', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryItem('${totalDist.toStringAsFixed(0)} km', 'Distance'),
                      _summaryItem('${totalFuel.toStringAsFixed(1)} L', 'Fuel'),
                      _summaryItem('₹${totalCost.toStringAsFixed(0)}', 'Cost'),
                      _summaryItem('${avgEff.toStringAsFixed(1)} km/L', 'Efficiency'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trip list
            ...completed.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final dist = (data['totalDistanceKm'] as num?)?.toDouble() ?? 0;
              final fuel = (data['fuelUsedLiters'] as num?)?.toDouble() ?? 0;
              final cost = (data['totalCost'] as num?)?.toDouble() ?? 0;
              final eff = fuel > 0 ? dist / fuel : 0.0;
              final completedAt = data['completedAt'] as Timestamp?;
              final dateStr = completedAt != null
                  ? DateFormat('dd MMM yy').format(completedAt.toDate())
                  : '—';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_car, color: Color(0xFF1A73E8), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['vehicleName'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                          Text('$dateStr · ${dist.toStringAsFixed(0)} km · ${eff.toStringAsFixed(1)} km/L',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('₹${cost.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(color: const Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

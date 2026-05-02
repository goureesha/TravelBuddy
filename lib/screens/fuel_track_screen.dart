import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/fuel_service.dart';
import '../services/team_service.dart';
import '../widgets/notification_bell.dart';

class FuelTrackScreen extends StatefulWidget {
  const FuelTrackScreen({super.key});

  @override
  State<FuelTrackScreen> createState() => _FuelTrackScreenState();
}

class _FuelTrackScreenState extends State<FuelTrackScreen> {
  String? _selectedTeamId;
  String _selectedLabel = 'Personal';

  // ══════════════════════════════════
  // MODE PICKER
  // ══════════════════════════════════
  void _pickMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Mode',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF00BFA5),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            title: Text('Personal', style: GoogleFonts.inter(color: Colors.white)),
            subtitle: Text('Track your own fuel', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
            trailing: _selectedTeamId == null ? const Icon(Icons.check_circle, color: Color(0xFF00BFA5)) : null,
            onTap: () {
              setState(() { _selectedTeamId = null; _selectedLabel = 'Personal'; });
              Navigator.pop(ctx);
            },
          ),
          const Divider(color: Colors.white12, height: 1),
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
      ),
    );
  }

  // ══════════════════════════════════
  // ADD FUEL LOG DIALOG
  // ══════════════════════════════════
  void _showAddFuelDialog() {
    final odometerCtrl = TextEditingController();
    final litersCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '102');
    final totalCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool autoCalcTotal = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          void _recalcTotal() {
            if (!autoCalcTotal) return;
            final liters = double.tryParse(litersCtrl.text) ?? 0;
            final price = double.tryParse(priceCtrl.text) ?? 0;
            if (liters > 0 && price > 0) {
              totalCtrl.text = (liters * price).toStringAsFixed(0);
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1C2128),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFF00BFA5), size: 20),
                ),
                const SizedBox(width: 10),
                Text('Add Fuel Log', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(odometerCtrl, 'Odometer Reading (km)', Icons.speed_rounded, isNumber: true),
                  const SizedBox(height: 12),
                  _dialogField(litersCtrl, 'Fuel Filled (Liters)', Icons.water_drop_rounded,
                      isNumber: true, onChanged: (_) => setSt(_recalcTotal)),
                  const SizedBox(height: 12),
                  _dialogField(priceCtrl, 'Price per Liter (₹)', Icons.currency_rupee_rounded,
                      isNumber: true, onChanged: (_) => setSt(_recalcTotal)),
                  const SizedBox(height: 12),
                  _dialogField(totalCtrl, 'Total Amount (₹)', Icons.account_balance_wallet_rounded,
                      isNumber: true, onChanged: (_) => setSt(() => autoCalcTotal = false)),
                  const SizedBox(height: 12),
                  _dialogField(vehicleCtrl, 'Vehicle (optional)', Icons.directions_car_rounded),
                  const SizedBox(height: 12),
                  _dialogField(notesCtrl, 'Notes (optional)', Icons.note_rounded),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final odometer = double.tryParse(odometerCtrl.text);
                  final liters = double.tryParse(litersCtrl.text);
                  final price = double.tryParse(priceCtrl.text);
                  final total = double.tryParse(totalCtrl.text);

                  if (odometer == null || liters == null || price == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill odometer, liters, and price')),
                    );
                    return;
                  }

                  await FuelService.addFuelLog(
                    teamId: _selectedTeamId,
                    odometerKm: odometer,
                    liters: liters,
                    pricePerLiter: price,
                    totalAmount: total ?? (liters * price),
                    vehicleName: vehicleCtrl.text.trim().isNotEmpty ? vehicleCtrl.text.trim() : null,
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: GoogleFonts.inter(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        title: Text('Fuel Tracker', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 4),
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FuelService.getFuelLogs(_selectedTeamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_gas_station_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Text('No fuel logs yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Tap + to add your first fill-up', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                ],
              ),
            );
          }

          // Calculate stats from logs
          double totalLiters = 0, totalCost = 0, totalMileageSum = 0;
          int mileageCount = 0;
          double bestMileage = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalLiters += (data['liters'] as num?)?.toDouble() ?? 0;
            totalCost += (data['totalAmount'] as num?)?.toDouble() ?? 0;
            final m = (data['mileage'] as num?)?.toDouble();
            if (m != null && m > 0) {
              totalMileageSum += m;
              mileageCount++;
              if (m > bestMileage) bestMileage = m;
            }
          }
          final avgMileage = mileageCount > 0 ? totalMileageSum / mileageCount : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Stats Summary Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF1A73E8).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    // Avg mileage — big number
                    Text(
                      avgMileage > 0 ? avgMileage.toStringAsFixed(1) : '—',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1),
                    ),
                    Text('km/L avg mileage', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryItem('${totalLiters.toStringAsFixed(0)} L', 'Total Fuel'),
                        _summaryItem('₹${totalCost.toStringAsFixed(0)}', 'Total Cost'),
                        _summaryItem('${bestMileage.toStringAsFixed(1)}', 'Best km/L'),
                        _summaryItem('${docs.length}', 'Fill-ups'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Section title ──
              Text('Fuel History', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // ── Fuel Log Cards ──
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final odometer = (data['odometerKm'] as num?)?.toDouble() ?? 0;
                final liters = (data['liters'] as num?)?.toDouble() ?? 0;
                final price = (data['pricePerLiter'] as num?)?.toDouble() ?? 0;
                final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
                final mileage = (data['mileage'] as num?)?.toDouble();
                final distance = (data['distanceSinceLastFill'] as num?)?.toDouble();
                final vehicle = data['vehicleName'] as String? ?? '';
                final notes = data['notes'] as String? ?? '';
                final createdAt = data['createdAt'] as Timestamp?;
                final dateStr = createdAt != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
                    : '—';

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) => FuelService.deleteFuelLog(_selectedTeamId, doc.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: date + mileage badge
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 6),
                            Text(dateStr, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                            const Spacer(),
                            if (mileage != null && mileage > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _mileageColor(mileage).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _mileageColor(mileage).withOpacity(0.4)),
                                ),
                                child: Text(
                                  '${mileage.toStringAsFixed(1)} km/L',
                                  style: GoogleFonts.inter(
                                    color: _mileageColor(mileage),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('1st fill',
                                    style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Data grid
                        Row(
                          children: [
                            _logChip(Icons.speed_rounded, '${odometer.toStringAsFixed(0)} km', 'Odometer'),
                            const SizedBox(width: 10),
                            _logChip(Icons.water_drop_rounded, '${liters.toStringAsFixed(1)} L', 'Fuel'),
                            const SizedBox(width: 10),
                            _logChip(Icons.currency_rupee_rounded, '₹${price.toStringAsFixed(0)}/L', 'Price'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _logChip(Icons.account_balance_wallet_rounded, '₹${total.toStringAsFixed(0)}', 'Total'),
                            const SizedBox(width: 10),
                            if (distance != null && distance > 0)
                              _logChip(Icons.route_rounded, '${distance.toStringAsFixed(0)} km', 'Distance'),
                          ],
                        ),

                        // Vehicle name + notes
                        if (vehicle.isNotEmpty || notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          if (vehicle.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.directions_car_rounded, size: 14, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(width: 6),
                                Text(vehicle, style: GoogleFonts.inter(color: Colors.white30, fontSize: 12)),
                              ],
                            ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.note_rounded, size: 14, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(notes, style: GoogleFonts.inter(color: Colors.white30, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFuelDialog,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Fuel', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Helper: mileage color ──
  Color _mileageColor(double mileage) {
    if (mileage >= 20) return const Color(0xFF00BFA5); // Great
    if (mileage >= 15) return const Color(0xFF1A73E8); // Good
    if (mileage >= 10) return const Color(0xFFFF6D00); // Average
    return const Color(0xFFE53935); // Poor
  }

  Widget _logChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white30, size: 14),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(label, style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

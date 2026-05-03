import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _maintRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('maintenance');

  static const _presets = [
    _Preset('Engine Oil Change', Icons.oil_barrel_rounded, 5000, 180, Color(0xFFFF6D00)),
    _Preset('Air Filter', Icons.air_rounded, 15000, 365, Color(0xFF1A73E8)),
    _Preset('Tyre Rotation', Icons.tire_repair_rounded, 10000, 180, Color(0xFF43A047)),
    _Preset('Brake Pads Check', Icons.do_not_step_rounded, 20000, 365, Color(0xFFE53935)),
    _Preset('Coolant Top-up', Icons.thermostat_rounded, 30000, 365, Color(0xFF00ACC1)),
    _Preset('Battery Check', Icons.battery_alert_rounded, 25000, 365, Color(0xFF8E24AA)),
    _Preset('Full Service', Icons.build_circle_rounded, 10000, 180, Color(0xFFFF8F00)),
    _Preset('Wheel Alignment', Icons.straighten_rounded, 10000, 180, Color(0xFF5C6BC0)),
    _Preset('Wiper Blades', Icons.water_drop_rounded, 20000, 365, Color(0xFF00897B)),
    _Preset('AC Service', Icons.ac_unit_rounded, 20000, 365, Color(0xFF29B6F6)),
  ];

  Future<void> _addReminder() async {
    String selectedPreset = 'Engine Oil Change';
    final kmCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    DateTime? lastDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final preset = _presets.firstWhere((p) => p.name == selectedPreset);
          return AlertDialog(
            backgroundColor: const Color(0xFF1C2128),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Add Reminder', style: GoogleFonts.inter(color: Colors.white)),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Preset selector
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: _presets.map((p) {
                  final sel = p.name == selectedPreset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(p.icon, size: 14, color: sel ? Colors.white : p.color),
                      label: Text(p.name, style: GoogleFonts.inter(fontSize: 10, color: sel ? Colors.white : Colors.white54)),
                      selected: sel, selectedColor: p.color,
                      backgroundColor: const Color(0xFF0D1117),
                      onSelected: (_) => setS(() => selectedPreset = p.name),
                    ),
                  );
                }).toList()),
              ),
              const SizedBox(height: 12),
              // Info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: preset.color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(preset.icon, color: preset.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Every ${preset.kmInterval} km or ${preset.dayInterval} days',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11))),
                ]),
              ),
              const SizedBox(height: 12),
              TextField(controller: kmCtrl, keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _deco('Current odometer (km)')),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx, initialDate: DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setS(() {
                      lastDate = picked;
                      dateCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
                    });
                  }
                },
                child: AbsorbPointer(
                  child: TextField(controller: dateCtrl,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: _deco('Last service date (tap to pick)')),
                ),
              ),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: preset.color),
                onPressed: () async {
                  final km = double.tryParse(kmCtrl.text) ?? 0;
                  if (km <= 0 || lastDate == null) return;
                  await _maintRef.add({
                    'name': selectedPreset,
                    'lastKm': km,
                    'lastDate': Timestamp.fromDate(lastDate!),
                    'kmInterval': preset.kmInterval,
                    'dayInterval': preset.dayInterval,
                    'done': false,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white24),
    filled: true, fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );

  String _statusText(Map<String, dynamic> d) {
    final lastKm = (d['lastKm'] as num?)?.toDouble() ?? 0;
    final kmInt = (d['kmInterval'] as num?)?.toInt() ?? 5000;
    final lastDate = (d['lastDate'] as Timestamp?)?.toDate();
    final dayInt = (d['dayInterval'] as num?)?.toInt() ?? 180;

    final daysElapsed = lastDate != null ? DateTime.now().difference(lastDate).inDays : 0;
    final daysPct = daysElapsed / dayInt;

    if (daysPct >= 1.0) return 'OVERDUE by ${daysElapsed - dayInt} days';
    if (daysPct >= 0.8) return 'Due soon (${dayInt - daysElapsed} days left)';
    return '${dayInt - daysElapsed} days remaining';
  }

  Color _statusColor(Map<String, dynamic> d) {
    final lastDate = (d['lastDate'] as Timestamp?)?.toDate();
    final dayInt = (d['dayInterval'] as num?)?.toInt() ?? 180;
    if (lastDate == null) return Colors.white38;
    final pct = DateTime.now().difference(lastDate).inDays / dayInt;
    if (pct >= 1.0) return Colors.redAccent;
    if (pct >= 0.8) return Colors.orange;
    return const Color(0xFF00BFA5);
  }

  double _progress(Map<String, dynamic> d) {
    final lastDate = (d['lastDate'] as Timestamp?)?.toDate();
    final dayInt = (d['dayInterval'] as num?)?.toInt() ?? 180;
    if (lastDate == null) return 0;
    return (DateTime.now().difference(lastDate).inDays / dayInt).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Maintenance', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _maintRef.orderBy('createdAt', descending: false).snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.build_circle_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text('No reminders yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
              Text('Track vehicle service schedules', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
            ]));
          }

          // Sort: overdue first
          final sorted = docs.toList()..sort((a, b) {
            final ap = _progress(a.data() as Map<String, dynamic>);
            final bp = _progress(b.data() as Map<String, dynamic>);
            return bp.compareTo(ap);
          });

          final overdue = sorted.where((d) => _progress(d.data() as Map<String, dynamic>) >= 1.0).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (overdue > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 10),
                    Text('$overdue service${overdue > 1 ? 's' : ''} overdue!',
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ...sorted.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = d['name'] as String? ?? '';
                final preset = _presets.where((p) => p.name == name).firstOrNull;
                final color = preset?.color ?? Colors.white38;
                final icon = preset?.icon ?? Icons.build_rounded;
                final pct = _progress(d);

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                  ),
                  onDismissed: (_) => doc.reference.delete(),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: pct >= 1.0 ? Colors.redAccent.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(_statusText(d), style: GoogleFonts.inter(color: _statusColor(d), fontSize: 11, fontWeight: FontWeight.w600)),
                        ])),
                        // Mark done
                        IconButton(
                          icon: Icon(Icons.check_circle_rounded, color: pct >= 0.8 ? const Color(0xFF00BFA5) : Colors.white24, size: 22),
                          onPressed: () async {
                            await doc.reference.update({
                              'lastDate': Timestamp.now(),
                              'lastKm': (d['lastKm'] as num? ?? 0).toDouble() + (d['kmInterval'] as num? ?? 5000).toDouble(),
                            });
                          },
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.white.withOpacity(0.04),
                          valueColor: AlwaysStoppedAnimation(_statusColor(d)),
                          minHeight: 5,
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        backgroundColor: const Color(0xFFFF6D00),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _Preset {
  final String name;
  final IconData icon;
  final int kmInterval, dayInterval;
  final Color color;
  const _Preset(this.name, this.icon, this.kmInterval, this.dayInterval, this.color);
}

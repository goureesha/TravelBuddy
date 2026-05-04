import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class TollCalculatorScreen extends StatefulWidget {
  const TollCalculatorScreen({super.key});
  @override
  State<TollCalculatorScreen> createState() => _TollCalculatorScreenState();
}

class _TollCalculatorScreenState extends State<TollCalculatorScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _tollRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('toll_logs');

  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _vehicleType = 'Car';
  bool _returnTrip = false;

  static const _vehicleTypes = ['Car', 'SUV', 'Bus', 'Truck', 'Two-Wheeler'];
  static const _vehicleIcons = {
    'Car': Icons.directions_car_rounded,
    'SUV': Icons.directions_car_filled_rounded,
    'Bus': Icons.directions_bus_rounded,
    'Truck': Icons.local_shipping_rounded,
    'Two-Wheeler': Icons.two_wheeler_rounded,
  };

  Future<void> _saveToll() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final amt = double.tryParse(_amtCtrl.text) ?? 0;
    if (amt <= 0) return;

    await _tollRef.add({
      'name': _nameCtrl.text.trim(),
      'amount': _returnTrip ? amt * 2 : amt,
      'singleAmount': amt,
      'vehicleType': _vehicleType,
      'returnTrip': _returnTrip,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _nameCtrl.clear();
    _amtCtrl.clear();
    setState(() => _returnTrip = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Toll saved!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00BFA5)),
      );
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _amtCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Tolls', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Input card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _nameCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Toll plaza name', hintStyle: GoogleFonts.inter(color: Colors.white24),
                  prefixIcon: const Icon(Icons.toll_rounded, color: Colors.white38, size: 20),
                  filled: true, fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amtCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Amount (₹)', hintStyle: GoogleFonts.inter(color: Colors.white24),
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Colors.white38, size: 20),
                  filled: true, fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              // Vehicle type
              SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: _vehicleTypes.map((v) {
                  final sel = v == _vehicleType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(_vehicleIcons[v], size: 14, color: sel ? Colors.white : Colors.white54),
                      label: Text(v, style: GoogleFonts.inter(fontSize: 11, color: sel ? Colors.white : Colors.white54)),
                      selected: sel, selectedColor: const Color(0xFF1A73E8),
                      backgroundColor: const Color(0xFF0D1117),
                      side: BorderSide(color: sel ? const Color(0xFF1A73E8) : Colors.white.withOpacity(0.08)),
                      onSelected: (_) => setState(() => _vehicleType = v),
                    ),
                  );
                }).toList()),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Checkbox(
                  value: _returnTrip,
                  onChanged: (v) => setState(() => _returnTrip = v ?? false),
                  activeColor: const Color(0xFF1A73E8),
                ),
                Text('Return trip (2x)', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saveToll,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          // Summary + History
          StreamBuilder<QuerySnapshot>(
            stream: _tollRef.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              double total = 0;
              for (final d in docs) {
                total += ((d.data() as Map)['amount'] as num?)?.toDouble() ?? 0;
              }

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6D00), Color(0xFFFF9100)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.toll_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total Tolls', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                      Text('₹${total.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    ]),
                    const Spacer(),
                    Text('${docs.length} tolls', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('History', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (docs.isEmpty)
                  Text('No tolls logged', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                ...docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                    ),
                    onDismissed: (_) => doc.reference.delete(),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(children: [
                        Icon(_vehicleIcons[d['vehicleType']] ?? Icons.directions_car_rounded, color: Colors.white38, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${d['vehicleType'] ?? ''}${d['returnTrip'] == true ? ' • Return' : ''}',
                              style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
                        ])),
                        Text('₹${((d['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                            style: GoogleFonts.inter(color: const Color(0xFFFF6D00), fontSize: 15, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  );
                }),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

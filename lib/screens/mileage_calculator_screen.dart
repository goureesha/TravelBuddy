import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class MileageCalculatorScreen extends StatefulWidget {
  const MileageCalculatorScreen({super.key});
  @override
  State<MileageCalculatorScreen> createState() => _MileageCalculatorScreenState();
}

class _MileageCalculatorScreenState extends State<MileageCalculatorScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _logsRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('mileage_logs');

  final _distCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  double? _mileage;
  double? _costPerKm;

  void _calculate() {
    final dist = double.tryParse(_distCtrl.text) ?? 0;
    final fuel = double.tryParse(_fuelCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    if (dist > 0 && fuel > 0) {
      setState(() {
        _mileage = dist / fuel;
        _costPerKm = price > 0 ? (fuel * price) / dist : null;
      });
    }
  }

  Future<void> _saveLog() async {
    if (_mileage == null) return;
    await _logsRef.add({
      'distance': double.tryParse(_distCtrl.text) ?? 0,
      'fuel': double.tryParse(_fuelCtrl.text) ?? 0,
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'mileage': _mileage,
      'costPerKm': _costPerKm ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _distCtrl.clear();
    _fuelCtrl.clear();
    _priceCtrl.clear();
    setState(() { _mileage = null; _costPerKm = null; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00BFA5)),
      );
    }
  }

  String _rating(double kmpl) {
    if (kmpl >= 20) return 'Excellent 🌟';
    if (kmpl >= 15) return 'Good 👍';
    if (kmpl >= 10) return 'Average 😐';
    return 'Poor 😟';
  }

  Color _ratingColor(double kmpl) {
    if (kmpl >= 20) return const Color(0xFF00BFA5);
    if (kmpl >= 15) return const Color(0xFF1A73E8);
    if (kmpl >= 10) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  void dispose() { _distCtrl.dispose(); _fuelCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Mileage', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Result
          if (_mileage != null)
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_ratingColor(_mileage!), _ratingColor(_mileage!).withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _ratingColor(_mileage!).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(children: [
                Text('${_mileage!.toStringAsFixed(1)} km/L', style: GoogleFonts.inter(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                Text(_rating(_mileage!), style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                if (_costPerKm != null) ...[
                  const SizedBox(height: 8),
                  Text('₹${_costPerKm!.toStringAsFixed(1)} per km', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                ],
              ]),
            ),
          // Inputs
          _inputField(_distCtrl, 'Distance (km)', Icons.straighten_rounded),
          const SizedBox(height: 10),
          _inputField(_fuelCtrl, 'Fuel used (litres)', Icons.local_gas_station_rounded),
          const SizedBox(height: 10),
          _inputField(_priceCtrl, 'Fuel price per litre (₹)', Icons.currency_rupee_rounded),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text('Calculate', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            if (_mileage != null) ...[
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saveLog,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          const SizedBox(height: 24),
          Text('History', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _logsRef.orderBy('createdAt', descending: true).limit(20).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return Text('No logs yet', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13));
              return Column(children: docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final m = (d['mileage'] as num?)?.toDouble() ?? 0;
                final dist = (d['distance'] as num?)?.toDouble() ?? 0;
                final fuel = (d['fuel'] as num?)?.toDouble() ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _ratingColor(m).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('⛽', style: const TextStyle(fontSize: 16))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${m.toStringAsFixed(1)} km/L', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('${dist.toStringAsFixed(0)} km • ${fuel.toStringAsFixed(1)} L', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _ratingColor(m).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(_rating(m).split(' ')[0], style: GoogleFonts.inter(color: _ratingColor(m), fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                );
              }).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true, fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      onChanged: (_) => _calculate(),
    );
  }
}

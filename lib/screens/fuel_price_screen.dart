import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class FuelPriceScreen extends StatefulWidget {
  const FuelPriceScreen({super.key});
  @override
  State<FuelPriceScreen> createState() => _FuelPriceScreenState();
}

class _FuelPriceScreenState extends State<FuelPriceScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _priceRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('fuel_prices');

  String _fuelType = 'Petrol';

  // Latest average prices by state (manually updated reference data)
  static const _statePrices = {
    'Petrol': {
      'Delhi': 94.72, 'Mumbai': 103.44, 'Bangalore': 101.94, 'Chennai': 100.76,
      'Kolkata': 103.94, 'Hyderabad': 107.41, 'Pune': 103.96, 'Ahmedabad': 94.38,
      'Jaipur': 104.88, 'Lucknow': 94.57, 'Chandigarh': 96.20, 'Goa': 97.34,
      'Bhopal': 108.65, 'Kochi': 107.71, 'Guwahati': 96.01,
    },
    'Diesel': {
      'Delhi': 87.62, 'Mumbai': 89.97, 'Bangalore': 87.89, 'Chennai': 92.13,
      'Kolkata': 90.76, 'Hyderabad': 95.65, 'Pune': 89.82, 'Ahmedabad': 88.40,
      'Jaipur': 90.36, 'Lucknow': 87.33, 'Chandigarh': 84.26, 'Goa': 88.56,
      'Bhopal': 93.56, 'Kochi': 96.43, 'Guwahati': 87.27,
    },
  };

  Future<void> _logPrice() async {
    final cityCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Fuel Price', style: GoogleFonts.inter(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: cityCtrl, style: GoogleFonts.inter(color: Colors.white),
            decoration: _deco('City/Location')),
          const SizedBox(height: 10),
          TextField(controller: priceCtrl, keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: Colors.white), decoration: _deco('Price per litre (₹)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (price <= 0 || cityCtrl.text.trim().isEmpty) return;
              await _priceRef.add({
                'city': cityCtrl.text.trim(),
                'price': price,
                'fuelType': _fuelType,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Log', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white24),
    filled: true, fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    final prices = _statePrices[_fuelType] ?? {};
    final sorted = prices.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final cheapest = sorted.isNotEmpty ? sorted.first : null;
    final costliest = sorted.isNotEmpty ? sorted.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Fuel Prices', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Fuel type toggle
          Row(children: [
            _toggle('Petrol', Icons.local_gas_station_rounded, const Color(0xFF1A73E8)),
            const SizedBox(width: 10),
            _toggle('Diesel', Icons.local_gas_station_rounded, const Color(0xFFFF6D00)),
          ]),
          const SizedBox(height: 16),
          // Stats row
          if (cheapest != null && costliest != null)
            Row(children: [
              Expanded(child: _statBox('Cheapest', '₹${cheapest.value}', cheapest.key, const Color(0xFF00BFA5))),
              const SizedBox(width: 10),
              Expanded(child: _statBox('Costliest', '₹${costliest.value}', costliest.key, const Color(0xFFE53935))),
            ]),
          const SizedBox(height: 16),
          Text('City Prices - $_fuelType', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...sorted.map((e) {
            final pct = (e.value - (sorted.first.value)) / ((sorted.last.value) - sorted.first.value + 0.01);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(children: [
                Row(children: [
                  Text('⛽', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.key, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('₹${e.value.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(color: pct < 0.3 ? const Color(0xFF00BFA5) : pct > 0.7 ? Colors.redAccent : Colors.white70,
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.05, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    valueColor: AlwaysStoppedAnimation(Color.lerp(const Color(0xFF00BFA5), Colors.redAccent, pct)!),
                    minHeight: 4,
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 20),
          // Personal logs
          Text('Your Logs', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _priceRef.orderBy('createdAt', descending: true).limit(10).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return Text('No personal logs yet', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12));
              return Column(children: docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(children: [
                    Text(d['city'] ?? '', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    const Spacer(),
                    Text('${d['fuelType']} • ₹${(d['price'] as num?)?.toStringAsFixed(2) ?? '0'}',
                        style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                );
              }).toList());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logPrice,
        backgroundColor: const Color(0xFF1A73E8),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _toggle(String label, IconData icon, Color color) {
    final sel = _fuelType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _fuelType = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : Colors.white.withOpacity(0.08)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: sel ? color : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(color: sel ? color : Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, String city, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(city, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
      ]),
    );
  }
}

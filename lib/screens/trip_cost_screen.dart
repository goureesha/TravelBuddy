import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_bell.dart';

class TripCostScreen extends StatefulWidget {
  const TripCostScreen({super.key});

  @override
  State<TripCostScreen> createState() => _TripCostScreenState();
}

class _TripCostScreenState extends State<TripCostScreen> {
  static final _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _costsRef =>
      _firestore.collection('users').doc(_uid).collection('trip_costs');

  final _categories = const [
    {'name': 'Fuel', 'icon': Icons.local_gas_station_rounded, 'color': Color(0xFFFF7043)},
    {'name': 'Food', 'icon': Icons.restaurant_rounded, 'color': Color(0xFF66BB6A)},
    {'name': 'Stay', 'icon': Icons.hotel_rounded, 'color': Color(0xFF42A5F5)},
    {'name': 'Toll', 'icon': Icons.toll_rounded, 'color': Color(0xFFAB47BC)},
    {'name': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Color(0xFF78909C)},
  ];

  void _showAddExpense() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = 'Fuel';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Expense', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 20),
                  hintText: '0',
                  hintStyle: GoogleFonts.inter(color: Colors.white12, fontSize: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _categories.map((cat) {
                  final isSelected = selectedCategory == cat['name'];
                  return ChoiceChip(
                    label: Text(cat['name'] as String, style: GoogleFonts.inter(fontSize: 12, color: isSelected ? Colors.white : Colors.white54)),
                    selected: isSelected,
                    selectedColor: (cat['color'] as Color).withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.06),
                    onSelected: (_) => setDialogState(() => selectedCategory = cat['name'] as String),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Note (optional)',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                await _costsRef.add({
                  'amount': amount,
                  'category': selectedCategory,
                  'note': noteCtrl.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Trip Costs', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _costsRef.orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          // Calculate total
          double total = 0;
          final Map<String, double> categoryTotals = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amt = (data['amount'] as num?)?.toDouble() ?? 0;
            final cat = data['category'] as String? ?? 'Other';
            total += amt;
            categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
          }

          return Column(
            children: [
              // Total card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF4FC3F7)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text('Total Spent', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('₹${NumberFormat('#,##0').format(total)}',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    if (categoryTotals.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: categoryTotals.entries.map((e) {
                          return Text('${e.key}: ₹${NumberFormat('#,##0').format(e.value)}',
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11));
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Expense list
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                            const SizedBox(height: 12),
                            Text('No expenses yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                          final category = data['category'] as String? ?? 'Other';
                          final note = data['note'] as String? ?? '';
                          final timestamp = data['timestamp'] as Timestamp?;
                          final timeStr = timestamp != null ? DateFormat('dd MMM, hh:mm a').format(timestamp.toDate()) : '';

                          final catInfo = _categories.firstWhere((c) => c['name'] == category, orElse: () => _categories.last);

                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                            ),
                            onDismissed: (_) => _costsRef.doc(doc.id).delete(),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (catInfo['color'] as Color).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(catInfo['icon'] as IconData, color: catInfo['color'] as Color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(category, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                        if (note.isNotEmpty)
                                          Text(note, style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                                        Text(timeStr, style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Text('₹${NumberFormat('#,##0').format(amount)}',
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpense,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Expense', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

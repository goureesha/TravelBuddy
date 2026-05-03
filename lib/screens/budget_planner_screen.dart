import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});
  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _budgetRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('budgets');

  static const _categoryConfig = {
    'Transport': {'icon': Icons.directions_car_rounded, 'color': 0xFF1A73E8},
    'Stay': {'icon': Icons.hotel_rounded, 'color': 0xFF8E24AA},
    'Food': {'icon': Icons.restaurant_rounded, 'color': 0xFFE53935},
    'Activities': {'icon': Icons.attractions_rounded, 'color': 0xFFFF6D00},
    'Shopping': {'icon': Icons.shopping_bag_rounded, 'color': 0xFF00ACC1},
    'Misc': {'icon': Icons.more_horiz_rounded, 'color': 0xFF78909C},
  };

  Future<void> _createBudget() async {
    final nameCtrl = TextEditingController();
    final totalCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Budget', style: GoogleFonts.inter(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: GoogleFonts.inter(color: Colors.white),
            decoration: _inputDeco('Trip name (e.g. Goa Trip)')),
          const SizedBox(height: 10),
          TextField(controller: totalCtrl, keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: _inputDeco('Total budget (₹)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final total = double.tryParse(totalCtrl.text) ?? 0;
              await _budgetRef.add({
                'name': nameCtrl.text.trim(),
                'total': total,
                'items': [],
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Create', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense(DocumentReference docRef, Map<String, dynamic> data) async {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String cat = 'Transport';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Expense', style: GoogleFonts.inter(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 6, runSpacing: 6, children: _categoryConfig.keys.map((c) {
              final sel = c == cat;
              final cfg = _categoryConfig[c]!;
              return ChoiceChip(
                avatar: Icon(cfg['icon'] as IconData, size: 14, color: sel ? Colors.white : Color(cfg['color'] as int)),
                label: Text(c, style: GoogleFonts.inter(fontSize: 11, color: sel ? Colors.white : Colors.white54)),
                selected: sel, selectedColor: Color(cfg['color'] as int),
                backgroundColor: const Color(0xFF161B22),
                onSelected: (_) => setS(() => cat = c),
              );
            }).toList()),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, style: GoogleFonts.inter(color: Colors.white),
              decoration: _inputDeco('Description')),
            const SizedBox(height: 8),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: Colors.white), decoration: _inputDeco('Amount (₹)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text) ?? 0;
                if (amt <= 0) return;
                final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
                items.add({'desc': descCtrl.text.trim(), 'amount': amt, 'category': cat});
                await docRef.update({'items': items});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.white24),
    filled: true, fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Budget Planner', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _budgetRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_wallet_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text('No budgets yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? '';
              final total = (data['total'] as num?)?.toDouble() ?? 0;
              final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
              final spent = items.fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
              final remaining = total - spent;
              final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

              // Category breakdown
              final catTotals = <String, double>{};
              for (final item in items) {
                final c = item['category'] as String? ?? 'Misc';
                catTotals[c] = (catTotals[c] ?? 0) + ((item['amount'] as num?)?.toDouble() ?? 0);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                    Text('₹${total.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation(remaining >= 0 ? const Color(0xFF00BFA5) : Colors.redAccent),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Spent: ₹${spent.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                    Text('Left: ₹${remaining.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(color: remaining >= 0 ? const Color(0xFF00BFA5) : Colors.redAccent,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                  if (catTotals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 4, children: catTotals.entries.map((e) {
                      final cfg = _categoryConfig[e.key];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(cfg?['color'] as int? ?? 0xFF78909C).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${e.key}: ₹${e.value.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(fontSize: 10, color: Color(cfg?['color'] as int? ?? 0xFF78909C), fontWeight: FontWeight.w600)),
                      );
                    }).toList()),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _addExpense(docs[i].reference, data),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Add Expense', style: GoogleFonts.inter(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A73E8),
                        side: BorderSide(color: const Color(0xFF1A73E8).withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createBudget,
        backgroundColor: const Color(0xFF1A73E8),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

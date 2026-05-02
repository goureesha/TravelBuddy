import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';
import '../services/team_service.dart';
import '../widgets/notification_bell.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String? _selectedTeamId; // null = personal/solo
  String _selectedLabel = 'Personal';

  void _pickMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Mode', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF9C27B0), child: Icon(Icons.person, color: Colors.white, size: 20)),
            title: Text('Personal', style: GoogleFonts.inter(color: Colors.white)),
            subtitle: Text('Track your own expenses', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
            trailing: _selectedTeamId == null ? const Icon(Icons.check_circle, color: Color(0xFF9C27B0)) : null,
            onTap: () { setState(() { _selectedTeamId = null; _selectedLabel = 'Personal'; }); Navigator.pop(ctx); },
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
                    leading: const CircleAvatar(backgroundColor: Color(0xFF1A73E8), child: Icon(Icons.group, color: Colors.white, size: 20)),
                    title: Text(data['name'] ?? '', style: GoogleFonts.inter(color: Colors.white)),
                    trailing: _selectedTeamId == doc.id ? const Icon(Icons.check_circle, color: Color(0xFF1A73E8)) : null,
                    onTap: () { setState(() { _selectedTeamId = doc.id; _selectedLabel = data['name'] ?? 'Team'; }); Navigator.pop(ctx); },
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

  void _showAddExpense() {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'food';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Expense', style: GoogleFonts.inter(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'What was it for?',
                    labelStyle: GoogleFonts.inter(color: Colors.white38),
                    prefixIcon: const Icon(Icons.receipt_rounded, color: Colors.white38, size: 20),
                    filled: true, fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    labelStyle: GoogleFonts.inter(color: Colors.white38),
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Colors.white38, size: 20),
                    filled: true, fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ExpenseService.categories.entries.map((e) {
                    final isSel = selectedCategory == e.key;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedCategory = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF9C27B0).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? const Color(0xFF9C27B0) : Colors.transparent),
                        ),
                        child: Text('${e.value} ${e.key}', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (descCtrl.text.trim().isEmpty || amountCtrl.text.isEmpty) return;
                await ExpenseService.addExpense(
                  teamId: _selectedTeamId,
                  description: descCtrl.text,
                  amount: double.tryParse(amountCtrl.text) ?? 0,
                  category: selectedCategory,
                );
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
        title: Text('Expenses', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _pickMode,
            icon: Icon(
              _selectedTeamId == null ? Icons.person_rounded : Icons.group_rounded,
              size: 18, color: const Color(0xFF9C27B0),
            ),
            label: Text(_selectedLabel, style: GoogleFonts.inter(color: const Color(0xFF9C27B0), fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
              stream: ExpenseService.getTeamExpenses(_selectedTeamId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                        const SizedBox(height: 12),
                        Text('No expenses yet', style: GoogleFonts.inter(color: Colors.white38)),
                      ],
                    ),
                  );
                }

                // Calculate total
                double total = 0, settled = 0;
                for (final doc in docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                  total += amt;
                  if (d['settled'] == true) settled += amt;
                }

                // Sort by time (newest first)
                docs.sort((a, b) {
                  final at = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (at == null || bt == null) return 0;
                  return bt.compareTo(at);
                });

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryItem('₹${total.toStringAsFixed(0)}', 'Total'),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _summaryItem('₹${settled.toStringAsFixed(0)}', 'Settled'),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _summaryItem('₹${(total - settled).toStringAsFixed(0)}', 'Pending'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final emoji = ExpenseService.categories[data['category'] ?? 'other'] ?? '📝';
                      final isSettled = data['settled'] == true;
                      final amt = (data['amount'] as num?)?.toDouble() ?? 0;
                      final createdAt = data['createdAt'] as Timestamp?;
                      final dateStr = createdAt != null ? DateFormat('dd MMM').format(createdAt.toDate()) : '';

                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => ExpenseService.deleteExpense(_selectedTeamId, doc.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSettled ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.06)),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
                            ),
                            title: Text(
                              data['description'] ?? '',
                              style: GoogleFonts.inter(
                                color: isSettled ? Colors.white38 : Colors.white,
                                fontWeight: FontWeight.w500,
                                decoration: isSettled ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              '${data['paidByName'] ?? ''} · $dateStr',
                              style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${amt.toStringAsFixed(0)}', style: GoogleFonts.inter(color: isSettled ? Colors.green : const Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => ExpenseService.toggleSettled(_selectedTeamId, doc.id, isSettled),
                                  child: Icon(
                                    isSettled ? Icons.check_circle_rounded : Icons.circle_outlined,
                                    color: isSettled ? Colors.green : Colors.white24,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpense,
        backgroundColor: const Color(0xFF9C27B0),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Expense', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

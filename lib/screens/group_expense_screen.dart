import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class GroupExpenseScreen extends StatefulWidget {
  const GroupExpenseScreen({super.key});

  @override
  State<GroupExpenseScreen> createState() => _GroupExpenseScreenState();
}

class _GroupExpenseScreenState extends State<GroupExpenseScreen> {
  static final _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _userName => FirebaseAuth.instance.currentUser?.displayName ?? 'You';

  CollectionReference get _groupsRef =>
      _firestore.collection('users').doc(_uid).collection('expense_groups');

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Group', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Group name (e.g. Goa Trip)',
                hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: membersCtrl,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Members (comma-separated)',
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final members = [_userName, ...membersCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)];
              await _groupsRef.add({
                'name': name,
                'members': members,
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

  void _openGroup(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _GroupDetailScreen(groupId: doc.id, groupData: data, uid: _uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Group Expenses', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _groupsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data?.docs ?? [];

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Text('No expense groups', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Create a group to split costs', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final doc = groups[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? '';
              final members = (data['members'] as List?)?.cast<String>() ?? [];

              return GestureDetector(
                onTap: () => _openGroup(doc),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.group_rounded, color: Color(0xFF1A73E8), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${members.length} members', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: Text('New Group', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> groupData;
  final String uid;

  const _GroupDetailScreen({required this.groupId, required this.groupData, required this.uid});

  @override
  State<_GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<_GroupDetailScreen> {
  CollectionReference get _expensesRef => FirebaseFirestore.instance
      .collection('users').doc(widget.uid).collection('expense_groups')
      .doc(widget.groupId).collection('expenses');

  List<String> get _members => (widget.groupData['members'] as List?)?.cast<String>() ?? [];
  String get _groupName => widget.groupData['name'] as String? ?? 'Group';

  Future<void> _addExpense() async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paidBy = _members.isNotEmpty ? _members.first : '';

    await showDialog(
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
                controller: descCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'What was it for?',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Amount (₹)',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.inter(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paidBy,
                dropdownColor: const Color(0xFF1C2128),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Paid by',
                  labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setDialogState(() => paidBy = v ?? paidBy),
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
                await _expensesRef.add({
                  'description': descCtrl.text.trim(),
                  'amount': amount,
                  'paidBy': paidBy,
                  'splitAmong': _members,
                  'createdAt': FieldValue.serverTimestamp(),
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

  Map<String, double> _calculateBalances(List<QueryDocumentSnapshot> expenses) {
    final balances = <String, double>{};
    for (final m in _members) {
      balances[m] = 0;
    }

    for (final doc in expenses) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final paidBy = data['paidBy'] as String? ?? '';
      final splitAmong = (data['splitAmong'] as List?)?.cast<String>() ?? _members;
      final share = amount / splitAmong.length;

      // Person who paid gets credited
      if (balances.containsKey(paidBy)) {
        balances[paidBy] = (balances[paidBy] ?? 0) + amount;
      }

      // Everyone owes their share
      for (final m in splitAmong) {
        if (balances.containsKey(m)) {
          balances[m] = (balances[m] ?? 0) - share;
        }
      }
    }
    return balances;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(_groupName, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _expensesRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          final expenses = snapshot.data?.docs ?? [];
          final balances = _calculateBalances(expenses);
          final totalSpent = expenses.fold<double>(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + ((data['amount'] as num?)?.toDouble() ?? 0);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total spent card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF4FC3F7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text('Total Spent', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('₹${totalSpent.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Split among ${_members.length} people',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Balances
              Text('Balances', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...balances.entries.map((e) {
                final isPositive = e.value > 0.5;
                final isNegative = e.value < -0.5;
                final color = isPositive ? const Color(0xFF00BFA5) : isNegative ? const Color(0xFFE53935) : Colors.white38;
                final label = isPositive ? 'gets back' : isNegative ? 'owes' : 'settled';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withOpacity(0.15),
                        child: Text(e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(e.key, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${e.value.abs().toStringAsFixed(0)}',
                              style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(label, style: GoogleFonts.inter(color: Colors.white30, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              // Expense list
              Text('Expenses', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (expenses.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No expenses yet', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                )),
              ...expenses.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final desc = data['description'] as String? ?? '';
                final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                final paidBy = data['paidBy'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(desc.isEmpty ? 'Expense' : desc, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('Paid by $paidBy', style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('₹${amount.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: const Color(0xFF00BFA5),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

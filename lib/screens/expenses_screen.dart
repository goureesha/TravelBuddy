import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';
import '../services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String? _activeTeamId;
  String? _activeTeamName;
  List<Map<String, dynamic>> _teams = [];

  static const _cats = ExpenseService.categories;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadTeams();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('teams')
        .where('members', arrayContains: uid)
        .get();
    if (!mounted) return;
    setState(() {
      _teams = snap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, 'name': data['name'] ?? 'Team'};
      }).toList();
    });
  }

  void _showAddExpense({bool isGroup = false}) {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String category = 'food';
    String? selectedTeamId = _activeTeamId ?? (_teams.isNotEmpty ? _teams.first['id'] : null);
    List<String> splitWithIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isGroup ? 'Split Expense' : 'Personal Expense',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descCtrl,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What did you spend on?',
                    hintStyle: GoogleFonts.inter(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.description_rounded, color: Colors.white24, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Amount
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.inter(color: Colors.white12, fontSize: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF00BFA5), size: 22),
                  ),
                ),
                const SizedBox(height: 14),

                // Category chips
                Text('Category', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _cats.entries.map((e) {
                  final selected = category == e.key;
                  return GestureDetector(
                    onTap: () => setSheetState(() => category = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF00BFA5).withOpacity(0.2) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? const Color(0xFF00BFA5) : Colors.transparent),
                      ),
                      child: Text('${e.value} ${e.key[0].toUpperCase()}${e.key.substring(1)}',
                          style: GoogleFonts.inter(
                            color: selected ? const Color(0xFF00BFA5) : Colors.white54,
                            fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList()),

                // Group: team selector + split
                if (isGroup) ...[
                  const SizedBox(height: 16),
                  Text('Team', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (_teams.isEmpty)
                    Text('No teams found — join or create a team first',
                        style: GoogleFonts.inter(color: Colors.white24, fontSize: 12))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: selectedTeamId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1C2128),
                        underline: const SizedBox(),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        items: _teams.map((t) => DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text(t['name'] as String),
                        )).toList(),
                        onChanged: (v) => setSheetState(() => selectedTeamId = v),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Show team members to split with
                  if (selectedTeamId != null)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('teams').doc(selectedTeamId).get(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const SizedBox();
                        final teamData = snap.data!.data() as Map<String, dynamic>? ?? {};
                        final members = List<String>.from(teamData['members'] ?? []);
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final others = members.where((m) => m != uid).toList();
                        if (others.isEmpty) {
                          return Text('No other members to split with',
                              style: GoogleFonts.inter(color: Colors.white24, fontSize: 12));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Split with', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 6),
                            ...others.map((memberId) {
                              final isSplit = splitWithIds.contains(memberId);
                              return GestureDetector(
                                onTap: () => setSheetState(() {
                                  if (isSplit) { splitWithIds.remove(memberId); }
                                  else { splitWithIds.add(memberId); }
                                }),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSplit
                                        ? const Color(0xFF1A73E8).withOpacity(0.15)
                                        : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isSplit
                                        ? const Color(0xFF1A73E8).withOpacity(0.4)
                                        : Colors.transparent),
                                  ),
                                  child: Row(children: [
                                    Icon(isSplit ? Icons.check_circle : Icons.circle_outlined,
                                        color: isSplit ? const Color(0xFF1A73E8) : Colors.white24, size: 20),
                                    const SizedBox(width: 10),
                                    // Show member ID (in real app, resolve to display name)
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                                      builder: (ctx, userSnap) {
                                        final name = (userSnap.data?.data() as Map<String, dynamic>?)?['displayName'] ?? memberId.substring(0, 8);
                                        return Text(name as String,
                                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13));
                                      },
                                    ),
                                  ]),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                ],

                const SizedBox(height: 20),
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final desc = descCtrl.text.trim();
                      final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
                      if (desc.isEmpty || amt <= 0) return;

                      final teamId = isGroup ? selectedTeamId : null;
                      await ExpenseService.addExpense(
                        teamId: teamId,
                        description: desc,
                        amount: amt,
                        category: category,
                        splitWith: isGroup ? splitWithIds : null,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text('Save Expense', style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )),
          );
        },
      ),
    );
  }

  Widget _buildExpenseList(String? teamId) {
    return StreamBuilder<QuerySnapshot>(
      stream: ExpenseService.getTeamExpenses(teamId),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_rounded, size: 56, color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 12),
              Text(teamId == null ? 'No personal expenses yet' : 'No group expenses yet',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
              Text('Tap + to add one', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
            ],
          ));
        }

        // Sort by createdAt desc
        docs.sort((a, b) {
          final aT = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bT = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          return (bT?.millisecondsSinceEpoch ?? 0).compareTo(aT?.millisecondsSinceEpoch ?? 0);
        });

        // Calculate total
        double total = 0;
        for (final d in docs) {
          total += ((d.data() as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0;
        }

        return Column(children: [
          // Total banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total Spent', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                Text('₹${total.toStringAsFixed(2)}', style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${docs.length} items', style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          // Balances (for group only)
          if (teamId != null) _buildBalances(docs),
          // Expense list
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final desc = data['description'] as String? ?? '';
              final amt = (data['amount'] as num?)?.toDouble() ?? 0;
              final cat = data['category'] as String? ?? 'other';
              final emoji = _cats[cat] ?? '📝';
              final settled = data['settled'] as bool? ?? false;
              final splitWith = List<String>.from(data['splitWith'] ?? []);
              final paidByName = data['paidByName'] as String? ?? '';
              final isSplit = splitWith.isNotEmpty;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                ),
                onDismissed: (_) => ExpenseService.deleteExpense(teamId, doc.id),
                child: GestureDetector(
                  onTap: () => ExpenseService.toggleSettled(teamId, doc.id, settled),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: settled
                          ? const Color(0xFF00BFA5).withOpacity(0.2)
                          : Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(children: [
                      // Category emoji
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: settled
                              ? const Color(0xFF00BFA5).withOpacity(0.1)
                              : const Color(0xFF1A73E8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(desc, style: GoogleFonts.inter(
                            color: settled ? Colors.white38 : Colors.white,
                            fontSize: 14, fontWeight: FontWeight.w600,
                            decoration: settled ? TextDecoration.lineThrough : null,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (isSplit) ...[
                              Icon(Icons.people_rounded, color: Colors.white24, size: 12),
                              const SizedBox(width: 4),
                              Text('Split ${splitWith.length + 1} ways',
                                  style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                              const SizedBox(width: 8),
                            ],
                            if (paidByName.isNotEmpty && teamId != null)
                              Text('by $paidByName',
                                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
                          ]),
                        ],
                      )),
                      // Amount
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₹${amt.toStringAsFixed(2)}', style: GoogleFonts.inter(
                          color: settled ? Colors.white30 : const Color(0xFF00BFA5),
                          fontSize: 16, fontWeight: FontWeight.bold,
                        )),
                        if (settled)
                          Text('Settled', style: GoogleFonts.inter(
                              color: const Color(0xFF00BFA5), fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          )),
        ]);
      },
    );
  }

  Widget _buildBalances(List<QueryDocumentSnapshot> docs) {
    final balances = ExpenseService.calculateBalances(docs);
    if (balances.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balances', style: GoogleFonts.inter(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...balances.entries.map((e) {
            final isPositive = e.value >= 0;
            // Check if key looks like a UID (long alphanumeric, no spaces)
            final isUid = e.key.length > 20 && !e.key.contains(' ');
            
            Widget nameWidget;
            if (isUid) {
              // Resolve UID to display name
              nameWidget = FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(e.key).get(),
                builder: (ctx, snap) {
                  final name = (snap.data?.data() as Map<String, dynamic>?)?['displayName'] 
                      ?? e.key.substring(0, 8);
                  return Text(name as String, 
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                      overflow: TextOverflow.ellipsis);
                },
              );
            } else {
              nameWidget = Text(e.key, 
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                  overflow: TextOverflow.ellipsis);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: isPositive ? const Color(0xFF00BFA5) : Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: nameWidget),
                Text('${isPositive ? '+' : ''}₹${e.value.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: isPositive ? const Color(0xFF00BFA5) : Colors.redAccent,
                      fontSize: 13, fontWeight: FontWeight.bold,
                    )),
              ]),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Expenses', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF00BFA5),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Personal'),
            Tab(text: 'Group Split'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Personal expenses
          _buildExpenseList(null),
          // Group expenses — show team picker if no active team
          _activeTeamId != null
              ? _buildExpenseList(_activeTeamId)
              : _buildTeamPicker(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00BFA5),
        onPressed: () => _showAddExpense(isGroup: _tabCtrl.index == 1),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildTeamPicker() {
    if (_teams.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded, size: 56, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 12),
          Text('No teams found', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
          Text('Join or create a team to split expenses',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        return GestureDetector(
          onTap: () => setState(() {
            _activeTeamId = team['id'] as String;
            _activeTeamName = team['name'] as String;
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF1A73E8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team['name'] as String, style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Tap to view group expenses', style: GoogleFonts.inter(
                      color: Colors.white30, fontSize: 12)),
                ],
              )),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ]),
          ),
        );
      },
    );
  }
}

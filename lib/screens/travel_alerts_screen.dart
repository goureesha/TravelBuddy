import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class TravelAlertsScreen extends StatefulWidget {
  const TravelAlertsScreen({super.key});
  @override
  State<TravelAlertsScreen> createState() => _TravelAlertsScreenState();
}

class _TravelAlertsScreenState extends State<TravelAlertsScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _alertsRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('travel_alerts');

  static const _defaultAlerts = [
    _AlertTemplate('Passport Expiry', 'Check passport validity (6+ months)', Icons.badge_rounded, 'document', Color(0xFFE53935)),
    _AlertTemplate('Visa Required', 'Verify visa requirements for destination', Icons.article_rounded, 'document', Color(0xFFFF6D00)),
    _AlertTemplate('Travel Insurance', 'Get travel insurance before departure', Icons.health_and_safety_rounded, 'insurance', Color(0xFF1E88E5)),
    _AlertTemplate('Vaccination', 'Check required vaccinations', Icons.vaccines_rounded, 'health', Color(0xFF43A047)),
    _AlertTemplate('Local SIM / eSIM', 'Research mobile data options', Icons.sim_card_rounded, 'connectivity', Color(0xFF8E24AA)),
    _AlertTemplate('Embassy Info', 'Note nearest embassy/consulate', Icons.account_balance_rounded, 'safety', Color(0xFF00ACC1)),
    _AlertTemplate('Currency Exchange', 'Get local currency before trip', Icons.currency_exchange_rounded, 'finance', Color(0xFFFFB300)),
    _AlertTemplate('Weather Check', 'Monitor destination weather forecast', Icons.cloud_rounded, 'weather', Color(0xFF5C6BC0)),
  ];

  Future<void> _addAlert() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Alert', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Quick templates
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: _defaultAlerts.map((t) =>
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: Icon(t.icon, size: 14, color: t.color),
                  label: Text(t.title, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
                  backgroundColor: const Color(0xFF161B22),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                  onPressed: () {
                    titleCtrl.text = t.title;
                    descCtrl.text = t.desc;
                  },
                ),
              ),
            ).toList()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleCtrl,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Alert title', hintStyle: GoogleFonts.inter(color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Description', hintStyle: GoogleFonts.inter(color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await _alertsRef.add({
                'title': titleCtrl.text.trim(),
                'desc': descCtrl.text.trim(),
                'resolved': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Travel Alerts', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _alertsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final active = docs.where((d) => (d.data() as Map)['resolved'] != true).toList();
          final resolved = docs.where((d) => (d.data() as Map)['resolved'] == true).toList();

          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text('No alerts yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
              Text('Add travel reminders & safety checks', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
            ]));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                Text('Active (${active.length})', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...active.map((doc) => _alertCard(doc, false)),
              ],
              if (resolved.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Resolved (${resolved.length})', style: GoogleFonts.inter(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...resolved.map((doc) => _alertCard(doc, true)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAlert,
        backgroundColor: const Color(0xFFE53935),
        child: const Icon(Icons.add_alert_rounded, color: Colors.white),
      ),
    );
  }

  Widget _alertCard(QueryDocumentSnapshot doc, bool isResolved) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? '';
    final desc = data['desc'] as String? ?? '';

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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isResolved ? const Color(0xFF161B22) : const Color(0xFFE53935).withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isResolved ? Colors.white.withOpacity(0.06) : const Color(0xFFE53935).withOpacity(0.2)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => doc.reference.update({'resolved': !isResolved}),
            child: Icon(
              isResolved ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: isResolved ? Colors.green : const Color(0xFFE53935), size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(color: isResolved ? Colors.white38 : Colors.white,
                fontSize: 14, fontWeight: FontWeight.w600,
                decoration: isResolved ? TextDecoration.lineThrough : null)),
            if (desc.isNotEmpty)
              Text(desc, style: GoogleFonts.inter(color: Colors.white24, fontSize: 12), maxLines: 2),
          ])),
        ]),
      ),
    );
  }
}

class _AlertTemplate {
  final String title, desc;
  final IconData icon;
  final String category;
  final Color color;
  const _AlertTemplate(this.title, this.desc, this.icon, this.category, this.color);
}

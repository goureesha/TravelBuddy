import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class TripTemplatesScreen extends StatefulWidget {
  const TripTemplatesScreen({super.key});
  @override
  State<TripTemplatesScreen> createState() => _TripTemplatesScreenState();
}

class _TripTemplatesScreenState extends State<TripTemplatesScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _plansRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('planned_trips');

  String _filter = 'All';

  static final _templates = <_Template>[
    // Beach
    _Template('Goa Beach Escape', '3 Days', 'Beach', '🏖️', const Color(0xFF00ACC1), 12000,
        ['Day 1: Arrive → Calangute Beach → Titos Lane nightlife',
         'Day 2: Old Goa churches → Dudhsagar Falls → spice plantation',
         'Day 3: Palolem Beach → water sports → depart'],
        ['Sunscreen SPF 50+', 'Swimwear', 'Flip flops', 'Beach towel', 'Waterproof phone pouch', 'Light cotton clothes']),
    _Template('Andaman Paradise', '5 Days', 'Beach', '🏝️', const Color(0xFF0097A7), 25000,
        ['Day 1: Port Blair → Cellular Jail → Light & Sound show',
         'Day 2: Ross Island → North Bay (snorkeling)',
         'Day 3: Ferry to Havelock → Radhanagar Beach sunset',
         'Day 4: Scuba diving → Elephant Beach kayaking',
         'Day 5: Kalapathar Beach → depart'],
        ['Snorkeling gear (or rent)', 'Reef-safe sunscreen', 'Waterproof bag', 'Anti-seasick medicine', 'Cash (limited ATMs)']),
    // Mountain
    _Template('Manali Adventure', '5 Days', 'Mountain', '🏔️', const Color(0xFF5C6BC0), 15000,
        ['Day 1: Arrive Manali → Mall Road → Hadimba Temple',
         'Day 2: Solang Valley → paragliding → zorbing',
         'Day 3: Rohtang Pass day trip (permit needed)',
         'Day 4: Old Manali cafes → Jogini Waterfall trek',
         'Day 5: Naggar Castle → depart'],
        ['Warm jacket', 'Thermal innerwear', 'Trekking shoes', 'Gloves & cap', 'Altitude sickness pills', 'Power bank']),
    _Template('Ladakh Road Trip', '7 Days', 'Mountain', '🗻', const Color(0xFF3949AB), 35000,
        ['Day 1: Fly to Leh → acclimatize → Shanti Stupa',
         'Day 2: Leh Palace → Thiksey Monastery → Hemis',
         'Day 3: Nubra Valley via Khardung La',
         'Day 4: Diskit → Hunder sand dunes → camel ride',
         'Day 5: Pangong Lake (camp overnight)',
         'Day 6: Return to Leh via Chang La',
         'Day 7: Local shopping → depart'],
        ['Warm layers (sub-zero)', 'Diamox tablets', 'Sunglasses UV400', 'Moisturizer & lip balm', 'Spare fuel cans', 'Copies of permits']),
    // Cultural
    _Template('Rajasthan Heritage', '6 Days', 'Cultural', '🏰', const Color(0xFFFF6D00), 20000,
        ['Day 1: Jaipur → Amber Fort → Hawa Mahal → bazaar',
         'Day 2: Jaipur → Jantar Mantar → City Palace',
         'Day 3: Drive to Jodhpur → Mehrangarh Fort',
         'Day 4: Jodhpur blue city walk → drive to Jaisalmer',
         'Day 5: Jaisalmer Fort → Patwon Haveli → desert safari',
         'Day 6: Sam sand dunes sunrise → depart'],
        ['Comfortable walking shoes', 'Scarf/dupatta (temple visits)', 'Sunscreen', 'Water bottle', 'Camera with spare battery']),
    _Template('Kerala Backwaters', '4 Days', 'Cultural', '🛶', const Color(0xFF2E7D32), 18000,
        ['Day 1: Kochi → Fort Kochi → Chinese fishing nets',
         'Day 2: Drive to Munnar → tea plantations',
         'Day 3: Alleppey houseboat → backwater cruise',
         'Day 4: Marari Beach → depart from Kochi'],
        ['Mosquito repellent', 'Rain jacket', 'Light cotton clothes', 'Binoculars', 'Seasickness pills']),
    // Weekend
    _Template('Coorg Weekend', '2 Days', 'Weekend', '☕', const Color(0xFF43A047), 8000,
        ['Day 1: Arrive → Abbey Falls → Raja Seat sunset',
         'Day 2: Coffee plantation tour → Dubare elephant camp → depart'],
        ['Light jacket', 'Trekking shoes', 'Camera', 'Mosquito repellent']),
    _Template('Pondicherry Getaway', '2 Days', 'Weekend', '🇫🇷', const Color(0xFFE53935), 6000,
        ['Day 1: French Quarter walk → Promenade → Rock Beach → cafes',
         'Day 2: Auroville → Paradise Beach → depart'],
        ['Cycle rental money', 'Sunscreen', 'Comfortable shoes', 'Camera']),
    // Pilgrimage
    _Template('Varanasi Spiritual', '3 Days', 'Pilgrimage', '🙏', const Color(0xFFFF8F00), 10000,
        ['Day 1: Arrive → Dashashwamedh Ghat → Ganga Aarti',
         'Day 2: Morning boat ride → Kashi Vishwanath → Sarnath',
         'Day 3: Sunrise at ghats → Ramnagar Fort → depart'],
        ['Modest clothing', 'Comfortable sandals', 'Small towel', 'Offerings/flowers']),
    _Template('Tirupati Darshan', '2 Days', 'Pilgrimage', '🛕', const Color(0xFFEF6C00), 5000,
        ['Day 1: Arrive Tirupati → Tirumala temple darshan',
         'Day 2: Padmavathi temple → Sri Kalahasti → depart'],
        ['Dhoti/saree for temple', 'Comfortable footwear', 'ID proof', 'Booking confirmation']),
  ];

  static const _types = ['All', 'Beach', 'Mountain', 'Cultural', 'Weekend', 'Pilgrimage'];

  Future<void> _useTemplate(_Template t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: t.color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('${t.duration} • ${t.type}', style: GoogleFonts.inter(color: t.color, fontSize: 11, fontWeight: FontWeight.w600))),
              const Spacer(),
              Text('~₹${t.budget}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            ]),
            const SizedBox(height: 14),
            Text('Itinerary', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...t.itinerary.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ', style: GoogleFonts.inter(color: t.color, fontSize: 12)),
                Expanded(child: Text(d, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))),
              ]),
            )),
            const SizedBox(height: 10),
            Text('Packing List', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: t.packing.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
              child: Text(p, style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
            )).toList()),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Close', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Use Template', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _plansRef.add({
        'destination': t.name,
        'startDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'endDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 7 + int.parse(t.duration.split(' ')[0])))),
        'notes': t.itinerary.join('\n'),
        'budget': t.budget.toDouble(),
        'templateType': t.type,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.name} added to your plans!', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF00BFA5)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All' ? _templates : _templates.where((t) => t.type == _filter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Trip Templates', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: Column(children: [
        // Type filter
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _types.map((t) {
              final sel = t == _filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t, style: GoogleFonts.inter(fontSize: 12, color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
                  selected: sel, selectedColor: const Color(0xFF1A73E8),
                  backgroundColor: const Color(0xFF161B22),
                  side: BorderSide(color: sel ? const Color(0xFF1A73E8) : Colors.white.withOpacity(0.08)),
                  onSelected: (_) => setState(() => _filter = t),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final t = filtered[i];
              return GestureDetector(
                onTap: () => _useTemplate(t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.color.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: t.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text(t.emoji, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: t.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text(t.duration, style: GoogleFonts.inter(color: t.color, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Text(t.type, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('~₹${(t.budget / 1000).toStringAsFixed(0)}k', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('budget', style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Template {
  final String name, duration, type, emoji;
  final Color color;
  final int budget;
  final List<String> itinerary, packing;
  const _Template(this.name, this.duration, this.type, this.emoji, this.color, this.budget, this.itinerary, this.packing);
}

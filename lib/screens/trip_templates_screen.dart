import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';
import '../services/trip_plan_service.dart';
import 'live_map_screen.dart';

class TripTemplatesScreen extends StatefulWidget {
  const TripTemplatesScreen({super.key});
  @override
  State<TripTemplatesScreen> createState() => _TripTemplatesScreenState();
}

class _TripTemplatesScreenState extends State<TripTemplatesScreen> {
  String _filter = 'All';

  static final _templates = <_Template>[
    // Beach
    _Template('Goa Beach Escape', '3 Days', 'Beach', '🏖️', const Color(0xFF00ACC1), 12000,
        ['Day 1: Arrive → Calangute Beach → Titos Lane nightlife',
         'Day 2: Old Goa churches → Dudhsagar Falls → spice plantation',
         'Day 3: Palolem Beach → water sports → depart'],
        ['Sunscreen SPF 50+', 'Swimwear', 'Flip flops', 'Beach towel', 'Waterproof phone pouch', 'Light cotton clothes'],
        [_Waypoint('Dabolim Airport', 15.3808, 73.8314),
         _Waypoint('Calangute Beach', 15.5449, 73.7553),
         _Waypoint('Old Goa Churches', 15.5009, 73.9116),
         _Waypoint('Dudhsagar Falls', 15.3144, 74.3143),
         _Waypoint('Palolem Beach', 15.0100, 74.0230)]),
    _Template('Andaman Paradise', '5 Days', 'Beach', '🏝️', const Color(0xFF0097A7), 25000,
        ['Day 1: Port Blair → Cellular Jail → Light & Sound show',
         'Day 2: Ross Island → North Bay (snorkeling)',
         'Day 3: Ferry to Havelock → Radhanagar Beach sunset',
         'Day 4: Scuba diving → Elephant Beach kayaking',
         'Day 5: Kalapathar Beach → depart'],
        ['Snorkeling gear (or rent)', 'Reef-safe sunscreen', 'Waterproof bag', 'Anti-seasick medicine', 'Cash (limited ATMs)'],
        [_Waypoint('Port Blair Airport', 11.6410, 92.7297),
         _Waypoint('Cellular Jail', 11.6773, 92.7426),
         _Waypoint('Ross Island', 11.6739, 92.7577),
         _Waypoint('Radhanagar Beach', 11.9810, 92.9524),
         _Waypoint('Elephant Beach', 12.0065, 92.9809),
         _Waypoint('Kalapathar Beach', 12.0253, 92.9948)]),
    // Mountain
    _Template('Manali Adventure', '5 Days', 'Mountain', '🏔️', const Color(0xFF5C6BC0), 15000,
        ['Day 1: Arrive Manali → Mall Road → Hadimba Temple',
         'Day 2: Solang Valley → paragliding → zorbing',
         'Day 3: Rohtang Pass day trip (permit needed)',
         'Day 4: Old Manali cafes → Jogini Waterfall trek',
         'Day 5: Naggar Castle → depart'],
        ['Warm jacket', 'Thermal innerwear', 'Trekking shoes', 'Gloves & cap', 'Altitude sickness pills', 'Power bank'],
        [_Waypoint('Manali Bus Stand', 32.2396, 77.1887),
         _Waypoint('Hadimba Temple', 32.2432, 77.1680),
         _Waypoint('Solang Valley', 32.3150, 77.1574),
         _Waypoint('Rohtang Pass', 32.3722, 77.2478),
         _Waypoint('Jogini Waterfall', 32.2553, 77.1782),
         _Waypoint('Naggar Castle', 32.1330, 77.1667)]),
    _Template('Ladakh Road Trip', '7 Days', 'Mountain', '🗻', const Color(0xFF3949AB), 35000,
        ['Day 1: Fly to Leh → acclimatize → Shanti Stupa',
         'Day 2: Leh Palace → Thiksey Monastery → Hemis',
         'Day 3: Nubra Valley via Khardung La',
         'Day 4: Diskit → Hunder sand dunes → camel ride',
         'Day 5: Pangong Lake (camp overnight)',
         'Day 6: Return to Leh via Chang La',
         'Day 7: Local shopping → depart'],
        ['Warm layers (sub-zero)', 'Diamox tablets', 'Sunglasses UV400', 'Moisturizer & lip balm', 'Spare fuel cans', 'Copies of permits'],
        [_Waypoint('Leh Airport', 34.1359, 77.5465),
         _Waypoint('Shanti Stupa', 34.1637, 77.5855),
         _Waypoint('Thiksey Monastery', 34.0547, 77.6683),
         _Waypoint('Khardung La', 34.2818, 77.6027),
         _Waypoint('Diskit Monastery', 34.5327, 77.5577),
         _Waypoint('Pangong Lake', 33.7595, 78.6566)]),
    // Cultural
    _Template('Rajasthan Heritage', '6 Days', 'Cultural', '🏰', const Color(0xFFFF6D00), 20000,
        ['Day 1: Jaipur → Amber Fort → Hawa Mahal → bazaar',
         'Day 2: Jaipur → Jantar Mantar → City Palace',
         'Day 3: Drive to Jodhpur → Mehrangarh Fort',
         'Day 4: Jodhpur blue city walk → drive to Jaisalmer',
         'Day 5: Jaisalmer Fort → Patwon Haveli → desert safari',
         'Day 6: Sam sand dunes sunrise → depart'],
        ['Comfortable walking shoes', 'Scarf/dupatta (temple visits)', 'Sunscreen', 'Water bottle', 'Camera with spare battery'],
        [_Waypoint('Jaipur Airport', 26.8242, 75.8122),
         _Waypoint('Amber Fort', 26.9855, 75.8513),
         _Waypoint('Hawa Mahal', 26.9239, 75.8267),
         _Waypoint('Mehrangarh Fort', 26.2981, 73.0186),
         _Waypoint('Jaisalmer Fort', 26.9124, 70.9136),
         _Waypoint('Sam Sand Dunes', 26.8903, 70.5317)]),
    _Template('Kerala Backwaters', '4 Days', 'Cultural', '🛶', const Color(0xFF2E7D32), 18000,
        ['Day 1: Kochi → Fort Kochi → Chinese fishing nets',
         'Day 2: Drive to Munnar → tea plantations',
         'Day 3: Alleppey houseboat → backwater cruise',
         'Day 4: Marari Beach → depart from Kochi'],
        ['Mosquito repellent', 'Rain jacket', 'Light cotton clothes', 'Binoculars', 'Seasickness pills'],
        [_Waypoint('Kochi Airport', 10.1520, 76.4019),
         _Waypoint('Fort Kochi', 9.9639, 76.2428),
         _Waypoint('Munnar', 10.0889, 77.0595),
         _Waypoint('Alleppey', 9.4981, 76.3388),
         _Waypoint('Marari Beach', 9.5941, 76.2965)]),
    // Weekend
    _Template('Coorg Weekend', '2 Days', 'Weekend', '☕', const Color(0xFF43A047), 8000,
        ['Day 1: Arrive → Abbey Falls → Raja Seat sunset',
         'Day 2: Coffee plantation tour → Dubare elephant camp → depart'],
        ['Light jacket', 'Trekking shoes', 'Camera', 'Mosquito repellent'],
        [_Waypoint('Madikeri', 12.4208, 75.7397),
         _Waypoint('Abbey Falls', 12.4545, 75.7208),
         _Waypoint('Raja Seat', 12.4200, 75.7345),
         _Waypoint('Dubare Elephant Camp', 12.4319, 75.9469)]),
    _Template('Pondicherry Getaway', '2 Days', 'Weekend', '🇫🇷', const Color(0xFFE53935), 6000,
        ['Day 1: French Quarter walk → Promenade → Rock Beach → cafes',
         'Day 2: Auroville → Paradise Beach → depart'],
        ['Cycle rental money', 'Sunscreen', 'Comfortable shoes', 'Camera'],
        [_Waypoint('Pondicherry Bus Stand', 11.9340, 79.8350),
         _Waypoint('French Quarter', 11.9330, 79.8363),
         _Waypoint('Rock Beach', 11.9336, 79.8365),
         _Waypoint('Auroville', 12.0063, 79.8107),
         _Waypoint('Paradise Beach', 11.8983, 79.8263)]),
    // Pilgrimage
    _Template('Varanasi Spiritual', '3 Days', 'Pilgrimage', '🙏', const Color(0xFFFF8F00), 10000,
        ['Day 1: Arrive → Dashashwamedh Ghat → Ganga Aarti',
         'Day 2: Morning boat ride → Kashi Vishwanath → Sarnath',
         'Day 3: Sunrise at ghats → Ramnagar Fort → depart'],
        ['Modest clothing', 'Comfortable sandals', 'Small towel', 'Offerings/flowers'],
        [_Waypoint('Varanasi Airport', 25.4524, 82.8593),
         _Waypoint('Dashashwamedh Ghat', 25.3046, 83.0105),
         _Waypoint('Kashi Vishwanath', 25.3109, 83.0107),
         _Waypoint('Sarnath', 25.3816, 83.0226),
         _Waypoint('Ramnagar Fort', 25.2878, 83.0293)]),
    _Template('Tirupati Darshan', '2 Days', 'Pilgrimage', '🛕', const Color(0xFFEF6C00), 5000,
        ['Day 1: Arrive Tirupati → Tirumala temple darshan',
         'Day 2: Padmavathi temple → Sri Kalahasti → depart'],
        ['Dhoti/saree for temple', 'Comfortable footwear', 'ID proof', 'Booking confirmation'],
        [_Waypoint('Tirupati Airport', 13.6325, 79.5432),
         _Waypoint('Tirumala Temple', 13.6833, 79.3471),
         _Waypoint('Padmavathi Temple', 13.6349, 79.4190),
         _Waypoint('Sri Kalahasti', 13.7496, 79.6983)]),
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
            // Route preview
            Text('Route (${t.waypoints.length} stops)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...t.waypoints.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: e.key == 0
                        ? const Color(0xFF00BFA5).withOpacity(0.2)
                        : e.key == t.waypoints.length - 1
                            ? const Color(0xFFE53935).withOpacity(0.2)
                            : const Color(0xFF1A73E8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: Text(
                    e.key == 0 ? '🟢' : e.key == t.waypoints.length - 1 ? '🔴' : '📍',
                    style: const TextStyle(fontSize: 10),
                  )),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value.name,
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 12))),
              ]),
            )),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: t.color),
            icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(ctx, true),
            label: Text('Open in Map', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Build waypoints list for TripPlanService
      final waypoints = t.waypoints.asMap().entries.map((e) => {
        'name': e.value.name,
        'lat': e.value.lat,
        'lng': e.value.lng,
        'order': e.key,
      }).toList();

      // Save the trip plan with waypoints
      final planId = await TripPlanService.savePlan(
        teamId: null,
        name: t.name,
        waypoints: waypoints,
        routeDistanceKm: 0,
        routeDurationMin: 0,
        routePolyline: '',
        isRoundTrip: false,
      );

      if (mounted && planId != null) {
        // Navigate to the map — it will load the plan and auto-fetch the route
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LiveMapScreen(
            loadPlanId: planId,
            loadPlanWaypoints: waypoints,
            loadPlanName: t.name,
          )),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.name} saved! Open the map to view it.',
              style: GoogleFonts.inter()), backgroundColor: const Color(0xFF00BFA5)),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: SizedBox(height: 42, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _types.map((type) {
              final active = type == _filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: active,
                  selectedColor: const Color(0xFF1A73E8),
                  backgroundColor: const Color(0xFF161B22),
                  labelStyle: GoogleFonts.inter(color: active ? Colors.white : Colors.white54),
                  onSelected: (_) => setState(() => _filter = type),
                ),
              );
            }).toList(),
          )),
        ),
      ),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final t = filtered[index];
                return GestureDetector(
                  onTap: () => _useTemplate(t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.color.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(t.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      // Route stops count
                      Row(children: [
                        Icon(Icons.place_rounded, color: t.color, size: 14),
                        const SizedBox(width: 4),
                        Text('${t.waypoints.length} stops', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: t.color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(t.duration, style: GoogleFonts.inter(color: t.color, fontSize: 10, fontWeight: FontWeight.w600))),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('~₹${(t.budget / 1000).toStringAsFixed(0)}k', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                          Text('budget', style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
                        ]),
                      ]),
                    ]),
                  ),
                );
              },
              childCount: filtered.length,
            ),
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
  final List<_Waypoint> waypoints;
  const _Template(this.name, this.duration, this.type, this.emoji, this.color, this.budget, this.itinerary, this.packing, this.waypoints);
}

class _Waypoint {
  final String name;
  final double lat, lng;
  const _Waypoint(this.name, this.lat, this.lng);
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/notification_bell.dart';

class SmartPackingScreen extends StatefulWidget {
  const SmartPackingScreen({super.key});
  @override
  State<SmartPackingScreen> createState() => _SmartPackingScreenState();
}

class _SmartPackingScreenState extends State<SmartPackingScreen> {
  int _tripDays = 3;
  String _weather = 'Hot';
  String _tripType = 'Leisure';
  final Set<String> _checked = {};
  List<_PackItem> _suggestions = [];

  static const _weathers = ['Hot', 'Cold', 'Rainy', 'Mixed'];
  static const _tripTypes = ['Leisure', 'Business', 'Adventure', 'Beach', 'Mountain'];

  void _generateSuggestions() {
    final items = <_PackItem>[];

    // Essentials (always)
    items.addAll([
      _PackItem('Phone charger', Icons.battery_charging_full_rounded, 'Essentials', 1),
      _PackItem('ID / Passport', Icons.badge_rounded, 'Essentials', 1),
      _PackItem('Wallet / Cards', Icons.account_balance_wallet_rounded, 'Essentials', 1),
      _PackItem('Medications', Icons.medical_services_rounded, 'Essentials', 1),
      _PackItem('Toiletries kit', Icons.wash_rounded, 'Essentials', 1),
    ]);

    // Clothing based on days
    final tops = (_tripDays * 1.2).ceil();
    final bottoms = (_tripDays * 0.7).ceil();
    items.add(_PackItem('T-shirts / Tops', Icons.checkroom_rounded, 'Clothing', tops));
    items.add(_PackItem('Pants / Bottoms', Icons.checkroom_rounded, 'Clothing', bottoms));
    items.add(_PackItem('Underwear', Icons.checkroom_rounded, 'Clothing', _tripDays + 1));
    items.add(_PackItem('Socks', Icons.checkroom_rounded, 'Clothing', _tripDays));
    items.add(_PackItem('Sleepwear', Icons.nightlight_rounded, 'Clothing', 1));

    // Weather-specific
    if (_weather == 'Cold' || _weather == 'Mountain' || _weather == 'Mixed') {
      items.addAll([
        _PackItem('Jacket / Sweater', Icons.ac_unit_rounded, 'Weather', 1),
        _PackItem('Thermal innerwear', Icons.ac_unit_rounded, 'Weather', 2),
        _PackItem('Warm cap / Gloves', Icons.ac_unit_rounded, 'Weather', 1),
      ]);
    }
    if (_weather == 'Hot' || _weather == 'Mixed') {
      items.addAll([
        _PackItem('Sunscreen', Icons.wb_sunny_rounded, 'Weather', 1),
        _PackItem('Sunglasses', Icons.wb_sunny_rounded, 'Weather', 1),
        _PackItem('Cap / Hat', Icons.wb_sunny_rounded, 'Weather', 1),
      ]);
    }
    if (_weather == 'Rainy' || _weather == 'Mixed') {
      items.addAll([
        _PackItem('Umbrella', Icons.umbrella_rounded, 'Weather', 1),
        _PackItem('Rain jacket', Icons.umbrella_rounded, 'Weather', 1),
        _PackItem('Waterproof bag', Icons.umbrella_rounded, 'Weather', 1),
      ]);
    }

    // Trip-type specific
    if (_tripType == 'Adventure' || _tripType == 'Mountain') {
      items.addAll([
        _PackItem('Hiking shoes', Icons.terrain_rounded, 'Activity', 1),
        _PackItem('Backpack', Icons.backpack_rounded, 'Activity', 1),
        _PackItem('Flashlight', Icons.flashlight_on_rounded, 'Activity', 1),
        _PackItem('First aid kit', Icons.healing_rounded, 'Activity', 1),
        _PackItem('Water bottle', Icons.water_drop_rounded, 'Activity', 1),
      ]);
    }
    if (_tripType == 'Beach') {
      items.addAll([
        _PackItem('Swimwear', Icons.pool_rounded, 'Activity', 1),
        _PackItem('Beach towel', Icons.dry_cleaning_rounded, 'Activity', 1),
        _PackItem('Flip flops', Icons.flip_rounded, 'Activity', 1),
      ]);
    }
    if (_tripType == 'Business') {
      items.addAll([
        _PackItem('Formal shirts', Icons.business_center_rounded, 'Activity', _tripDays.clamp(1, 3)),
        _PackItem('Formal shoes', Icons.business_center_rounded, 'Activity', 1),
        _PackItem('Laptop + charger', Icons.laptop_rounded, 'Activity', 1),
        _PackItem('Notebook / Pen', Icons.edit_note_rounded, 'Activity', 1),
      ]);
    }

    // Tech
    items.addAll([
      _PackItem('Power bank', Icons.power_rounded, 'Tech', 1),
      _PackItem('Earphones', Icons.headphones_rounded, 'Tech', 1),
    ]);
    if (_tripDays > 3) {
      items.add(_PackItem('Travel adapter', Icons.electrical_services_rounded, 'Tech', 1));
    }

    setState(() => _suggestions = items);
  }

  @override
  void initState() {
    super.initState();
    _generateSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _suggestions.map((e) => e.category).toSet().toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Smart Packing', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          Center(child: Text('${_checked.length}/${_suggestions.length}',
              style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 13, fontWeight: FontWeight.bold))),
          const NotificationBell(), const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Config row
          Row(children: [
            Expanded(child: _configChip('${_tripDays}d trip', Icons.calendar_today_rounded, () async {
              final val = await _showSliderDialog('Trip Duration', _tripDays.toDouble(), 1, 30, ' days');
              if (val != null) { _tripDays = val.toInt(); _generateSuggestions(); }
            })),
            const SizedBox(width: 8),
            Expanded(child: _configChip(_weather, Icons.thermostat_rounded, () async {
              final val = await _showOptionDialog('Weather', _weathers, _weather);
              if (val != null) { _weather = val; _generateSuggestions(); }
            })),
            const SizedBox(width: 8),
            Expanded(child: _configChip(_tripType, Icons.luggage_rounded, () async {
              final val = await _showOptionDialog('Trip Type', _tripTypes, _tripType);
              if (val != null) { _tripType = val; _generateSuggestions(); }
            })),
          ]),
          const SizedBox(height: 16),
          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _suggestions.isEmpty ? 0 : _checked.length / _suggestions.length,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00BFA5)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),
          // Items by category
          ...categories.map((cat) {
            final items = _suggestions.where((e) => e.category == cat).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat, style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final key = '${item.category}_${item.name}';
                  final done = _checked.contains(key);
                  return GestureDetector(
                    onTap: () => setState(() => done ? _checked.remove(key) : _checked.add(key)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: done ? const Color(0xFF00BFA5).withOpacity(0.08) : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: done ? const Color(0xFF00BFA5).withOpacity(0.3) : Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(children: [
                        Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: done ? const Color(0xFF00BFA5) : Colors.white24, size: 20),
                        const SizedBox(width: 10),
                        Icon(item.icon, color: done ? Colors.white38 : Colors.white54, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item.name,
                            style: GoogleFonts.inter(color: done ? Colors.white38 : Colors.white,
                                fontSize: 13, decoration: done ? TextDecoration.lineThrough : null))),
                        if (item.qty > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                            child: Text('x${item.qty}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                          ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _configChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: const Color(0xFF1A73E8)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Future<double?> _showSliderDialog(String title, double value, double min, double max, String suffix) async {
    double current = value;
    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${current.toInt()}$suffix', style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 28, fontWeight: FontWeight.w900)),
            Slider(value: current, min: min, max: max, divisions: (max - min).toInt(),
                activeColor: const Color(0xFF1A73E8),
                onChanged: (v) => setS(() => current = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, current),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
                child: Text('Apply', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Future<String?> _showOptionDialog(String title, List<String> options, String current) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min,
            children: options.map((o) => ListTile(
              dense: true,
              title: Text(o, style: GoogleFonts.inter(color: o == current ? const Color(0xFF1A73E8) : Colors.white70, fontWeight: o == current ? FontWeight.bold : FontWeight.normal)),
              trailing: o == current ? const Icon(Icons.check_rounded, color: Color(0xFF1A73E8), size: 18) : null,
              onTap: () => Navigator.pop(ctx, o),
            )).toList()),
      ),
    );
  }
}

class _PackItem {
  final String name;
  final IconData icon;
  final String category;
  final int qty;
  _PackItem(this.name, this.icon, this.category, this.qty);
}

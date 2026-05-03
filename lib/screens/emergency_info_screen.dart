import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/notification_bell.dart';

class EmergencyInfoScreen extends StatefulWidget {
  const EmergencyInfoScreen({super.key});
  @override
  State<EmergencyInfoScreen> createState() => _EmergencyInfoScreenState();
}

class _EmergencyInfoScreenState extends State<EmergencyInfoScreen> {
  String _selected = 'India';

  static final _countries = <String, _CountryInfo>{
    'India': _CountryInfo('🇮🇳', [_Num('Police', '100'), _Num('Ambulance', '108'), _Num('Fire', '101'), _Num('Women Helpline', '1091'), _Num('Road Accident', '1073'), _Num('Tourist Helpline', '1363')]),
    'USA': _CountryInfo('🇺🇸', [_Num('Emergency', '911'), _Num('Poison Control', '1-800-222-1222'), _Num('Road Assist', '511')]),
    'UK': _CountryInfo('🇬🇧', [_Num('Emergency', '999'), _Num('Non-Emergency', '101'), _Num('NHS', '111')]),
    'UAE': _CountryInfo('🇦🇪', [_Num('Police', '999'), _Num('Ambulance', '998'), _Num('Fire', '997'), _Num('Tourist Police', '901')]),
    'Singapore': _CountryInfo('🇸🇬', [_Num('Police', '999'), _Num('Ambulance/Fire', '995')]),
    'Thailand': _CountryInfo('🇹🇭', [_Num('Police', '191'), _Num('Tourist Police', '1155'), _Num('Ambulance', '1669')]),
    'Malaysia': _CountryInfo('🇲🇾', [_Num('Emergency', '999'), _Num('Police', '112'), _Num('Fire', '994')]),
    'Japan': _CountryInfo('🇯🇵', [_Num('Police', '110'), _Num('Fire/Ambulance', '119')]),
    'Australia': _CountryInfo('🇦🇺', [_Num('Emergency', '000'), _Num('Police Non-Emg', '131 444')]),
    'Sri Lanka': _CountryInfo('🇱🇰', [_Num('Police', '119'), _Num('Ambulance', '110'), _Num('Fire', '111')]),
    'Nepal': _CountryInfo('🇳🇵', [_Num('Police', '100'), _Num('Ambulance', '102'), _Num('Fire', '101')]),
  };

  @override
  Widget build(BuildContext context) {
    final info = _countries[_selected]!;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Emergency Info', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Country selector
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _countries.entries.map((e) {
                final sel = e.key == _selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Text(e.value.flag, style: const TextStyle(fontSize: 16)),
                    label: Text(e.key, style: GoogleFonts.inter(fontSize: 11, color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
                    selected: sel, selectedColor: const Color(0xFFE53935),
                    backgroundColor: const Color(0xFF161B22),
                    side: BorderSide(color: sel ? const Color(0xFFE53935) : Colors.white.withOpacity(0.08)),
                    onSelected: (_) => setState(() => _selected = e.key),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF5252)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Text(info.flag, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selected, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('${info.numbers.length} emergency numbers', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          // Numbers
          ...info.numbers.map((n) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_rounded, color: Color(0xFFE53935), size: 20),
              ),
              title: Text(n.label, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(n.number, style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontSize: 18, fontWeight: FontWeight.w900)),
              trailing: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.call_rounded, color: Color(0xFF00BFA5), size: 18),
                ),
                onPressed: () => launchUrl(Uri.parse('tel:${n.number}')),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _CountryInfo {
  final String flag;
  final List<_Num> numbers;
  const _CountryInfo(this.flag, this.numbers);
}

class _Num {
  final String label, number;
  const _Num(this.label, this.number);
}

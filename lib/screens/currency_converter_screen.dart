import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../widgets/notification_bell.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});
  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _amountCtrl = TextEditingController(text: '1000');
  String _from = 'INR';
  String _to = 'USD';
  double? _result;
  bool _loading = false;
  Map<String, double> _rates = {};

  static const _popular = ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD', 'THB', 'MYR', 'JPY', 'AUD', 'CAD', 'CHF', 'LKR', 'NPR', 'BDT'];
  
  static const _flags = {
    'INR': '🇮🇳', 'USD': '🇺🇸', 'EUR': '🇪🇺', 'GBP': '🇬🇧', 'AED': '🇦🇪',
    'SGD': '🇸🇬', 'THB': '🇹🇭', 'MYR': '🇲🇾', 'JPY': '🇯🇵', 'AUD': '🇦🇺',
    'CAD': '🇨🇦', 'CHF': '🇨🇭', 'LKR': '🇱🇰', 'NPR': '🇳🇵', 'BDT': '🇧🇩',
  };

  @override
  void initState() {
    super.initState();
    _convert();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    setState(() { _loading = true; _result = null; });
    try {
      final url = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${_from.toLowerCase()}.json';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final ratesMap = json[_from.toLowerCase()] as Map<String, dynamic>? ?? {};
        _rates = ratesMap.map((k, v) => MapEntry(k.toUpperCase(), (v as num).toDouble()));
        final rate = _rates[_to] ?? 0;
        final amount = double.tryParse(_amountCtrl.text) ?? 0;
        _result = amount * rate;
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Currency', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Result card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF4FC3F7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(children: [
              if (_loading)
                const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: Colors.white)))
              else if (_result != null) ...[
                Text('${_amountCtrl.text} $_from =', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${_result!.toStringAsFixed(2)} $_to',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                if (_rates[_to] != null)
                  Text('1 $_from = ${_rates[_to]!.toStringAsFixed(4)} $_to',
                      style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
              ] else
                Text('Enter amount to convert', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 20),
          // Amount input
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Amount',
              labelStyle: GoogleFonts.inter(color: Colors.white38),
              filled: true, fillColor: const Color(0xFF161B22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Text(_flags[_from] ?? '💱', style: const TextStyle(fontSize: 20))),
            ),
            onChanged: (_) => _convert(),
          ),
          const SizedBox(height: 14),
          // From / Swap / To
          Row(children: [
            Expanded(child: _currencyDropdown('From', _from, (v) { _from = v; _convert(); })),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                onPressed: _swap,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF1A73E8).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF1A73E8)),
                ),
              ),
            ),
            Expanded(child: _currencyDropdown('To', _to, (v) { _to = v; _convert(); })),
          ]),
          const SizedBox(height: 24),
          // Quick rates
          Text('Quick Rates from $_from', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ..._popular.where((c) => c != _from && _rates.containsKey(c)).take(8).map((c) {
            final rate = _rates[c]!;
            final amount = double.tryParse(_amountCtrl.text) ?? 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(children: [
                Text(_flags[c] ?? '💱', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(c, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text((amount * rate).toStringAsFixed(2),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _currencyDropdown(String label, String value, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C2128),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
          items: _popular.map((c) => DropdownMenuItem(
            value: c,
            child: Row(children: [
              Text(_flags[c] ?? '', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(c, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          )).toList(),
          onChanged: (v) { if (v != null) { setState(() => onChanged(v)); } },
        ),
      ),
    );
  }
}

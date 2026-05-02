import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/notification_bell.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  bool _isSending = false;
  bool _sent = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendSos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    // Get current location
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {}

    // Send SOS to all user's teams
    final teamsSnapshot = await FirebaseFirestore.instance
        .collection('teams')
        .where('members', arrayContains: user.uid)
        .get();

    for (final teamDoc in teamsSnapshot.docs) {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamDoc.id)
          .collection('sos')
          .add({
        'userId': user.uid,
        'userName': user.displayName ?? 'Unknown',
        'userPhoto': user.photoURL ?? '',
        'lat': position?.latitude ?? 0,
        'lng': position?.longitude ?? 0,
        'accuracy': position?.accuracy ?? 0,
        'message': 'Emergency! I need help!',
        'createdAt': FieldValue.serverTimestamp(),
        'resolved': false,
      });

      // Also send as a chat message
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamDoc.id)
          .collection('messages')
          .add({
        'text': '🚨 SOS EMERGENCY! ${user.displayName ?? "A member"} needs help!\n📍 Location: ${position?.latitude.toStringAsFixed(5) ?? "unknown"}, ${position?.longitude.toStringAsFixed(5) ?? "unknown"}',
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Unknown',
        'senderPhoto': user.photoURL ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'sos',
      });
    }

    setState(() {
      _isSending = false;
      _sent = true;
    });

    // Reset after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _sent = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Emergency SOS', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Warning icon
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.redAccent.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Send an emergency alert to\nall your team members',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 48),

            // SOS button
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = _sent ? 1.0 : 1.0 + (_pulseCtrl.value * 0.05);
                return Transform.scale(scale: scale, child: child);
              },
              child: GestureDetector(
                onTap: _isSending || _sent ? null : _sendSos,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _sent
                        ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                        : const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
                    boxShadow: [
                      BoxShadow(
                        color: (_sent ? Colors.green : Colors.redAccent).withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                        : _sent
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                                  Text('Sent!', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sos_rounded, color: Colors.white, size: 48),
                                  Text('SOS', style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
                                ],
                              ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Info text
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text('What happens:', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('📍 Your GPS location is shared'),
                  _infoRow('💬 Alert sent to all team chats'),
                  _infoRow('🔔 All team members are notified'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Expanded(child: Text(text, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12))),
        ],
      ),
    );
  }
}

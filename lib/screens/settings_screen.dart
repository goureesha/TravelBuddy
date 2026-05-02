import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_contact_service.dart';
import '../widgets/notification_bell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  backgroundColor: const Color(0xFF1A73E8),
                  child: user?.photoURL == null
                      ? Text(user?.displayName?.isNotEmpty == true ? user!.displayName![0] : '?',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'Traveler',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Emergency contacts
          Text('Emergency Contacts', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: EmergencyContactService.getContacts(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return Column(
                children: [
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE53935),
                          child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                        ),
                        title: Text(data['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                        subtitle: Text(data['phone'] ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone_rounded, color: Color(0xFF00BFA5), size: 20),
                              onPressed: () => _callNumber(data['phone'] ?? ''),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                              onPressed: () => EmergencyContactService.deleteContact(doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showAddContact(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Add Contact', style: GoogleFonts.inter(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00BFA5),
                      side: BorderSide(color: const Color(0xFF00BFA5).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Sign out
          ElevatedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  void _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showAddContact(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Emergency Contact', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              await EmergencyContactService.addContact(nameCtrl.text.trim(), phoneCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

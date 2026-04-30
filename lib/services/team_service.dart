import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _email => _auth.currentUser?.email;
  static String? get _name => _auth.currentUser?.displayName;
  static String? get _photo => _auth.currentUser?.photoURL;

  /// Generate a 6-character invite code
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No O/0/1/I confusion
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Create a new team
  static Future<String?> createTeam(String teamName) async {
    if (_uid == null) return null;

    final inviteCode = _generateInviteCode();
    final docRef = await _firestore.collection('teams').add({
      'name': teamName.trim(),
      'inviteCode': inviteCode,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [_uid],
      'memberDetails': {
        _uid!: {
          'name': _name ?? 'Unknown',
          'email': _email ?? '',
          'photoUrl': _photo ?? '',
          'role': 'admin',
          'joinedAt': FieldValue.serverTimestamp(),
        },
      },
    });

    return docRef.id;
  }

  /// Join a team using invite code
  static Future<String?> joinTeam(String code) async {
    if (_uid == null) return null;

    final query = await _firestore
        .collection('teams')
        .where('inviteCode', isEqualTo: code.toUpperCase().trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final members = List<String>.from(doc.data()['members'] ?? []);

    if (members.contains(_uid)) {
      return doc.id; // Already a member
    }

    await doc.reference.update({
      'members': FieldValue.arrayUnion([_uid]),
      'memberDetails.$_uid': {
        'name': _name ?? 'Unknown',
        'email': _email ?? '',
        'photoUrl': _photo ?? '',
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      },
    });

    return doc.id;
  }

  /// Get teams the current user belongs to (real-time stream)
  static Stream<QuerySnapshot> getMyTeams() {
    if (_uid == null) return const Stream.empty();
    return _firestore
        .collection('teams')
        .where('members', arrayContains: _uid)
        .snapshots();
  }

  /// Get a single team (real-time stream)
  static Stream<DocumentSnapshot> getTeam(String teamId) {
    return _firestore.collection('teams').doc(teamId).snapshots();
  }

  /// Leave a team
  static Future<void> leaveTeam(String teamId) async {
    if (_uid == null) return;
    await _firestore.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayRemove([_uid]),
      'memberDetails.$_uid': FieldValue.delete(),
    });
  }

  /// Delete a team (admin only)
  static Future<void> deleteTeam(String teamId) async {
    await _firestore.collection('teams').doc(teamId).delete();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Send a text message to a team
  static Future<void> sendMessage(String teamId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('messages')
        .add({
      'text': text.trim(),
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown',
      'senderPhoto': user.photoURL ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });
  }

  /// Get real-time message stream for a team
  static Stream<QuerySnapshot> getMessages(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }
}

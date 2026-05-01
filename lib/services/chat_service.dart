import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// Messages collection for a team
  static CollectionReference _messagesRef(String teamId) {
    return _firestore.collection('teams').doc(teamId).collection('messages');
  }

  /// Send a text message to a team
  static Future<void> sendMessage(String teamId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    await _messagesRef(teamId).add({
      'text': text.trim(),
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown',
      'senderPhoto': user.photoURL ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    // Update team's last message info for quick badge checks
    await _firestore.collection('teams').doc(teamId).update({
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': user.uid,
    });
  }

  /// Get real-time message stream for a team
  static Stream<QuerySnapshot> getMessages(String teamId) {
    return _messagesRef(teamId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Mark messages as read for current user
  static Future<void> markAsRead(String teamId) async {
    if (_uid == null) return;
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('readStatus')
        .doc(_uid)
        .set({'lastRead': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Stream: does this team have unread messages?
  static Stream<bool> hasUnread(String teamId) {
    if (_uid == null) return Stream.value(false);

    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('readStatus')
        .doc(_uid)
        .snapshots()
        .asyncMap((readDoc) async {
      final lastRead = readDoc.data()?['lastRead'] as Timestamp?;

      final latestMsg = await _messagesRef(teamId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latestMsg.docs.isEmpty) return false;

      final msgData = latestMsg.docs.first.data() as Map<String, dynamic>;
      final msgTime = msgData['timestamp'] as Timestamp?;
      final senderId = msgData['senderId'] as String?;

      // Don't badge for own messages
      if (senderId == _uid) return false;
      if (lastRead == null) return true;
      if (msgTime == null) return false;

      return msgTime.compareTo(lastRead) > 0;
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class BlogService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _name => _auth.currentUser?.displayName;
  static String? get _photo => _auth.currentUser?.photoURL;

  /// Create a blog post
  static Future<String?> createPost({
    required String teamId,
    required String caption,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (_uid == null) return null;

    String? imageUrl;

    // Upload image if provided
    if (imageBytes != null && imageName != null) {
      try {
        final ref = _storage
            .ref()
            .child('teams/$teamId/blog/${DateTime.now().millisecondsSinceEpoch}_$imageName');
        await ref.putData(imageBytes);
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        // Continue without image if upload fails
      }
    }

    final docRef = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('blog')
        .add({
      'caption': caption.trim(),
      'imageUrl': imageUrl ?? '',
      'userId': _uid,
      'userName': _name ?? 'Unknown',
      'userPhoto': _photo ?? '',
      'likes': [],
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Get blog posts for a team (real-time)
  static Stream<QuerySnapshot> getTeamBlog(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('blog')
        .snapshots();
  }

  /// Toggle like on a post
  static Future<void> toggleLike(String teamId, String postId) async {
    if (_uid == null) return;

    final docRef = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('blog')
        .doc(postId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final likes = List<String>.from(doc.data()?['likes'] ?? []);

    if (likes.contains(_uid)) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([_uid]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([_uid]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  /// Delete a post
  static Future<void> deletePost(String teamId, String postId) async {
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('blog')
        .doc(postId)
        .delete();
  }
}

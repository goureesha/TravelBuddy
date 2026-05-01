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

  /// Returns the blog collection ref — personal or team-scoped
  static CollectionReference _blogRef(String? teamId) {
    if (teamId != null) {
      return _firestore.collection('teams').doc(teamId).collection('blog');
    }
    return _firestore.collection('users').doc(_uid!).collection('blog');
  }

  /// Create a blog post
  static Future<String?> createPost({
    String? teamId,
    required String caption,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (_uid == null) return null;

    String? imageUrl;
    final storagePath = teamId != null ? 'teams/$teamId' : 'users/$_uid';

    // Upload image if provided
    if (imageBytes != null && imageName != null) {
      final ref = _storage
          .ref()
          .child('$storagePath/blog/${DateTime.now().millisecondsSinceEpoch}_$imageName');
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      imageUrl = await ref.getDownloadURL();
    }

    final docRef = await _blogRef(teamId).add({
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

  /// Get blog posts (real-time)
  static Stream<QuerySnapshot> getTeamBlog(String? teamId) {
    return _blogRef(teamId).snapshots();
  }

  /// Toggle like on a post
  static Future<void> toggleLike(String? teamId, String postId) async {
    if (_uid == null) return;

    final docRef = _blogRef(teamId).doc(postId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final likes = List<String>.from((doc.data() as Map<String, dynamic>?)?['likes'] ?? []);

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
  static Future<void> deletePost(String? teamId, String postId) async {
    await _blogRef(teamId).doc(postId).delete();
  }
}

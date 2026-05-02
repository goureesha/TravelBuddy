import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyContactService {
  static final _firestore = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static CollectionReference get _collection =>
      _firestore.collection('users').doc(_uid).collection('emergency_contacts');

  static Future<void> addContact(String name, String phone) async {
    await _collection.add({
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> getContacts() {
    return _collection.orderBy('createdAt').snapshots();
  }

  static Future<void> deleteContact(String docId) async {
    await _collection.doc(docId).delete();
  }
}

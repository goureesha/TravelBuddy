import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _name => _auth.currentUser?.displayName;

  /// Add an expense
  static Future<String?> addExpense({
    required String teamId,
    required String description,
    required double amount,
    required String category,
    List<String>? splitWith, // list of user IDs to split with
  }) async {
    if (_uid == null) return null;

    final docRef = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('expenses')
        .add({
      'description': description.trim(),
      'amount': amount,
      'category': category,
      'paidBy': _uid,
      'paidByName': _name ?? 'Unknown',
      'splitWith': splitWith ?? [],
      'settled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Get all expenses for a team
  static Stream<QuerySnapshot> getTeamExpenses(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('expenses')
        .snapshots();
  }

  /// Toggle settled status
  static Future<void> toggleSettled(String teamId, String expenseId, bool settled) async {
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('expenses')
        .doc(expenseId)
        .update({'settled': !settled});
  }

  /// Delete an expense
  static Future<void> deleteExpense(String teamId, String expenseId) async {
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  /// Calculate balances (who owes whom)
  static Map<String, double> calculateBalances(List<QueryDocumentSnapshot> expenses) {
    final Map<String, double> balances = {};

    for (final doc in expenses) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['settled'] == true) continue;

      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final paidBy = data['paidBy'] as String? ?? '';
      final paidByName = data['paidByName'] as String? ?? 'Unknown';
      final splitWith = List<String>.from(data['splitWith'] ?? []);

      if (splitWith.isEmpty) continue;

      final perPerson = amount / (splitWith.length + 1);

      // Payer is owed money
      balances[paidByName] = (balances[paidByName] ?? 0) + (amount - perPerson);

      // Each person owes
      for (final uid in splitWith) {
        final key = uid; // In real app, resolve to name
        balances[key] = (balances[key] ?? 0) - perPerson;
      }
    }

    return balances;
  }

  static const categories = {
    'food': '🍽️',
    'fuel': '⛽',
    'hotel': '🏨',
    'transport': '🚕',
    'tickets': '🎫',
    'shopping': '🛍️',
    'other': '📝',
  };
}

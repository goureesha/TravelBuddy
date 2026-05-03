import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_bell.dart';

class ExpenseAnalyticsScreen extends StatefulWidget {
  const ExpenseAnalyticsScreen({super.key});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static const _categoryColors = {
    'Fuel': Color(0xFFFF6D00),
    'Food': Color(0xFF66BB6A),
    'Stay': Color(0xFF42A5F5),
    'Toll': Color(0xFFAB47BC),
    'Shopping': Color(0xFFEC407A),
    'Transport': Color(0xFF26A69A),
    'Other': Color(0xFF78909C),
  };

  static const _categoryIcons = {
    'Fuel': Icons.local_gas_station_rounded,
    'Food': Icons.restaurant_rounded,
    'Stay': Icons.hotel_rounded,
    'Toll': Icons.toll_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Transport': Icons.directions_car_rounded,
    'Other': Icons.receipt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Expense Analytics', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(_uid).collection('trip_costs')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 12),
                  Text('No expense data yet', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                  Text('Add costs in Trip Costs to see analytics', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                ],
              ),
            );
          }

          // Calculate analytics
          double totalSpent = 0;
          final categoryTotals = <String, double>{};
          final dailyTotals = <String, double>{};
          int totalEntries = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            final category = data['category'] as String? ?? 'Other';
            final ts = data['createdAt'] as Timestamp?;

            totalSpent += amount;
            totalEntries++;
            categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;

            if (ts != null) {
              final dateKey = DateFormat('dd MMM').format(ts.toDate());
              dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + amount;
            }
          }

          final avgPerDay = dailyTotals.isNotEmpty
              ? totalSpent / dailyTotals.length
              : 0.0;

          final sortedCategories = categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final maxDailySpend = dailyTotals.values.fold<double>(0, max);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(child: _summaryCard('Total Spent', '₹${totalSpent.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, const Color(0xFF1A73E8))),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryCard('Avg/Day', '₹${avgPerDay.toStringAsFixed(0)}', Icons.trending_up_rounded, const Color(0xFF00BFA5))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _summaryCard('Entries', '$totalEntries', Icons.receipt_long_rounded, const Color(0xFFFF6D00))),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryCard('Categories', '${categoryTotals.length}', Icons.category_rounded, const Color(0xFF7C4DFF))),
                ],
              ),

              const SizedBox(height: 28),

              // Category breakdown with donut-like bar chart
              Text('By Category', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              ...sortedCategories.map((entry) {
                final pct = totalSpent > 0 ? (entry.value / totalSpent) : 0.0;
                final color = _categoryColors[entry.key] ?? const Color(0xFF78909C);
                final icon = _categoryIcons[entry.key] ?? Icons.receipt_rounded;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(entry.key, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${entry.value.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                Text('${(pct * 100).toStringAsFixed(0)}%',
                                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Daily spending chart
              Text('Daily Spending', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: dailyTotals.entries.take(7).map((entry) {
                          final barHeight = maxDailySpend > 0 ? (entry.value / maxDailySpend) * 110 : 0.0;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('₹${entry.value.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 9)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1A73E8), Color(0xFF4FC3F7)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(entry.key.split(' ').first,
                                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 9)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Top expense
              if (sortedCategories.isNotEmpty) ...[
                Text('Insights', style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _insightCard(
                  Icons.trending_up_rounded,
                  'Highest Category',
                  '${sortedCategories.first.key} accounts for ${((sortedCategories.first.value / totalSpent) * 100).toStringAsFixed(0)}% of spending',
                  const Color(0xFFFF6D00),
                ),
                const SizedBox(height: 8),
                _insightCard(
                  Icons.calendar_today_rounded,
                  'Spending Days',
                  'You logged expenses on ${dailyTotals.length} different days',
                  const Color(0xFF1A73E8),
                ),
                if (avgPerDay > 0) ...[
                  const SizedBox(height: 8),
                  _insightCard(
                    Icons.savings_rounded,
                    'Daily Average',
                    '₹${avgPerDay.toStringAsFixed(0)} per day across ${dailyTotals.length} days',
                    const Color(0xFF00BFA5),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _insightCard(IconData icon, String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(description, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

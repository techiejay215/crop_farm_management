// lib/features/expenses/widgets/expense_category_style.dart
import 'package:flutter/material.dart';

class ExpenseCategoryStyle {
  const ExpenseCategoryStyle({
    required this.value,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
}

/// Single source of truth for how a category looks.
/// The colour is reused by the chips, the bars, the list icons and the form.
class ExpenseCategories {
  const ExpenseCategories._();

  static const ExpenseCategoryStyle other = ExpenseCategoryStyle(
    value: 'other',
    label: 'Other',
    shortLabel: 'Other',
    icon: Icons.more_horiz,
    color: Color(0xFF757575),
  );

  static const List<ExpenseCategoryStyle> all = <ExpenseCategoryStyle>[
    ExpenseCategoryStyle(
        value: 'seeds',
        label: 'Seeds & Seedlings',
        shortLabel: 'Seeds',
        icon: Icons.grass,
        color: Color(0xFF43A047)),
    ExpenseCategoryStyle(
        value: 'fertilizer',
        label: 'Fertilizer',
        shortLabel: 'Fertilizer',
        icon: Icons.eco,
        color: Color(0xFF8D6E63)),
    ExpenseCategoryStyle(
        value: 'chemicals',
        label: 'Chemicals & Pesticides',
        shortLabel: 'Chemicals',
        icon: Icons.science,
        color: Color(0xFF7E57C2)),
    ExpenseCategoryStyle(
        value: 'labour',
        label: 'Labour',
        shortLabel: 'Labour',
        icon: Icons.engineering,
        color: Color(0xFF1E88E5)),
    ExpenseCategoryStyle(
        value: 'irrigation',
        label: 'Irrigation & Water',
        shortLabel: 'Water',
        icon: Icons.water_drop,
        color: Color(0xFF00ACC1)),
    ExpenseCategoryStyle(
        value: 'transport',
        label: 'Transport',
        shortLabel: 'Transport',
        icon: Icons.local_shipping,
        color: Color(0xFFF4511E)),
    ExpenseCategoryStyle(
        value: 'rent',
        label: 'Land Rent',
        shortLabel: 'Rent',
        icon: Icons.key,
        color: Color(0xFF6D4C41)),
    ExpenseCategoryStyle(
        value: 'maintenance',
        label: 'Greenhouse Maintenance',
        shortLabel: 'Maintenance',
        icon: Icons.build,
        color: Color(0xFF546E7A)),
    ExpenseCategoryStyle(
        value: 'packaging',
        label: 'Packaging & Harvesting',
        shortLabel: 'Packaging',
        icon: Icons.inventory_2,
        color: Color(0xFFF9A825)),
    other,
  ];

  static ExpenseCategoryStyle of(String value) =>
      all.firstWhere((c) => c.value == value, orElse: () => other);

  static String labelFor(String value) => of(value).label;
}
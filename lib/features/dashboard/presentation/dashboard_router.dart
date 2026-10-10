import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../dashboard_screen.dart';   // ← up one level to dashboard/

class DashboardRouter extends ConsumerWidget {
  const DashboardRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (isAdmin) return const AdminDashboardScreen();
    return const DashboardScreen();
  }
}
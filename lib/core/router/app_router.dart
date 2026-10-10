import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ---- Admin ----
import '../../features/admin/presentation/register_customer_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';

// ---- Auth ----
import '../../features/auth/presentation/login_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

// ---- Dashboard ----
import '../../features/dashboard/presentation/dashboard_router.dart';

// ---- Farms ----
import '../../features/farms/farms_screen.dart';
import '../../features/farms/presentation/add_edit_farm_screen.dart';
import '../../features/farms/presentation/payment_info_screen.dart';

// ---- Crops ----
import '../../features/crops/presentation/crops_screen.dart';
import '../../features/crops/presentation/add_edit_crop_screen.dart';
import '../../features/crops/presentation/crop_detail_screen.dart';
import '../../features/crops/presentation/add_edit_activity_screen.dart';

// ---- Greenhouses ----
import '../../features/greenhouses/presentation/greenhouses_screen.dart';
import '../../features/greenhouses/presentation/add_edit_greenhouse_screen.dart';
import '../../features/greenhouses/presentation/greenhouse_detail_screen.dart';

// ---- Harvests ----
import '../../features/harvests/presentation/harvests_screen.dart';
import '../../features/harvests/presentation/add_edit_harvest_screen.dart';

// ---- Sales ----
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/sales/presentation/add_edit_sale_screen.dart';
import '../../features/sales/presentation/sale_invoice_screen.dart';

// ---- Expenses ----
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/expenses/presentation/add_edit_expense_screen.dart';

// ---- Labour ----
import '../../features/labour/presentation/labour_screen.dart';
import '../../features/labour/presentation/add_edit_labour_screen.dart';

// ---- Reports ----
import '../../features/reports/presentation/reports_hub_screen.dart';
import '../../features/reports/presentation/expense_report_screen.dart';
import '../../features/reports/presentation/sales_report_screen.dart';
import '../../features/reports/presentation/labour_report_screen.dart';
import '../../features/reports/presentation/financial_summary_screen.dart';
import '../../features/reports/presentation/harvest_report_screen.dart';
import '../../features/reports/presentation/farm_report_screen.dart';
import '../../features/reports/presentation/crop_report_screen.dart';
import '../../features/reports/presentation/crop_report_detail_screen.dart';
import '../../features/reports/presentation/greenhouse_report_screen.dart';

// ---- Shell ----
import '../layout/main_shell.dart';

// ============================================================================
// Auth change notifier
// ============================================================================
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier._() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  static final _AuthChangeNotifier instance = _AuthChangeNotifier._();

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _AuthChangeNotifier.instance,
  routes: [
    // ============ PUBLIC ROUTES ============
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // ============ PROTECTED ROUTES (inside MainShell) ============
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        // ---- DASHBOARD ----
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardRouter(),
        ),

        // ---- FARMS ----
        GoRoute(
          path: '/farms',
          builder: (context, state) => const FarmsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddEditFarmScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => AddEditFarmScreen(
                farmId: state.pathParameters['id'],
              ),
            ),
          ],
        ),

        // ---- CROPS ----
        GoRoute(
          path: '/crops',
          builder: (context, state) => const CropsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddEditCropScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => AddEditCropScreen(
                cropId: state.pathParameters['id'],
              ),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) => CropDetailScreen(
                    cropId: state.pathParameters['id']!,
                  ),
                ),
                GoRoute(
                  path: 'activities/add',
                  builder: (context, state) => AddEditActivityScreen(
                    cropId: state.pathParameters['id']!,
                  ),
                ),
                GoRoute(
                  path: 'activities/:activityId/edit',
                  builder: (context, state) => AddEditActivityScreen(
                    cropId: state.pathParameters['id']!,
                    activityId: state.pathParameters['activityId'],
                  ),
                ),
              ],
            ),
          ],
        ),

        // ---- GREENHOUSES ----
        GoRoute(
          path: '/greenhouses',
          builder: (context, state) => const GreenhousesScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddEditGreenhouseScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => AddEditGreenhouseScreen(
                greenhouseId: state.pathParameters['id'],
              ),
            ),
            GoRoute(
              path: ':id/detail',
              builder: (context, state) => GreenhouseDetailScreen(
                greenhouseId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),

        // ---- HARVESTS ----
        GoRoute(
          path: '/harvests',
          builder: (context, state) => const HarvestsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddEditHarvestScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => AddEditHarvestScreen(
                harvestId: state.pathParameters['id'],
              ),
            ),
          ],
        ),

        // ---- SALES ----
        GoRoute(
          path: '/sales',
          builder: (context, state) => const SalesScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddEditSaleScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => AddEditSaleScreen(
                saleId: state.pathParameters['id'],
              ),
              routes: [
                GoRoute(
                  path: 'invoice',
                  builder: (context, state) => SaleInvoiceScreen(
                    saleId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        // ---- EXPENSES ----
        GoRoute(
          path: '/expenses',
          builder: (context, state) => const ExpensesScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddEditExpenseScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => AddEditExpenseScreen(
                expenseId: state.pathParameters['id'],
              ),
            ),
          ],
        ),

        // ---- LABOUR ----
        GoRoute(
          path: '/labour',
          builder: (context, state) => const LabourScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddEditLabourScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => AddEditLabourScreen(
                labourId: state.pathParameters['id'],
              ),
            ),
          ],
        ),

        // ---- REPORTS ----
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsHubScreen(),
          routes: [
            GoRoute(
              path: 'expense',
              builder: (context, state) => const ExpenseReportScreen(),
            ),
            GoRoute(
              path: 'sales',
              builder: (context, state) => const SalesReportScreen(),
            ),
            GoRoute(
              path: 'labour',
              builder: (context, state) => const LabourReportScreen(),
            ),
            GoRoute(
              path: 'financial',
              builder: (context, state) => const FinancialSummaryScreen(),
            ),
            GoRoute(
              path: 'harvest',
              builder: (context, state) => const HarvestReportScreen(),
            ),
            GoRoute(
              path: 'farm',
              builder: (context, state) => const FarmReportScreen(),
            ),
            GoRoute(
              path: 'crop',
              builder: (context, state) => const CropReportScreen(),
              routes: [
                GoRoute(
                  path: ':cropName/detail',
                  builder: (context, state) => CropReportDetailScreen(
                    cropName:
                        Uri.decodeComponent(state.pathParameters['cropName']!),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'greenhouse',
              builder: (context, state) => const GreenhouseReportScreen(),
            ),
          ],
        ),

        // ---- SETTINGS ----
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/payment-info',
          builder: (context, state) => const PaymentInfoScreen(),
        ),

        // ---- ADMIN ----
        GoRoute(
          path: '/admin/register-customer',
          builder: (context, state) => const RegisterCustomerScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
      ],
    ),
  ],

  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn = state.matchedLocation == '/login';

    if (user == null && !isLoggingIn) return '/login';
    if (user != null && isLoggingIn) return '/dashboard';
    return null;
  },

  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page Not Found')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No page found for: ${state.uri}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    ),
  ),
);
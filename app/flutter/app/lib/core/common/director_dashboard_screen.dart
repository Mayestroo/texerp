import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/presentation/production_entries_screen.dart';
import 'package:texerp/features/payroll/data/payroll_repository.dart';
import 'package:texerp/features/payroll/data/payroll_models.dart';

class DirectorDashboardScreen extends StatefulWidget {
  const DirectorDashboardScreen({super.key});

  @override
  State<DirectorDashboardScreen> createState() => _DirectorDashboardScreenState();
}

class _DirectorDashboardScreenState extends State<DirectorDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  ProductionSummary? _productionSummary;
  PayrollPeriod? _latestPeriod;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final productionRepo = context.read<ProductionRepository>();
      final payrollRepo = context.read<PayrollRepository>();

      final results = await Future.wait([
        productionRepo.fetchProductionSummary(),
        payrollRepo.fetchPeriods(limit: 1),
      ]);

      final summary = results[0] as ProductionSummary;
      final (periods, _) = results[1] as (List<PayrollPeriod>, int);

      if (!mounted) return;

      setState(() {
        _productionSummary = summary;
        _latestPeriod = periods.isNotEmpty ? periods.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT':
        return 'Qoralama';
      case 'CALCULATING':
        return 'Hisoblanmoqda';
      case 'CALCULATED':
        return 'Hisoblangan';
      case 'FINALIZED':
        return 'Yakunlangan';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return const Color(0xFFF59E0B);
      case 'CALCULATED':
        return const Color(0xFF0EA5E9);
      case 'FINALIZED':
        return AppColors.success;
      default:
        return AppColors.labelSecondary;
    }
  }

  String _formatCurrency(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
    return '$formatted so\'m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: _loadDashboardData,
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 12),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CupertinoActivityIndicator(radius: 14),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: AppColors.error,
                          size: 44,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ma\'lumotlarni yuklashda xatolik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 24),
                        CupertinoButton(
                          color: primaryColor,
                          onPressed: _loadDashboardData,
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildProductionCard(isDark),
                    const SizedBox(height: 16),
                    _buildPayrollCard(isDark),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionCard(bool isDark) {
    final summary = _productionSummary!;
    final today = DateTime.now();
    final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ProductionEntriesScreen(
              dateFrom: dateStr,
              dateTo: dateStr,
            ),
          ),
        );
      },
      child: Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(23),
                topRight: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.hammer_fill, color: CupertinoColors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kunlik ishlab chiqarish',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          inherit: true,
                        ),
                      ),
                      Text(
                        'Joriy kun statistikasi',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white,
                          inherit: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      summary.todayEntriesCount.toString(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: CupertinoColors.white,
                        inherit: true,
                      ),
                    ),
                    Text(
                      'yozuvlar',
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.white.withOpacity(0.8),
                        inherit: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 12,
                childAspectRatio: 2.8,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                final details = [
                  _StatDetail(label: 'Bugungi miqdor', value: summary.todayTotalQuantity.toString(), color: const Color(0xFF0EA5E9)),
                  _StatDetail(label: 'Kutilayotgan', value: summary.pendingEntriesCount.toString(), color: const Color(0xFFF59E0B)),
                  _StatDetail(label: 'Tasdiqlangan', value: summary.approvedEntriesCount.toString(), color: AppColors.success),
                  _StatDetail(label: 'Rad etilgan', value: summary.rejectedEntriesCount.toString(), color: AppColors.error),
                ];
                final detail = details[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: detail.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              detail.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                fontWeight: FontWeight.w500,
                                inherit: true,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail.value,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                fontWeight: FontWeight.w800,
                                inherit: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPayrollCard(bool isDark) {
    final period = _latestPeriod;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(23),
                topRight: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.money_dollar_circle_fill, color: CupertinoColors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ish haqi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          inherit: true,
                        ),
                      ),
                      Text(
                        'Oxirgi ish haqi davri',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white,
                          inherit: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (period != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(period.status).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(period.status),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.white,
                        inherit: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (period != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.8,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final details = [
                    _StatDetail(label: 'Davr nomi', value: period.name, color: const Color(0xFF0EA5E9)),
                    _StatDetail(label: 'Ishchilar soni', value: period.workerCount.toString(), color: const Color(0xFF8B5CF6)),
                    _StatDetail(label: 'Yalpi summa', value: _formatCurrency(period.totalGross), color: const Color(0xFFF59E0B)),
                    _StatDetail(label: 'To\'lanadigan', value: _formatCurrency(period.totalFinal), color: AppColors.success),
                  ];
                  final detail = details[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: detail.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                detail.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                  fontWeight: FontWeight.w500,
                                  inherit: true,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                detail.value,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                  fontWeight: FontWeight.w800,
                                  inherit: true,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Hozircha ish haqi davri yo\'q',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                  inherit: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatDetail {
  const _StatDetail({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

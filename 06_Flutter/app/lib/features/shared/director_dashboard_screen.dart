import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/production/data/production_models.dart';

class DirectorDashboardScreen extends StatefulWidget {
  const DirectorDashboardScreen({super.key});

  @override
  State<DirectorDashboardScreen> createState() => _DirectorDashboardScreenState();
}

class _DirectorDashboardScreenState extends State<DirectorDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  int _totalWorkers = 0;
  int _activeWorkers = 0;
  int _deactivatedWorkers = 0;
  int _foremenCount = 0;
  int _workersCount = 0;

  int _totalDepartments = 0;
  int _activeDepartments = 0;
  int _deactivatedDepartments = 0;

  int _totalOperations = 0;
  int _activeOperations = 0;
  int _deactivatedOperations = 0;

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
      final profileRepo = context.read<ProfileRepository>();
      final productionRepo = context.read<ProductionRepository>();

      final results = await Future.wait([
        profileRepo.fetchUsers(status: 'ALL'),
        profileRepo.fetchDepartments(includeInactive: true),
        productionRepo.fetchOperations(status: 'ALL'),
      ]);

      final (users, _) = results[0] as (List<UserProfile>, int);
      final departments = results[1] as List<Department>;
      final operations = results[2] as List<Operation>;

      if (!mounted) return;

      setState(() {
        _totalWorkers = users.length;
        _activeWorkers = users.where((u) => u.status == 'ACTIVE').length;
        _deactivatedWorkers = users.where((u) => u.status == 'DEACTIVATED').length;
        _foremenCount = users.where((u) => u.role == 'FOREMAN').length;
        _workersCount = users.where((u) => u.role == 'WORKER').length;

        _totalDepartments = departments.length;
        _activeDepartments = departments.where((d) => d.isActive ?? true).length;
        _deactivatedDepartments = departments.where((d) => !(d.isActive ?? true)).length;

        _totalOperations = operations.length;
        _activeOperations = operations.where((o) => o.isActive).length;
        _deactivatedOperations = operations.where((o) => !o.isActive).length;

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

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
      'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
    ];
    return '${now.day}-${months[now.month - 1]}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: _loadDashboardData,
            ),
            // Header Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getFormattedDate().toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              letterSpacing: 1.1,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Xush kelibsiz,',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.labelDark.withOpacity(0.8) : AppColors.labelLight.withOpacity(0.8),
                              inherit: false,
                            ),
                          ),
                          Text(
                            user?.fullName ?? 'Direktor',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              inherit: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.person_solid,
                          color: CupertinoColors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                            inherit: false,
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
                    // Workers Stats Card
                    _buildStatsCard(
                      title: 'Ishchilar',
                      total: _totalWorkers,
                      subtitle: 'Jami xodimlar',
                      icon: CupertinoIcons.person_3_fill,
                      isDark: isDark,
                      colors: [
                        const Color(0xFF6366F1),
                        const Color(0xFF4F46E5),
                      ],
                      details: [
                        _StatDetail(label: 'Faol', value: _activeWorkers, color: AppColors.success),
                        _StatDetail(label: 'Faolsiz', value: _deactivatedWorkers, color: AppColors.error),
                        _StatDetail(label: 'Brigadirlar', value: _foremenCount, color: const Color(0xFF0EA5E9)),
                        _StatDetail(label: 'Ishchilar', value: _workersCount, color: const Color(0xFFF43F5E)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Departments Stats Card
                    _buildStatsCard(
                      title: 'Bo\'limlar',
                      total: _totalDepartments,
                      subtitle: 'Jami bo\'limlar',
                      icon: CupertinoIcons.square_grid_2x2_fill,
                      isDark: isDark,
                      colors: [
                        const Color(0xFF06B6D4),
                        const Color(0xFF0891B2),
                      ],
                      details: [
                        _StatDetail(label: 'Faol bo\'limlar', value: _activeDepartments, color: AppColors.success),
                        _StatDetail(label: 'Faolsiz bo\'limlar', value: _deactivatedDepartments, color: AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operations Stats Card
                    _buildStatsCard(
                      title: 'Katalog',
                      total: _totalOperations,
                      subtitle: 'Jami operatsiyalar',
                      icon: CupertinoIcons.rectangle_grid_2x2_fill,
                      isDark: isDark,
                      colors: [
                        const Color(0xFFF59E0B),
                        const Color(0xFFD97706),
                      ],
                      details: [
                        _StatDetail(label: 'Faol operatsiyalar', value: _activeOperations, color: AppColors.success),
                        _StatDetail(label: 'Faolsiz operatsiyalar', value: _deactivatedOperations, color: AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required int total,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required List<Color> colors,
    required List<_StatDetail> details,
  }) {
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
          // Card Header with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(23),
                topRight: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: CupertinoColors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          inherit: false,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white.withOpacity(0.8),
                          inherit: false,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  total.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: CupertinoColors.white,
                    inherit: false,
                  ),
                ),
              ],
            ),
          ),
          // Details Grid
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
              itemCount: details.length,
              itemBuilder: (context, index) {
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
                                inherit: false,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail.value.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                fontWeight: FontWeight.w800,
                                inherit: false,
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
  final int value;
  final Color color;
}

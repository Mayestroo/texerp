import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';
import 'package:texerp/features/reports/data/report_models.dart';
import 'package:texerp/features/reports/presentation/reports_bloc.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _filtersExpanded = true;

  List<UserProfile> _workers = const [];
  List<UserProfile> _foremen = const [];
  List<Operation> _operations = const [];
  bool _assistantsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAssistanceData();
    context.read<ReportsBloc>().add(const ReportsLoadRequested());
  }

  Future<void> _loadAssistanceData() async {
    setState(() => _assistantsLoading = true);
    try {
      final profileRepo = context.read<ProfileRepository>();
      final productionRepo = context.read<ProductionRepository>();
      final results = await Future.wait([
        profileRepo.fetchUsers(role: 'WORKER', status: 'ACTIVE', limit: 200),
        profileRepo.fetchUsers(role: 'FOREMAN', status: 'ACTIVE', limit: 200),
        productionRepo.fetchOperations(status: 'ACTIVE'),
      ]);
      final (workers, _) = results[0] as (List<UserProfile>, int);
      final (foremen, _) = results[1] as (List<UserProfile>, int);
      final operations = results[2] as List<Operation>;
      if (mounted) {
        setState(() {
          _workers = workers;
          _foremen = foremen;
          _operations = operations;
          _assistantsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _assistantsLoading = false);
      }
    }
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatMoney(int tiyin) {
    final som = tiyin / 100;
    final formatted = NumberFormat('#,##0.00').format(som);
    return '$formatted so\'m';
  }

  String _groupByLabel(String groupBy) {
    switch (groupBy) {
      case 'worker':
        return 'Ishchi';
      case 'operation':
        return 'Operatsiya';
      case 'date':
        return 'Sana';
      case 'foreman':
        return 'Brigadir';
      default:
        return groupBy;
    }
  }

  String _rowTitle(ReportRow row) {
    switch (row.groupBy) {
      case 'worker':
        return row.groupIdentity['full_name'] as String? ??
            row.groupIdentity['worker_code'] as String? ??
            'Noma\'lum ishchi';
      case 'foreman':
        return row.groupIdentity['full_name'] as String? ??
            'Noma\'lum brigadir';
      case 'operation':
        return row.groupIdentity['name'] as String? ??
            row.groupIdentity['code'] as String? ??
            'Noma\'lum operatsiya';
      case 'date':
        return row.groupIdentity['date']?.toString() ?? '-';
      default:
        return '-';
    }
  }

  String? _rowSubtitle(ReportRow row) {
    switch (row.groupBy) {
      case 'worker':
        final code = row.groupIdentity['worker_code'] as String?;
        return code != null && code.isNotEmpty ? 'Kod: $code' : null;
      case 'operation':
        final code = row.groupIdentity['code'] as String?;
        final unit = row.groupIdentity['unit'] as String?;
        final parts = <String>[];
        if (code != null && code.isNotEmpty) parts.add('Kod: $code');
        if (unit != null && unit.isNotEmpty) parts.add(unit);
        return parts.isEmpty ? null : parts.join(' • ');
      case 'foreman':
        return row.groupIdentity['phone'] as String?;
      default:
        return null;
    }
  }

  Color _groupColor(String groupBy) {
    switch (groupBy) {
      case 'worker':
        return const Color(0xFF6366F1);
      case 'operation':
        return const Color(0xFF0EA5E9);
      case 'date':
        return const Color(0xFFF59E0B);
      case 'foreman':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.primary;
    }
  }

  Future<void> _selectDate({required bool isFrom}) async {
    final bloc = context.read<ReportsBloc>();
    final current = isFrom ? bloc.state.dateFrom : bloc.state.dateTo;
    final initial = DateTime.tryParse(current) ?? DateTime.now();
    final selected = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => _DatePickerSheet(initialDate: initial),
    );
    if (selected == null) return;

    final dateStr = _formatDate(selected);
    bloc.add(ReportsFiltersChanged(
      dateFrom: isFrom ? dateStr : null,
      dateTo: isFrom ? null : dateStr,
    ));
  }

  void _showOptionPicker<T>({
    required String title,
    required List<T> items,
    required String Function(T) label,
    required String Function(T) id,
    String? selectedId,
    required ValueChanged<String?> onSelected,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E)
                : CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          'Bekor qilish',
                          style: TextStyle(fontSize: 15, inherit: true),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.labelDark
                              : AppColors.labelLight,
                          inherit: true,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          'Tozalash',
                          style: TextStyle(fontSize: 15, inherit: true),
                        ),
                        onPressed: () {
                          onSelected(null);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = id(item);
                      final isSelected = itemId == selectedId;
                      return CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          onSelected(itemId);
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CupertinoTheme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)
                                : null,
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFE5E5EA),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label(item),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? AppColors.labelDark
                                        : AppColors.labelLight,
                                    inherit: true,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  CupertinoIcons.check_mark,
                                  color: CupertinoTheme.of(context).primaryColor,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterCard(ReportsState state) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    final groupOptions = <String, Widget>{
      'worker': Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Ishchi',
          style: TextStyle(
            fontSize: 13,
            color: state.groupBy == 'worker'
                ? CupertinoColors.white
                : (isDark ? AppColors.labelDark : AppColors.labelLight),
            inherit: true,
          ),
        ),
      ),
      'operation': Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Operatsiya',
          style: TextStyle(
            fontSize: 13,
            color: state.groupBy == 'operation'
                ? CupertinoColors.white
                : (isDark ? AppColors.labelDark : AppColors.labelLight),
            inherit: true,
          ),
        ),
      ),
      'date': Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Sana',
          style: TextStyle(
            fontSize: 13,
            color: state.groupBy == 'date'
                ? CupertinoColors.white
                : (isDark ? AppColors.labelDark : AppColors.labelLight),
            inherit: true,
          ),
        ),
      ),
      'foreman': Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Brigadir',
          style: TextStyle(
            fontSize: 13,
            color: state.groupBy == 'foreman'
                ? CupertinoColors.white
                : (isDark ? AppColors.labelDark : AppColors.labelLight),
            inherit: true,
          ),
        ),
      ),
    };

    Widget optionTile({
      required String label,
      required String value,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.person,
                size: 18,
                color: isDark
                    ? AppColors.labelSecondary
                    : AppColors.secondaryLabelLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.labelSecondary
                            : AppColors.secondaryLabelLight,
                        inherit: true,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.labelDark
                            : AppColors.labelLight,
                        inherit: true,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_down,
                size: 14,
                color: isDark
                    ? AppColors.labelSecondary
                    : AppColors.secondaryLabelLight,
              ),
            ],
          ),
        ),
      );
    }

    final selectedWorker = state.workerId == null
        ? null
        : _workers.cast<UserProfile?>().firstWhere(
              (w) => w?.id == state.workerId,
              orElse: () => null,
            );
    final selectedForeman = state.foremanId == null
        ? null
        : _foremen.cast<UserProfile?>().firstWhere(
              (f) => f?.id == state.foremanId,
              orElse: () => null,
            );
    final selectedOperation = state.operationId == null
        ? null
        : _operations.cast<Operation?>().firstWhere(
              (o) => o?.id == state.operationId,
              orElse: () => null,
            );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 20,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Filtrlar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.labelDark : AppColors.labelLight,
                        inherit: true,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _filtersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: isDark
                          ? AppColors.labelSecondary
                          : AppColors.secondaryLabelLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date range
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(isFrom: true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0x1AFFFFFF)
                                    : const Color(0x0F000000),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.calendar,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.labelSecondary
                                      : AppColors.secondaryLabelLight,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.labelSecondary
                                            : AppColors.secondaryLabelLight,
                                        inherit: true,
                                      ),
                                    ),
                                    Text(
                                      state.dateFrom,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppColors.labelDark
                                            : AppColors.labelLight,
                                        inherit: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(isFrom: false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0x1AFFFFFF)
                                    : const Color(0x0F000000),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.calendar,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.labelSecondary
                                      : AppColors.secondaryLabelLight,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gacha',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.labelSecondary
                                            : AppColors.secondaryLabelLight,
                                        inherit: true,
                                      ),
                                    ),
                                    Text(
                                      state.dateTo,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppColors.labelDark
                                            : AppColors.labelLight,
                                        inherit: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Group by
                  Text(
                    'Guruhlash',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.labelSecondary
                          : AppColors.secondaryLabelLight,
                      inherit: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoSegmentedControl<String>(
                    groupValue: state.groupBy,
                    children: groupOptions,
                    onValueChanged: (value) => context
                        .read<ReportsBloc>()
                        .add(ReportsFiltersChanged(groupBy: value)),
                    padding: EdgeInsets.zero,
                    selectedColor: primaryColor,
                    borderColor: primaryColor,
                    unselectedColor: isDark
                        ? AppColors.cardDark
                        : AppColors.cardLight,
                  ),
                  const SizedBox(height: 16),

                  // Optional pickers
                  if (_assistantsLoading)
                    const Center(child: CupertinoActivityIndicator())
                  else ...[
                    optionTile(
                      label: 'Ishchi',
                      value: selectedWorker?.fullName ?? 'Barchasi',
                      onTap: () => _showOptionPicker<UserProfile>(
                        title: 'Ishchi tanlash',
                        items: _workers,
                        label: (u) => '${u.fullName} (${u.workerCode})',
                        id: (u) => u.id,
                        selectedId: state.workerId,
                        onSelected: (id) => context.read<ReportsBloc>().add(
                          ReportsFiltersChanged(workerId: id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    optionTile(
                      label: 'Brigadir',
                      value: selectedForeman?.fullName ?? 'Barchasi',
                      onTap: () => _showOptionPicker<UserProfile>(
                        title: 'Brigadir tanlash',
                        items: _foremen,
                        label: (u) => u.fullName,
                        id: (u) => u.id,
                        selectedId: state.foremanId,
                        onSelected: (id) => context.read<ReportsBloc>().add(
                          ReportsFiltersChanged(foremanId: id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    optionTile(
                      label: 'Operatsiya',
                      value: selectedOperation?.name ?? 'Barchasi',
                      onTap: () => _showOptionPicker<Operation>(
                        title: 'Operatsiya tanlash',
                        items: _operations,
                        label: (o) => o.name,
                        id: (o) => o.id,
                        selectedId: state.operationId,
                        onSelected: (id) => context.read<ReportsBloc>().add(
                          ReportsFiltersChanged(operationId: id),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Create report button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context
                        .read<ReportsBloc>()
                        .add(const ReportsLoadRequested()),
                    child: Container(
                      height: 50,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Hisobot yaratish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                          inherit: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _filtersExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    ProductionReport report,
    bool isDark,
    String groupBy,
  ) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
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
                const Icon(
                  CupertinoIcons.chart_bar_fill,
                  color: CupertinoColors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_groupByLabel(report.rows.isEmpty ? groupBy : report.rows.first.groupBy)} bo\'yicha',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          inherit: true,
                        ),
                      ),
                      Text(
                        '${report.period.from} ~ ${report.period.to}',
                        style: const TextStyle(
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
                      report.rows.length.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: CupertinoColors.white,
                        inherit: true,
                      ),
                    ),
                    Text(
                      'qatlam',
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
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Jami dona',
                    value: report.totalPieces.toString(),
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryStat(
                    label: 'Jami daromad',
                    value: _formatMoney(report.totalEarnings),
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowCard(ReportRow row, bool isDark, Color color) {
    final title = _rowTitle(row);
    final subtitle = _rowSubtitle(row);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _iconForGroup(row.groupBy),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.labelDark
                              : AppColors.labelLight,
                          inherit: true,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _RowStat(label: 'Dona', value: row.totalPieces.toString()),
                  Container(
                    width: 1,
                    height: 24,
                    color: isDark
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFE5E5EA),
                  ),
                  _RowStat(
                    label: 'Daromad',
                    value: _formatMoney(row.grossEarnings),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: isDark
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFE5E5EA),
                  ),
                  _RowStat(
                    label: 'Yozuvlar',
                    value: row.recordsCount.toString(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForGroup(String groupBy) {
    switch (groupBy) {
      case 'worker':
        return CupertinoIcons.person_fill;
      case 'operation':
        return CupertinoIcons.hammer_fill;
      case 'date':
        return CupertinoIcons.calendar;
      case 'foreman':
        return CupertinoIcons.person_2_fill;
      default:
        return CupertinoIcons.chart_bar_fill;
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.doc_text_search,
                size: 64,
                color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
              ),
              const SizedBox(height: 16),
              Text(
                'Ma\'lumot topilmadi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.labelDark : AppColors.labelLight,
                  inherit: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tanlangan davr va filtrlar bo\'yicha hisobot ma\'lumoti yo\'q.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.labelSecondary
                      : AppColors.secondaryLabelLight,
                  inherit: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(ReportsState state) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    if (state.isExporting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? const Color(0x33FFFFFF) : const Color(0x15000000),
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(color: primaryColor),
            const SizedBox(width: 10),
            Text(
              state.exportStatus?.status == 'GENERATING'
                  ? 'Excel tayyorlanmoqda...'
                  : 'Yuklanmoqda...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                inherit: true,
              ),
            ),
          ],
        ),
      );
    }

    if (state.exportStatus?.status == 'READY') {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          final url = state.exportStatus?.downloadUrl;
          if (url != null) {
            AppToast.show(
              context,
              message: url,
              type: ToastType.success,
              duration: const Duration(seconds: 5),
            );
          }
          context.read<ReportsBloc>().add(const ReportsExportReset());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: CupertinoColors.white,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Yuklash havolasi tayyor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                  inherit: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        context.read<ReportsBloc>().add(const ReportsExportRequested());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.arrow_down_doc_fill,
              color: CupertinoColors.white,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Excel yuklash',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
                inherit: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocConsumer<ReportsBloc, ReportsState>(
      listener: (context, state) {
        if (state.error != null) {
          AppToast.show(context, message: state.error!);
          context.read<ReportsBloc>().add(const ReportsFiltersChanged());
        }
        if (state.exportError != null) {
          AppToast.show(
            context,
            message: state.exportError!,
            type: ToastType.error,
          );
          context.read<ReportsBloc>().add(const ReportsExportReset());
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async {
                    context
                        .read<ReportsBloc>()
                        .add(const ReportsLoadRequested(refresh: true));
                  },
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildFilterCard(state),
                      if (state.isLoading && state.report == null)
                        const SizedBox(
                          height: 200,
                          child: Center(
                            child: CupertinoActivityIndicator(radius: 14),
                          ),
                        )
                      else if (state.report != null) ...[
                        _buildSummaryCard(state.report!, isDark, state.groupBy),
                        if (state.report!.rows.isEmpty)
                          const SizedBox(height: 40),
                        ...state.report!.rows.map((row) {
                          return _buildRowCard(
                            row,
                            isDark,
                            _groupColor(row.groupBy),
                          );
                        }),
                      ],
                    ]),
                  ),
                ),
                if (state.report != null && state.report!.rows.isEmpty)
                  _buildEmptyState(isDark),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(child: _buildExportButton(state)),
            ),
          ],
        );
      },
    );
  }
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1E)
            : CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      'Bekor qilish',
                      style: TextStyle(fontSize: 15, inherit: true),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      'Tanlash',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        inherit: true,
                      ),
                    ),
                    onPressed: () => Navigator.of(context)
                        .pop<DateTime>(_selected),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: _selected,
                mode: CupertinoDatePickerMode.date,
                minimumDate: DateTime(2020),
                maximumDate: DateTime(2035),
                onDateTimeChanged: (d) => setState(() => _selected = d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Tanlangan: ${_formatDate(_selected)}',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.labelSecondary
                      : AppColors.secondaryLabelLight,
                  inherit: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              color: color,
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
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.labelSecondary
                        : AppColors.secondaryLabelLight,
                    fontWeight: FontWeight.w500,
                    inherit: true,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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
  }
}

class _RowStat extends StatelessWidget {
  const _RowStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.labelDark : AppColors.labelLight,
              inherit: true,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.labelSecondary
                  : AppColors.secondaryLabelLight,
              inherit: true,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

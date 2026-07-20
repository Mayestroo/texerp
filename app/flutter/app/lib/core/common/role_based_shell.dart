import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/core/common/placeholder_screen.dart';
import 'package:texerp/core/common/director_dashboard_screen.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:texerp/features/production/presentation/production_bloc.dart';
import 'package:texerp/features/production/presentation/submit_entry_screen.dart';
import 'package:texerp/features/production/presentation/entry_history_screen.dart';
import 'package:texerp/features/production/presentation/foreman_queue_bloc.dart';
import 'package:texerp/features/production/presentation/foreman_queue_screen.dart';
import 'package:texerp/features/production/presentation/foreman_history_screen.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';
import 'package:texerp/features/profile/presentation/team_bloc.dart';
import 'package:texerp/features/profile/presentation/team_screen.dart';

import 'package:texerp/features/payroll/data/payroll_repository.dart';
import 'package:texerp/features/payroll/presentation/payroll_bloc.dart';
import 'package:texerp/features/payroll/presentation/payroll_period_list_screen.dart';
import 'package:texerp/features/payroll/presentation/worker_payroll_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class _RoleTab {
  const _RoleTab({required this.label, required this.icon, this.activeIcon, required this.title});

  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String title;
}

class WorkerHomeScreen extends StatelessWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductionBloc(
        productionRepository: context.read<ProductionRepository>(),
      ),
      child: const _RoleBasedShell(role: 'WORKER'),
    );
  }
}

class ForemanHomeScreen extends StatelessWidget {
  const ForemanHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ForemanQueueBloc(
            productionRepository: context.read<ProductionRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => TeamBloc(
            profileRepository: context.read<ProfileRepository>(),
          ),
        ),
      ],
      child: const _RoleBasedShell(role: 'FOREMAN'),
    );
  }
}

class AccountantHomeScreen extends StatelessWidget {
  const AccountantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PayrollBloc(
        payrollRepository: context.read<PayrollRepository>(),
      ),
      child: const _RoleBasedShell(role: 'ACCOUNTANT'),
    );
  }
}

class DirectorHomeScreen extends StatelessWidget {
  const DirectorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RoleBasedShell(role: 'DIRECTOR');
  }
}

class _RoleBasedShell extends StatefulWidget {
  const _RoleBasedShell({required this.role, this.initialIndex = 0});

  final String role;
  final int initialIndex;

  @override
  State<_RoleBasedShell> createState() => _RoleBasedShellState();
}

class _RoleBasedShellState extends State<_RoleBasedShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  List<_RoleTab> _tabs(AppLocalizations l10n) {
    switch (widget.role) {
      case 'FOREMAN':
        return [
          _RoleTab(label: l10n.home, icon: CupertinoIcons.square_grid_2x2, activeIcon: CupertinoIcons.square_grid_2x2_fill, title: l10n.home),
          _RoleTab(label: l10n.queue, icon: CupertinoIcons.square_list, activeIcon: CupertinoIcons.square_list_fill, title: l10n.queue),
          _RoleTab(label: l10n.history, icon: CupertinoIcons.clock, activeIcon: CupertinoIcons.clock_fill, title: l10n.history),
          _RoleTab(label: l10n.team, icon: CupertinoIcons.person_2, activeIcon: CupertinoIcons.person_2_fill, title: l10n.team),
        ];
      case 'ACCOUNTANT':
        return [
          _RoleTab(label: l10n.home, icon: CupertinoIcons.chart_pie, activeIcon: CupertinoIcons.chart_pie_fill, title: l10n.home),
          _RoleTab(label: l10n.periods, icon: CupertinoIcons.calendar, activeIcon: CupertinoIcons.calendar_today, title: l10n.periods),
          _RoleTab(label: l10n.records, icon: CupertinoIcons.doc_on_doc, activeIcon: CupertinoIcons.doc_on_doc_fill, title: l10n.records),
        ];
      case 'DIRECTOR':
        return [
          _RoleTab(label: l10n.home, icon: CupertinoIcons.house, activeIcon: CupertinoIcons.house_fill, title: l10n.home),
        ];
      case 'WORKER':
      default:
        return [
          _RoleTab(label: l10n.home, icon: CupertinoIcons.house, activeIcon: CupertinoIcons.house_fill, title: l10n.home),
          _RoleTab(label: l10n.submit, icon: CupertinoIcons.plus_rectangle_on_rectangle, activeIcon: CupertinoIcons.plus_rectangle_fill_on_rectangle_fill, title: l10n.submit),
          _RoleTab(label: l10n.history, icon: CupertinoIcons.time, activeIcon: CupertinoIcons.time_solid, title: l10n.history),
          _RoleTab(label: l10n.periods, icon: CupertinoIcons.money_dollar, activeIcon: CupertinoIcons.money_dollar_circle_fill, title: 'Maosh'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = _tabs(l10n);
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final tab = tabs[_currentIndex];
    
    // Using a primary solid color
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: List.generate(tabs.length, (index) {
                final t = tabs[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 90, bottom: 90), // Make room for top and bottom floating bars
                  child: _buildTabContent(widget.role, index, t),
                );
              }),
            ),
            // Top Floating Navbar
            Positioned(
              top: 12,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? const Color(0xFF1C1C1E).withOpacity(0.65)
                          : const Color(0xFFFFFFFF).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark 
                            ? const Color(0x33FFFFFF)
                            : const Color(0x33000000),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _currentIndex == 0 ? (user?.fullName ?? l10n.appTitle) : tab.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              inherit: true,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 36,
                          child: Icon(
                            CupertinoIcons.bell, 
                            size: 22,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          ),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 36,
                          child: Icon(
                            CupertinoIcons.person_crop_circle, 
                            size: 26,
                            color: primaryColor,
                          ),
                          onPressed: () => context.push('/profile'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom Floating Custom Tabbar (User's Capsule Design)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom > 0 
                      ? MediaQuery.of(context).padding.bottom + 8 
                      : 24,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: tabs.length * 90.0 + 14.0,
                      height: 68,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? const Color(0xFF1C1C1E).withOpacity(0.75)
                            : const Color(0xFFFFFFFF).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: isDark 
                              ? const Color(0x22FFFFFF)
                              : const Color(0x15000000),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(isDark ? 0.3 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Sliding Background Indicator
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOutCubic,
                            left: _currentIndex * 90.0 + 7.0,
                            top: 7.0,
                            bottom: 7.0,
                            width: 90.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                          // Tab Items Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(tabs.length, (index) {
                                final isSelected = index == _currentIndex;
                                final item = tabs[index];

                                return GestureDetector(
                                  onTap: () => setState(() => _currentIndex = index),
                                  behavior: HitTestBehavior.opaque,
                                  child: SizedBox(
                                    width: 90.0,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                                          color: isSelected 
                                              ? primaryColor 
                                              : (isDark ? AppColors.secondaryLabelDark : AppColors.secondaryLabelLight),
                                          size: 22,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            color: isSelected 
                                                ? primaryColor 
                                                : (isDark ? AppColors.secondaryLabelDark : AppColors.secondaryLabelLight),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            inherit: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String role, int index, _RoleTab tab) {
    if (role == 'WORKER') {
      if (index == 1) {
        return const SubmitEntryScreen();
      } else if (index == 2) {
        return const EntryHistoryScreen();
      } else if (index == 3) {
        return BlocProvider(
          create: (context) => PayrollBloc(
            payrollRepository: context.read<PayrollRepository>(),
          ),
          child: const WorkerPayrollScreen(),
        );
      }
    } else if (role == 'FOREMAN') {
      if (index == 1) {
        return const ForemanQueueScreen();
      } else if (index == 2) {
        return const ForemanHistoryScreen();
      } else if (index == 3) {
        return const TeamScreen();
      }
    } else if (role == 'ACCOUNTANT') {
      if (index == 1) {
        return const PayrollPeriodListScreen();
      }
    } else if (role == 'DIRECTOR') {
      if (index == 0) {
        return const DirectorDashboardScreen();
      }
    }
    return PlaceholderScreen(title: tab.title);
  }
}

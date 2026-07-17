import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/features/shared/placeholder_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Bottom-navigation wrapper that shows role-appropriate tabs.
class RoleBasedShell extends StatefulWidget {
  const RoleBasedShell({
    required this.role,
    super.key,
    this.initialIndex = 0,
  });

  final String role;
  final int initialIndex;

  @override
  State<RoleBasedShell> createState() => _RoleBasedShellState();
}

class _RoleBasedShellState extends State<RoleBasedShell> {
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
          _RoleTab(label: l10n.home, icon: Icons.home_outlined, title: l10n.home),
          _RoleTab(label: l10n.queue, icon: Icons.pending_actions_outlined, title: l10n.queue),
          _RoleTab(label: l10n.team, icon: Icons.people_outline, title: l10n.team),
        ];
      case 'ACCOUNTANT':
        return [
          _RoleTab(label: l10n.home, icon: Icons.home_outlined, title: l10n.home),
          _RoleTab(label: l10n.periods, icon: Icons.calendar_month_outlined, title: l10n.periods),
          _RoleTab(label: l10n.records, icon: Icons.receipt_long_outlined, title: l10n.records),
        ];
      case 'DIRECTOR':
        return [
          _RoleTab(label: l10n.home, icon: Icons.home_outlined, title: l10n.home),
          _RoleTab(label: l10n.workers, icon: Icons.people_outlined, title: l10n.workers),
          _RoleTab(label: l10n.catalog, icon: Icons.list_alt_outlined, title: l10n.catalog),
        ];
      case 'WORKER':
      default:
        return [
          _RoleTab(label: l10n.home, icon: Icons.home_outlined, title: l10n.home),
          _RoleTab(label: l10n.submit, icon: Icons.add_circle_outline, title: l10n.submit),
          _RoleTab(label: l10n.history, icon: Icons.history, title: l10n.history),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = _tabs(l10n);
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.fullName ?? l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: l10n.notifications,
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs
            .map((tab) => PlaceholderScreen(title: tab.title))
            .toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RoleTab {
  const _RoleTab({required this.label, required this.icon, required this.title});

  final String label;
  final IconData icon;
  final String title;
}

/// Minimal worker home screen that hosts the role-based shell.
class WorkerHomeScreen extends StatelessWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleBasedShell(role: 'WORKER');
  }
}

/// Minimal foreman home screen that hosts the role-based shell.
class ForemanHomeScreen extends StatelessWidget {
  const ForemanHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleBasedShell(role: 'FOREMAN');
  }
}

/// Minimal accountant home screen that hosts the role-based shell.
class AccountantHomeScreen extends StatelessWidget {
  const AccountantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleBasedShell(role: 'ACCOUNTANT');
  }
}

/// Minimal director home screen that hosts the role-based shell.
class DirectorHomeScreen extends StatelessWidget {
  const DirectorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleBasedShell(role: 'DIRECTOR');
  }
}

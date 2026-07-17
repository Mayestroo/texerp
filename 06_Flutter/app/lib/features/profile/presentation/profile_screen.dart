import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/profile/presentation/profile_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const ProfileLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProfileFailure) {
            return _ErrorView(message: state.error);
          }
          if (state is ProfileLoaded) {
            return _ProfileContent(user: state.user);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _AvatarHeader(name: user.fullName),
        const SizedBox(height: 16),
        _InfoCard(user: user),
        if (user.department != null) _DepartmentCard(user: user),
        _LanguageCard(),
        _SecurityCard(),
        _VersionCard(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton(
            onPressed: () => _showLogoutDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            child: Text(l10n.logout),
          ),
        ),
      ],
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirm),
        content: Text(l10n.logoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirmLogout),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProfileBloc>().add(const ProfileLogoutRequested());
    }
  }
}

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return Center(
      child: CircleAvatar(
        radius: 48,
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          initial,
          style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: l10n.fullName, value: user.fullName),
            _InfoRow(label: l10n.phone, value: user.phone),
            _InfoRow(label: l10n.workerCode, value: user.workerCode),
            const SizedBox(height: 8),
            Chip(label: Text(_roleLabel(l10n, user.role))),
          ],
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, String role) {
    switch (role) {
      case 'WORKER':
        return l10n.worker;
      case 'FOREMAN':
        return l10n.foreman_role;
      case 'ACCOUNTANT':
        return l10n.accountant;
      case 'DIRECTOR':
        return l10n.director;
      default:
        return role;
    }
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              label: l10n.department,
              value: user.department?.name ?? '-',
            ),
            if (user.role == 'WORKER' && user.foreman != null)
              _InfoRow(
                label: l10n.foreman,
                value: user.foreman!.fullName,
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeCubit = context.watch<LocaleCubit>();
    final isUz = localeCubit.state.languageCode == 'uz';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(l10n.language),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: isUz ? null : () => localeCubit.setLocale(const Locale('uz')),
              child: Text(l10n.languageUz),
            ),
            TextButton(
              onPressed: isUz ? () => localeCubit.setLocale(const Locale('ru')) : null,
              child: Text(l10n.languageRu),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(l10n.changePin),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/profile/change-pin'),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(l10n.version),
        trailing: const Text('1.0.0'),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<ProfileBloc>().add(const ProfileLoadRequested()),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/config/settings_rows.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';

/// Ajustes del mayor: filas grandes que llevan a subpantallas (settings_rows.dart).
/// Con [group], las filas de ese grupo.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.group});

  final SettingsGroup? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final textScale = user?.preferences.textSizeMultiplier ?? 1.0;
    final group = this.group;
    final List<SettingsEntry> entries = user == null
        ? const []
        : group != null
            ? group.visibleRows(user)
            : visibleSettingsEntries(user);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
            child: user == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                    // El título es el primer elemento de la lista.
                    itemCount: entries.length + 1,
                    // Separación entre filas para evitar toques erróneos.
                    separatorBuilder: (_, __) => const SizedBox(height: 24),
                    itemBuilder: (context, index) => index == 0
                        ? ElderScreenTitle(group?.title ?? 'Ajustes',
                            textScale: textScale)
                        : _SettingsEntryTile(
                            entry: entries[index - 1],
                            value: entries[index - 1].subtitleFor(user),
                            textScale: textScale,
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsEntryTile extends StatelessWidget {
  const _SettingsEntryTile({
    required this.entry,
    required this.value,
    required this.textScale,
  });

  final SettingsEntry entry;
  final String value;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${entry.title}: $value',
      child: Material(
        color: AppTheme.elderSurface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: () => context.push(entry.route),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTheme.emergencyButtonMinHeight,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.elderPrimary, width: 2),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: TextStyle(
                          fontSize: AppTheme.fontButton * textScale,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.elderTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Vacío explícito ("Sin configurar"), nunca una fila en blanco.
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: AppTheme.fontButton * textScale,
                          color: AppTheme.elderTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 48,
                  color: AppTheme.elderPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/config/settings_rows.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';

/// Shell de ajustes del mayor: una lista de filas grandes que enrutan a
/// subpantallas. No tiene modelo, repositorio ni estado propio — los campos
/// que edita viven donde les corresponde y se escriben por sus repositorios.
/// Las filas y su visibilidad vienen de core/config/settings_rows.dart, la
/// misma fuente que decide si HomeScreen muestra el botón de ajustes.
///
/// Sin [group] es el menú de Ajustes; con él, la lista de filas de ese grupo.
/// Es la misma pantalla para que un grupo se vea y se toque igual que el menú.
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
                    // Separación explícita entre filas: son destinos táctiles
                    // grandes y contiguos, y pegadas invitan al toque erróneo.
                    // Mismo hueco que entre los botones de EmergencyScreen.
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
                      // Vacío explícito y accionable ("Sin configurar"),
                      // nunca fila en blanco ni deshabilitada.
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

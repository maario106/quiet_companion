import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/config/settings_rows.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Shell de ajustes del mayor: una lista de filas grandes que enrutan a
/// subpantallas. No tiene modelo, repositorio ni estado propio — los campos
/// que edita viven donde les corresponde y se escriben por sus repositorios.
/// Las filas y su visibilidad vienen de core/config/settings_rows.dart, la
/// misma fuente que decide si HomeScreen muestra el botón de ajustes.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final textScale = user?.preferences.textSizeMultiplier ?? 1.0;
    final rows = user == null ? const <SettingsRow>[] : visibleSettingsRows(user);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ajustes',
          style: TextStyle(
            fontSize: AppTheme.fontMedium * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
            child: user == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                    itemCount: rows.length,
                    // Separación explícita entre filas: son destinos táctiles
                    // grandes y contiguos, y pegadas invitan al toque erróneo.
                    // Mismo hueco que entre los botones de EmergencyScreen.
                    separatorBuilder: (_, __) => const SizedBox(height: 24),
                    itemBuilder: (context, index) => _SettingsRowTile(
                      row: rows[index],
                      value: rows[index].value(user),
                      textScale: textScale,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRowTile extends StatelessWidget {
  const _SettingsRowTile({
    required this.row,
    required this.value,
    required this.textScale,
  });

  final SettingsRow row;
  final String value;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${row.title}: $value',
      child: Material(
        color: AppTheme.elderSurface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: () => context.push(row.route),
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
                        row.title,
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

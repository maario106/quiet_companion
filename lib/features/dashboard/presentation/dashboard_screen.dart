import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/providers/linked_elder_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/sign_out_button.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_controller.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_state.dart';
import 'package:quiet_companion/features/dashboard/presentation/conversation_settings_card.dart';
import 'package:quiet_companion/features/dashboard/presentation/conversation_status_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Los datos del mayor, en vivo: lo que él cambie desde su móvil aparece
    // aquí sin recargar (ADR-0027).
    final elder = ref.watch(linkedElderProvider);

    ref.listen<DashboardState>(dashboardControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      ref.read(dashboardControllerProvider.notifier).clearError();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de control'),
        actions: const [SignOutButton()],
      ),
      body: elder.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const _CenteredMessage(
          'No se han podido cargar los datos del mayor.',
          isError: true,
        ),
        data: (linkedElder) => linkedElder == null
            ? const _CenteredMessage('No hay ningún mayor vinculado.')
            : _DashboardContent(elder: linkedElder),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: TextStyle(
            color: isError
                ? AppTheme.companionError
                : AppTheme.companionTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final UserModel elder;
  const _DashboardContent({required this.elder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = elder.preferences;
    final padding = AppTheme.screenPadding(context);
    final maxWidth = AppTheme.contentMaxWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ElderNameCard(elder: elder),
              ConversationStatusCard(elder: elder),
              ConversationSettingsCard(elder: elder),
              const SizedBox(height: 8),
              const Text(
                'Preferencias de voz y texto',
                style: TextStyle(
                  fontSize: AppTheme.companionFontTitle,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.companionTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _SettingSlider(
                        label: 'Volumen de la voz',
                        icon: Icons.volume_up_outlined,
                        value: prefs.volume,
                        onChangeEnd: (val) => ref
                            .read(dashboardControllerProvider.notifier)
                            .updateElderPreference(
                                UserPreferences.volumeKey, val),
                      ),
                      const Divider(height: 1),
                      _SettingSlider(
                        label: 'Velocidad del habla',
                        icon: Icons.speed_outlined,
                        value: prefs.speechRate,
                        min: 0.1,
                        max: 1.0,
                        onChangeEnd: (val) => ref
                            .read(dashboardControllerProvider.notifier)
                            .updateElderPreference(
                                UserPreferences.speechRateKey, val),
                      ),
                      const Divider(height: 1),
                      _SettingSlider(
                        label: 'Tamaño del texto',
                        icon: Icons.text_fields_outlined,
                        value: prefs.textSizeMultiplier,
                        min: 1.0,
                        max: 2.0,
                        onChangeEnd: (val) => ref
                            .read(dashboardControllerProvider.notifier)
                            .updateElderPreference(
                                UserPreferences.textSizeMultiplierKey, val),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElderNameCard extends ConsumerStatefulWidget {
  final UserModel elder;
  const _ElderNameCard({required this.elder});

  @override
  ConsumerState<_ElderNameCard> createState() => _ElderNameCardState();
}

class _ElderNameCardState extends ConsumerState<_ElderNameCard> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.elder.name ?? '');
  }

  @override
  void didUpdateWidget(covariant _ElderNameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync field when Firestore pushes a new name (e.g. set by Gemini).
    if (!_editing && widget.elder.name != oldWidget.elder.name) {
      _controller.text = widget.elder.name ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    ref
        .read(dashboardControllerProvider.notifier)
        .updateElderName(_controller.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: AppTheme.companionPrimary),
                const SizedBox(width: 12),
                const Text(
                  'Nombre del mayor',
                  style: TextStyle(
                    fontSize: AppTheme.companionFontTitle,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.companionTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_editing) ...[
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: AppTheme.companionFontBody,
                  color: AppTheme.companionTextPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Escribe el nombre',
                  hintStyle: TextStyle(
                    fontSize: AppTheme.companionFontBody,
                    color: AppTheme.companionTextSecondary,
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          _controller.text = widget.elder.name ?? '';
                          setState(() => _editing = false);
                        },
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Guardar'),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.elder.name?.isNotEmpty == true
                          ? widget.elder.name!
                          : 'Sin nombre (lo aprende por voz)',
                      style: TextStyle(
                        fontSize: AppTheme.companionFontBody,
                        color: widget.elder.name?.isNotEmpty == true
                            ? AppTheme.companionTextPrimary
                            : AppTheme.companionTextSecondary,
                        fontStyle: widget.elder.name?.isNotEmpty == true
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      color: AppTheme.companionPrimary,
                      iconSize: 28,
                      onPressed: () => setState(() => _editing = true),
                      tooltip: 'Editar nombre',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingSlider extends StatefulWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChangeEnd;

  const _SettingSlider({
    required this.label,
    required this.icon,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.onChangeEnd,
  });

  @override
  State<_SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<_SettingSlider> {
  late double _localValue;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SettingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.value != oldWidget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(widget.icon,
              size: 20, color: AppTheme.companionTextSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: AppTheme.companionFontBody,
                    color: AppTheme.companionTextPrimary,
                  ),
                ),
                Slider(
                  value: _localValue,
                  min: widget.min,
                  max: widget.max,
                  divisions: 10,
                  label: _localValue.toStringAsFixed(1),
                  onChanged: (val) {
                    setState(() {
                      _isDragging = true;
                      _localValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    setState(() {
                      _isDragging = false;
                      _localValue = val;
                    });
                    widget.onChangeEnd(val);
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              _localValue.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: AppTheme.companionFontLabel,
                color: AppTheme.companionTextSecondary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

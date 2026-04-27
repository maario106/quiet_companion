import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_controller.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_state.dart';
import 'package:quiet_companion/core/models/user_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Control Familiar')),
      body: state.status == DashboardStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : state.status == DashboardStatus.error
          ? Center(child: Text(state.errorMessage))
          : _DashboardContent(elder: state.linkedElder!),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final UserModel elder;
  const _DashboardContent({required this.elder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = elder.preferences;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuración para: ${elder.id.substring(0, 5)}...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),

          _SettingSlider(
            label: 'Volumen de la voz',
            value: prefs.volume,
            onChanged: (val) {
              ref.read(dashboardControllerProvider.notifier)
                  .updateElderPreferences(prefs.copyWith(volume: val));
            },
          ),

          _SettingSlider(
            label: 'Velocidad del habla (TTS)',
            value: prefs.speechRate,
            min: 0.1,
            max: 1.0,
            onChanged: (val) {
              ref.read(dashboardControllerProvider.notifier)
                  .updateElderPreferences(prefs.copyWith(speechRate: val));
            },
          ),

          _SettingSlider(
            label: 'Tamaño del texto',
            value: prefs.textSizeMultiplier,
            min: 1.0,
            max: 2.0,
            onChanged: (val) {
              ref.read(dashboardControllerProvider.notifier)
                  .updateElderPreferences(prefs.copyWith(textSizeMultiplier: val));
            },
          ),
        ],
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
    required this.label,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 10,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
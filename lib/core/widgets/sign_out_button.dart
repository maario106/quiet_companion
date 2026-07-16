import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';

class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
        try {
          await ref.read(authRepositoryProvider).signOut();
        } catch (_) {
          // Router handles the redirect reactively via firebaseAuthUserProvider.
        }
      },
    );
  }
}

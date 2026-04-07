import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../ui/ui.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  Future<void> _sair(BuildContext context) async {
    final bool confirmar = await AppConfirmDialog.show(
      context,
      title: 'Sair da conta',
      message: 'Deseja encerrar a sessão neste dispositivo?',
    );

    if (!confirmar) {
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  String _nomeExibicao(User user, Map<String, dynamic>? perfil) {
    final String nomePerfil = (perfil?['nome'] ?? '').toString().trim();
    if (nomePerfil.isNotEmpty) {
      return nomePerfil;
    }

    final String nomeAuth = (user.displayName ?? '').trim();
    if (nomeAuth.isNotEmpty) {
      return nomeAuth;
    }

    final String email = (user.email ?? '').trim();
    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'Usuario';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final DocumentReference<Map<String, dynamic>> perfilRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: perfilRef.snapshots(),
          builder: (context, snapshot) {
            final Map<String, dynamic>? perfil = snapshot.data?.data();
            final String nome = _nomeExibicao(user, perfil);
            final String email = (user.email ?? '').trim().isEmpty
                ? 'Sem e-mail'
                : user.email!.trim();
            final String workspaceId = (perfil?['workspaceId'] ?? user.uid)
                .toString();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_circle_outlined, size: 26),
                        SizedBox(width: AppSpacing.s8),
                        Text(
                          'Perfil',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(email, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: AppSpacing.s4),

                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Workspace: $workspaceId',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.s12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _sair(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

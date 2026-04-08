import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/features/perfil/data/services/perfil_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final PerfilService _perfilService = PerfilService();

  Future<void> _sair(BuildContext context) async {
    final bool confirmar = await AppConfirmDialog.show(
      context,
      title: 'Sair da conta',
      message: 'Deseja encerrar a sessão neste dispositivo?',
    );

    if (!confirmar) {
      return;
    }

    await _perfilService.sair();
  }

  Future<void> _editarNome(
    BuildContext context, {
    required String uid,
    required String nomeAtual,
    required String? email,
  }) async {
    final TextEditingController nomeController = TextEditingController(
      text: nomeAtual,
    );

    final bool? salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar nome'),
          content: TextFormField(
            controller: nomeController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Nome exibido no app',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (salvar != true) {
      return;
    }

    final String novoNome = nomeController.text.trim();
    if (novoNome.length < 2) {
      if (!context.mounted) {
        return;
      }
      AppFeedback.showError(context, 'Informe um nome com ao menos 2 letras.');
      return;
    }

    try {
      await _perfilService.atualizarNomeExibicao(
        uid: uid,
        nome: novoNome,
        email: email,
      );
      if (!context.mounted) {
        return;
      }
      AppFeedback.showSuccess(context, 'Nome atualizado com sucesso.');
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      AppFeedback.showError(context, 'Não foi possível atualizar nome: $e');
    }
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
    final User? user = _perfilService.usuarioAtual;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String uid = user.uid;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        StreamBuilder<Map<String, dynamic>?>(
          stream: _perfilService.perfilUsuarioStream(uid),
          builder: (context, snapshot) {
            final Map<String, dynamic>? perfil = snapshot.data;
            final String nome = _nomeExibicao(user, perfil);
            final String email = (user.email ?? '').trim().isEmpty
                ? 'Sem e-mail'
                : user.email!.trim();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 26),
                        const SizedBox(width: AppSpacing.s8),
                        const Text(
                          'Perfil',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _editarNome(
                            context,
                            uid: uid,
                            nomeAtual: nome,
                            email: user.email,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar nome'),
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

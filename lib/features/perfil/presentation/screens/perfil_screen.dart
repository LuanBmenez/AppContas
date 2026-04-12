import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/features/perfil/data/services/perfil_service.dart'
    hide PerfilSyncException;
import 'package:paga_o_que_me_deve/features/perfil/domain/models/perfil_usuario.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final PerfilService _perfilService = PerfilService();

  bool _isInitializingProfile = false;
  bool _isSavingName = false;
  bool _isSigningOut = false;
  bool _redirectAgendado = false;

  final Set<String> _pendingActions = <String>{};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarPerfilSePossivel();
    });
  }

  Future<void> _inicializarPerfilSePossivel({
    bool showErrorFeedback = false,
  }) async {
    final User? user = _perfilService.usuarioAtual;
    if (user == null || _isInitializingProfile) {
      return;
    }

    setState(() {
      _isInitializingProfile = true;
    });

    try {
      await _perfilService.garantirDocumentoPerfil(user: user);

      try {
        await _perfilService.sincronizarNomeAuthComPerfil(uid: user.uid);
      } catch (_) {
        // silencioso
      }
    } catch (e) {
      if (!mounted || !showErrorFeedback) {
        return;
      }

      AppFeedback.showError(
        context,
        'Não foi possível preparar o perfil agora.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingProfile = false;
        });
      }
    }
  }

  void _agendarRedirecionamentoLogin() {
    if (_redirectAgendado) {
      return;
    }

    _redirectAgendado = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.go('/login');
    });
  }

  Future<void> _sair() async {
    if (_isSigningOut) {
      return;
    }

    final bool confirmar = await AppConfirmDialog.show(
      context,
      title: 'Sair da conta',
      message: 'Deseja encerrar a sessão neste dispositivo?',
      confirmText: 'Sair',
      cancelText: 'Cancelar',
    );

    if (!confirmar) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _perfilService.sair();
    } catch (e) {
      if (!mounted) {
        return;
      }

      AppFeedback.showError(
        context,
        'Não foi possível sair agora. Tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Future<void> _editarNome(PerfilUsuario perfil) async {
    if (_isSavingName) {
      return;
    }

    final String? novoNome = await _abrirDialogEditarNome(
      nomeAtual: perfil.nomeExibicao,
    );

    if (novoNome == null || novoNome == perfil.nomeExibicao) {
      return;
    }

    setState(() {
      _isSavingName = true;
    });

    try {
      await _perfilService.atualizarNomeExibicao(
        uid: perfil.uid,
        nome: novoNome,
        email: perfil.email.isEmpty ? null : perfil.email,
      );

      if (!mounted) {
        return;
      }

      AppFeedback.showSuccess(context, 'Nome atualizado com sucesso.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      AppFeedback.showError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  Future<String?> _abrirDialogEditarNome({required String nomeAtual}) async {
    final TextEditingController controller = TextEditingController(
      text: nomeAtual,
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar nome'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nome exibido no app',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final String text = (value ?? '').trim();

                if (text.length < 2) {
                  return 'Informe um nome com ao menos 2 letras.';
                }

                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                Navigator.pop(dialogContext, controller.text.trim());
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _executarAcaoPreferencia({
    required String key,
    required Future<void> Function() action,
    required String errorMessage,
  }) async {
    if (_pendingActions.contains(key)) {
      return;
    }

    setState(() {
      _pendingActions.add(key);
    });

    try {
      await action();
    } catch (e) {
      if (!mounted) {
        return;
      }

      AppFeedback.showError(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _pendingActions.remove(key);
        });
      }
    }
  }

  Future<void> _atualizarMostrarValores({
    required String uid,
    required bool value,
  }) async {
    await _executarAcaoPreferencia(
      key: 'mostrarValoresDashboard',
      action: () => _perfilService.atualizarPreferenciaMostrarValoresDashboard(
        uid: uid,
        value: value,
      ),
      errorMessage: 'Não foi possível atualizar essa preferência.',
    );
  }

  Future<void> _atualizarConfirmarAcoes({
    required String uid,
    required bool value,
  }) async {
    await _executarAcaoPreferencia(
      key: 'confirmarAcoesDestrutivas',
      action: () =>
          _perfilService.atualizarPreferenciaConfirmarAcoesDestrutivas(
            uid: uid,
            value: value,
          ),
      errorMessage: 'Não foi possível atualizar essa preferência.',
    );
  }

  Future<void> _atualizarResumoMensal({
    required String uid,
    required bool value,
  }) async {
    await _executarAcaoPreferencia(
      key: 'receberResumoMensal',
      action: () => _perfilService.atualizarPreferenciaReceberResumoMensal(
        uid: uid,
        value: value,
      ),
      errorMessage: 'Não foi possível atualizar essa preferência.',
    );
  }

  Future<void> _atualizarTema({
    required String uid,
    required AppThemePreference value,
  }) async {
    await _executarAcaoPreferencia(
      key: 'tema',
      action: () =>
          _perfilService.atualizarPreferenciaTema(uid: uid, value: value),
      errorMessage: 'Não foi possível atualizar o tema.',
    );
  }

  Future<void> _tentarSincronizarNome(String uid) async {
    await _executarAcaoPreferencia(
      key: 'syncNome',
      action: () => _perfilService.sincronizarNomeAuthComPerfil(uid: uid),
      errorMessage: 'Ainda não foi possível sincronizar o nome.',
    );
  }

  bool _isBusy(String key) => _pendingActions.contains(key);

  @override
  Widget build(BuildContext context) {
    final User? user = _perfilService.usuarioAtual;

    if (user == null) {
      _agendarRedirecionamentoLogin();

      return _buildCenteredState(
        icon: Icons.lock_outline_rounded,
        title: 'Sessão encerrada',
        description: 'Você precisa estar autenticado para acessar o perfil.',
        actionLabel: 'Ir para login',
        onAction: () => context.go('/login'),
      );
    }

    return StreamBuilder<PerfilUsuario?>(
      stream: _perfilService.perfilUsuarioStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCenteredState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar o perfil',
            description:
                'Não foi possível buscar seus dados agora. Tente novamente.',
            actionLabel: 'Tentar novamente',
            onAction: () {
              setState(() {});
              _inicializarPerfilSePossivel(showErrorFeedback: true);
            },
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildCenteredState(
            icon: Icons.person_outline_rounded,
            title: 'Carregando perfil',
            description: 'Estamos preparando suas informações.',
            loading: true,
          );
        }

        final PerfilUsuario? perfil = snapshot.data;

        if (perfil == null) {
          return _buildCenteredState(
            icon: Icons.person_search_outlined,
            title: 'Perfil ainda não disponível',
            description:
                'Vamos criar a estrutura inicial da sua conta para liberar as preferências.',
            actionLabel: 'Preparar perfil',
            onAction: _inicializarPerfilSePossivel,
          );
        }

        return _buildPerfilContent(perfil);
      },
    );
  }

  Widget _buildPerfilContent(PerfilUsuario perfil) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        if (_isInitializingProfile) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.s12),
        ],
        _buildHeaderCard(perfil),
        if (perfil.displayNameSyncPending) ...[
          const SizedBox(height: AppSpacing.s12),
          AppSectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sync_problem_outlined, color: colorScheme.error),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nome pendente de sincronização',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      const Text(
                        'O nome já foi salvo no app, mas a autenticação ainda não refletiu a mudança.',
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      OutlinedButton.icon(
                        onPressed: _isBusy('syncNome')
                            ? null
                            : () => _tentarSincronizarNome(perfil.uid),
                        icon: _isBusy('syncNome')
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          _isBusy('syncNome')
                              ? 'Sincronizando...'
                              : 'Tentar novamente',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                title: 'Preferências do app',
                subtitle: 'Essas escolhas ficam vinculadas à sua conta.',
              ),
              const SizedBox(height: AppSpacing.s8),
              _buildPreferenceTile(
                actionKey: 'mostrarValoresDashboard',
                icon: Icons.visibility_outlined,
                title: 'Mostrar valores no dashboard',
                subtitle: 'Ao desligar, você poderá esconder saldos e totais.',
                value: perfil.mostrarValoresDashboard,
                onChanged: (value) =>
                    _atualizarMostrarValores(uid: perfil.uid, value: value),
              ),
              const Divider(height: AppSpacing.s24),
              _buildPreferenceTile(
                actionKey: 'receberResumoMensal',
                icon: Icons.mark_email_unread_outlined,
                title: 'Receber resumo mensal',
                subtitle:
                    'Salva sua preferência para futuros resumos e notificações.',
                value: perfil.receberResumoMensal,
                onChanged: (value) =>
                    _atualizarResumoMensal(uid: perfil.uid, value: value),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                title: 'Aparência',
                subtitle: 'Escolha como o app deve abrir neste dispositivo.',
              ),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: AppThemePreference.values.map((option) {
                  return ChoiceChip(
                    label: Text(_themeLabel(option)),
                    selected: perfil.preferenciaTema == option,
                    onSelected: _isBusy('tema')
                        ? null
                        : (_) => _atualizarTema(uid: perfil.uid, value: option),
                    avatar: Icon(_themeIcon(option), size: 18),
                  );
                }).toList(),
              ),
              if (_isBusy('tema')) ...[
                const SizedBox(height: AppSpacing.s12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                title: 'Atalhos',
                subtitle: 'Acesse áreas importantes do app direto pelo perfil.',
              ),
              const SizedBox(height: AppSpacing.s8),
              _buildNavigationTile(
                icon: Icons.repeat_rounded,
                title: 'Compras recorrentes',
                subtitle: 'Veja e gerencie suas recorrências',
                onTap: () => context.push(AppRoutes.recorrenciasPath),
              ),
              const Divider(height: AppSpacing.s24),
              _buildNavigationTile(
                icon: Icons.credit_card_outlined,
                title: 'Cartões',
                subtitle: 'Consulte e organize seus cartões',
                onTap: () => context.push(AppRoutes.cartoesPath),
              ),
              const Divider(height: AppSpacing.s24),
              _buildNavigationTile(
                icon: Icons.upload_file_outlined,
                title: 'Importar extrato',
                subtitle: 'Importe CSV e revise lançamentos',
                onTap: () => context.push(AppRoutes.importarPath),
              ),
              const Divider(height: AppSpacing.s24),
              _buildNavigationTile(
                icon: Icons.savings_outlined,
                title: 'Orçamentos',
                subtitle: 'Defina limites e acompanhe suas categorias',
                onTap: () => context.push(AppRoutes.orcamentosPath),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                title: 'Sessão',
                subtitle: 'Controle o acesso da sua conta neste dispositivo.',
              ),
              const SizedBox(height: AppSpacing.s16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSigningOut ? null : _sair,
                  icon: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(_isSigningOut ? 'Saindo...' : 'Sair'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(PerfilUsuario perfil) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  perfil.iniciais,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Minha conta', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Gerencie seu nome, e-mail e preferências.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              OutlinedButton.icon(
                onPressed: _isSavingName ? null : () => _editarNome(perfil),
                icon: _isSavingName
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(_isSavingName ? 'Salvando...' : 'Editar nome'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Nome',
            value: perfil.nomeExibicao,
          ),
          const SizedBox(height: AppSpacing.s12),
          _buildInfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'E-mail',
            value: perfil.emailExibicao,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required String actionKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final bool isBusy = _isBusy(actionKey);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          Switch.adaptive(value: value, onChanged: isBusy ? null : onChanged),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _buildCenteredState({
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
    bool loading = false,
  }) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        AppSectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
            child: Column(
              children: [
                if (loading)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(),
                  )
                else
                  Icon(icon, size: 48),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(description, textAlign: TextAlign.center),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.s16),
                  OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _themeLabel(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.system:
        return 'Sistema';
      case AppThemePreference.light:
        return 'Claro';
      case AppThemePreference.dark:
        return 'Escuro';
    }
  }

  IconData _themeIcon(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.system:
        return Icons.brightness_auto_outlined;
      case AppThemePreference.light:
        return Icons.light_mode_outlined;
      case AppThemePreference.dark:
        return Icons.dark_mode_outlined;
    }
  }
}

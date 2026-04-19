import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/a_receber/data/services/recebiveis_service.dart';

class NovoRecebivelScreen extends StatefulWidget {
  const NovoRecebivelScreen({required this.db, super.key});

  final FinanceRepository db;

  @override
  State<NovoRecebivelScreen> createState() => _NovoRecebivelScreenState();
}

class _NovoRecebivelScreenState extends State<NovoRecebivelScreen> {
  late final RecebiveisService _recebiveisService;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  bool _salvando = false;

  static const AppSemanticColors _fallbackSemanticColors = AppSemanticColors(
    success: Color(0xFF0F9D7A),
    successContainer: Color(0xFFE5F6F2),
    warning: Color(0xFFC26A00),
    warningContainer: Color(0xFFFFEED9),
    error: Color(0xFFD64545),
    errorContainer: Color(0xFFFDE8E8),
  );

  @override
  void initState() {
    super.initState();
    _recebiveisService = RecebiveisService(widget.db);
    _nomeController.addListener(_onCamposAlterados);
    _descricaoController.addListener(_onCamposAlterados);
    _valorController.addListener(_onCamposAlterados);
  }

  void _onCamposAlterados() {
    if (mounted) {
      setState(() {});
    }
  }

  String _normalizarMensagemErro(Object error) {
    final texto = error.toString();
    final lower = texto.toLowerCase();

    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return 'Cloud Firestore desativado ou sem permissão no projeto.\n'
          'Ative o Firestore no Firebase Console e tente novamente.';
    }

    return 'Erro ao salvar: $texto';
  }

  @override
  void dispose() {
    _nomeController.removeListener(_onCamposAlterados);
    _descricaoController.removeListener(_onCamposAlterados);
    _valorController.removeListener(_onCamposAlterados);
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  String _formatarValorPreview() {
    try {
      return AppFormatters.moeda(
        AppFormatters.parseMoedaInput(_valorController.text),
      );
    } catch (_) {
      return r'R$ 0,00';
    }
  }

  Widget _buildSectionCard({required Widget child}) {
    return AppSectionCard(child: child);
  }

  AppSemanticColors _semanticColors(ThemeData theme) {
    return theme.extension<AppSemanticColors>() ?? _fallbackSemanticColors;
  }

  Widget _buildSectionTitle({required String title, required IconData icon}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(title, style: theme.textTheme.labelLarge),
      ],
    );
  }

  Future<void> _salvarConta() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);

      try {
        final valor = AppFormatters.parseMoedaInput(
          _valorController.text,
        );

        final novaConta = Conta(
          id: '',
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          valor: valor,
          data: DateTime.now(),
        );

        await _recebiveisService.adicionarRecebivel(novaConta);

        if (mounted) {
          Navigator.pop(context);
          AppFeedback.showSuccess(context, 'Item a receber salvo com sucesso!');
        }
      } catch (e) {
        if (mounted) {
          AppFeedback.showError(context, _normalizarMensagemErro(e));
        }
      } finally {
        if (mounted) {
          setState(() => _salvando = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = _semanticColors(theme);
    final nomePreview = _nomeController.text.trim().isEmpty
        ? 'Sem nome'
        : _nomeController.text.trim();
    final descricaoPreview = _descricaoController.text.trim().isEmpty
        ? 'Sem referência'
        : _descricaoController.text.trim();
    final valorPreview = _formatarValorPreview();

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Item a Receber')),
      bottomNavigationBar: AppFormSubmitBar(
        onPressed: _salvarConta,
        label: 'Salvar item a receber',
        isLoading: _salvando,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prévia rápida',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.surfaceContainerHighest,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(
                              alpha: 0.04,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: semantic.success.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.payments_outlined,
                                  size: 17,
                                  color: semantic.success,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                'Como vai aparecer',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              nomePreview,
                              key: ValueKey<String>(nomePreview),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              descricaoPreview,
                              key: ValueKey<String>(descricaoPreview),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              valorPreview,
                              key: ValueKey<String>(valorPreview),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: semantic.success,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(title: 'Pessoa', icon: Icons.person),
                    const SizedBox(height: AppSpacing.s12),
                    TextFormField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Quem vai pagar',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe o nome.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      title: 'Cobrança',
                      icon: Icons.description_outlined,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextFormField(
                      controller: _descricaoController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Referência da cobrança',
                        helperText: 'Ex: Internet de abril',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Descreva a cobrança.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionCard(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: semantic.successContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppSpacing.s14),
                    border: Border.all(
                      color: semantic.success.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        title: 'Valor',
                        icon: Icons.payments_outlined,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      TextFormField(
                        controller: _valorController,
                        textInputAction: TextInputAction.done,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          MoedaInputFormatter(),
                        ],
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: semantic.success,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor da cobrança',
                          helperText: 'Valor em reais',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          prefixText: r'R$ ',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Valor inválido.';
                          }

                          try {
                            final valor = AppFormatters.parseMoedaInput(
                              value,
                            );
                            if (valor <= 0) {
                              return 'Valor inválido.';
                            }
                          } catch (_) {
                            return 'Valor inválido.';
                          }

                          return null;
                        },
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

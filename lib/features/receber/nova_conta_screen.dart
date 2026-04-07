import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../ui/ui.dart';

class NovoRecebivelScreen extends StatefulWidget {
  const NovoRecebivelScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<NovoRecebivelScreen> createState() => _NovoRecebivelScreenState();
}

class _NovoRecebivelScreenState extends State<NovoRecebivelScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
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
    final String texto = error.toString();
    final String lower = texto.toLowerCase();

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
      return 'R\$ 0,00';
    }
  }

  Widget _buildSectionCard({required Widget child}) {
    return AppSectionCard(child: child);
  }

  Widget _buildSectionTitle({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Future<void> _salvarConta() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);

      try {
        final double valor = AppFormatters.parseMoedaInput(
          _valorController.text,
        );

        final Conta novaConta = Conta(
          id: '',
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          valor: valor,
          data: DateTime.now(),
        );

        await widget.db.adicionarRecebivel(novaConta);

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
    final String nomePreview = _nomeController.text.trim().isEmpty
        ? 'Sem nome'
        : _nomeController.text.trim();
    final String descricaoPreview = _descricaoController.text.trim().isEmpty
        ? 'Sem referência'
        : _descricaoController.text.trim();
    final String valorPreview = _formatarValorPreview();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Item a Receber'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      bottomNavigationBar: AppFormSubmitBar(
        onPressed: _salvarConta,
        label: 'SALVAR ITEM A RECEBER',
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              nomePreview,
                              key: ValueKey<String>(nomePreview),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
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
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
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
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor da cobrança',
                        helperText: 'Valor em reais',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        prefixText: 'R\$ ',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Valor inválido.';
                        }

                        try {
                          final double valor = AppFormatters.parseMoedaInput(
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
            ],
          ),
        ),
      ),
    );
  }
}

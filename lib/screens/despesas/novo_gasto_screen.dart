import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/repositories/finance_repository.dart';
import '../../models/gasto_model.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_feedback.dart';
import '../../utils/app_formatters.dart';

class NovoGastoScreen extends StatefulWidget {
  const NovoGastoScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<NovoGastoScreen> createState() => _NovoGastoScreenState();
}

class _NovoGastoScreenState extends State<NovoGastoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  CategoriaGasto _categoriaSelecionada = CategoriaGasto.outros;
  TipoGasto _tipoSelecionado = TipoGasto.variavel;
  DateTime _dataSelecionada = DateTime.now();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tituloController.addListener(_onCamposAlterados);
    _valorController.addListener(_onCamposAlterados);
  }

  void _onCamposAlterados() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tituloController.removeListener(_onCamposAlterados);
    _valorController.removeListener(_onCamposAlterados);
    _tituloController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  String _normalizarMensagemErro(Object error) {
    final String lower = error.toString().toLowerCase();
    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return 'Erro no Firestore. Tente novamente.';
    }
    return 'Erro ao salvar gasto.';
  }

  String _formatarData(DateTime data) {
    return AppFormatters.dataCurta(data);
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

  Future<void> _selecionarData() async {
    final DateTime? novaData = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Escolha a data do gasto',
    );

    if (novaData != null) {
      setState(() => _dataSelecionada = novaData);
    }
  }

  Future<void> _salvarGasto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final double valor = AppFormatters.parseMoedaInput(_valorController.text);
      final Gasto novoGasto = Gasto(
        id: '',
        titulo: _tituloController.text.trim(),
        valor: valor,
        data: _dataSelecionada,
        categoria: _categoriaSelecionada,
        tipo: _tipoSelecionado,
      );

      await widget.db.adicionarGasto(novoGasto);

      if (mounted) {
        Navigator.pop(context);
        AppFeedback.showSuccess(context, 'Gasto salvo com sucesso.');
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

  Widget _buildSectionCard({required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: child,
      ),
    );
  }

  Widget _previewTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _ResumoMiniItem(
        key: ValueKey<String>('${label}_$value'),
        icon: icon,
        label: label,
        value: value,
        accent: accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String valorPreview = _formatarValorPreview();
    final Color previewAccent = _categoriaSelecionada.color;
    final Color previewSurface = Theme.of(context).colorScheme.primaryContainer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Gasto'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          minimum: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _salvando ? null : _salvarGasto,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _salvando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SALVAR GASTO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: previewAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          'Prévia rápida',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Atualiza em tempo real',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            previewSurface,
                            previewAccent.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: previewAccent.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tituloController.text.trim().isEmpty
                                          ? 'Sem título'
                                          : _tituloController.text.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    Text(
                                      _categoriaSelecionada.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: previewAccent.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _categoriaSelecionada.icon,
                                  color: previewAccent,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.08),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              valorPreview,
                              key: ValueKey<String>(valorPreview),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: previewAccent,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            _tipoSelecionado == TipoGasto.fixo
                                ? 'Despesa fixa'
                                : 'Despesa variável',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          Row(
                            children: [
                              Expanded(
                                child: _previewTile(
                                  icon: Icons.calendar_month_outlined,
                                  label: 'Data',
                                  value: _formatarData(_dataSelecionada),
                                  accent: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: _previewTile(
                                  icon: _tipoSelecionado == TipoGasto.fixo
                                      ? Icons.lock_outline
                                      : Icons.auto_awesome_outlined,
                                  label: 'Tipo',
                                  value: _tipoSelecionado.label,
                                  accent: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionCard(
                child: TextFormField(
                  controller: _tituloController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Título do gasto',
                    helperText: 'Ex: Mercado, Uber, aluguel',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Título obrigatório.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionCard(
                child: TextFormField(
                  controller: _valorController,
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[MoedaInputFormatter()],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor do gasto',
                    helperText: 'Valor em reais',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments_outlined),
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o valor.';
                    }

                    try {
                      final double valor = AppFormatters.parseMoedaInput(value);
                      if (valor <= 0) {
                        return 'Valor inválido.';
                      }
                    } catch (_) {
                      return 'Valor inválido.';
                    }

                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categoria',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool compact = constraints.maxWidth < 360;
                        return GridView.count(
                          crossAxisCount: compact ? 2 : 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: AppSpacing.s8,
                          crossAxisSpacing: AppSpacing.s8,
                          childAspectRatio: 2.8,
                          children: CategoriaGasto.values.map((categoria) {
                            final bool selecionada =
                                categoria == _categoriaSelecionada;
                            return _CategoriaOptionTile(
                              categoria: categoria,
                              selecionada: selecionada,
                              onTap: () {
                                setState(
                                  () => _categoriaSelecionada = categoria,
                                );
                              },
                            );
                          }).toList(),
                        );
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
                    Text(
                      'Tipo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    ToggleButtons(
                      isSelected: <bool>[
                        _tipoSelecionado == TipoGasto.fixo,
                        _tipoSelecionado == TipoGasto.variavel,
                      ],
                      onPressed: (index) {
                        setState(() {
                          _tipoSelecionado = index == 0
                              ? TipoGasto.fixo
                              : TipoGasto.variavel;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      selectedColor: Colors.white,
                      fillColor: Theme.of(context).colorScheme.primary,
                      color: Colors.grey.shade700,
                      constraints: const BoxConstraints(minHeight: 46),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Fixo'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Variável'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    FilledButton.tonalIcon(
                      onPressed: _selecionarData,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatarData(_dataSelecionada)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                        alignment: Alignment.centerLeft,
                      ),
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

class _ResumoMiniItem extends StatelessWidget {
  const _ResumoMiniItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CategoriaOptionTile extends StatelessWidget {
  const _CategoriaOptionTile({
    required this.categoria,
    required this.selecionada,
    required this.onTap,
  });

  final CategoriaGasto categoria;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionada
          ? categoria.color.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selecionada
                  ? categoria.color.withValues(alpha: 0.45)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: categoria.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoria.icon, size: 16, color: categoria.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  categoria.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selecionada ? categoria.color : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

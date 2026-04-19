import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/data/services/orcamentos_service.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/domain/models/orcamento_categoria.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/presentation/widgets/orcamento_categoria_progress_item.dart';

class OrcamentosScreen extends StatefulWidget {
  const OrcamentosScreen({required this.db, super.key});

  final FinanceRepository db;

  @override
  State<OrcamentosScreen> createState() => _OrcamentosScreenState();
}

class _OrcamentosScreenState extends State<OrcamentosScreen> {
  late final OrcamentosService _orcamentosService;
  late Stream<List<OrcamentoCategoriaResumo>> _resumosOrcamentoStream;

  // Estado para controlar o mês atual na tela
  DateTime _mesSelecionado = DateTime.now();

  @override
  void initState() {
    super.initState();
    _orcamentosService = OrcamentosService(repository: widget.db);
    _carregarStreamDoMes();
  }

  // Atualiza a Stream baseada no mês selecionado
  void _carregarStreamDoMes() {
    _resumosOrcamentoStream = _orcamentosService.calcularResumoPorCategoria(
      _mesSelecionado,
    );
  }

  void _mudarMes(int incremento) {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + incremento,
      );
      _carregarStreamDoMes();
    });
  }

  Future<void> _abrirFormularioOrcamento({
    required List<OrcamentoCategoriaResumo> resumos, OrcamentoCategoria? existente,
  }) async {
    final screenContext = context;
    var categoriaSelecionada =
        existente?.categoriaPadrao ?? CategoriaGasto.outros;
    final limiteController = TextEditingController(
      text: existente == null
          ? ''
          : AppFormatters.moeda(existente.valorLimite).replaceFirst(r'R$ ', ''),
    );

    final confirmar = await showDialog<bool>(
      context: screenContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setDialogState) {
            return AlertDialog(
              title: Text(
                existente == null ? 'Novo orçamento' : 'Editar orçamento',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<CategoriaGasto>(
                      initialValue: categoriaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: CategoriaGasto.values
                          .map(
                            (categoria) => DropdownMenuItem<CategoriaGasto>(
                              value: categoria,
                              child: Text(categoria.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => categoriaSelecionada = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextFormField(
                      controller: limiteController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        MoedaInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Limite mensal base',
                        hintText: 'Ex: 500,00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
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
      },
    );

    if (confirmar != true) return;
    if (!screenContext.mounted) return;

    final limiteRaw = limiteController.text.trim();
    final double limite;
    try {
      limite = AppFormatters.parseMoedaInput(limiteRaw);
    } catch (_) {
      AppFeedback.showError(screenContext, 'Informe um valor limite válido.');
      return;
    }

    if (limite <= 0) {
      AppFeedback.showError(screenContext, 'O limite deve ser maior que zero.');
      return;
    }

    final categoriaDuplicada = resumos.any(
      (resumo) =>
          resumo.orcamento.categoriaPadrao == categoriaSelecionada &&
          resumo.orcamento.id != existente?.id,
    );

    if (categoriaDuplicada) {
      AppFeedback.showError(
        screenContext,
        'Já existe orçamento para essa categoria.',
      );
      return;
    }

    try {
      if (existente == null) {
        await _orcamentosService.criarOrcamento(
          categoriaPadrao: categoriaSelecionada,
          valorLimite: limite,
        );
      } else {
        await _orcamentosService.atualizarOrcamento(
          id: existente.id,
          categoriaPadrao: categoriaSelecionada,
          valorLimite: limite,
        );
      }

      if (!screenContext.mounted) return;
      AppFeedback.showSuccess(screenContext, 'Orçamento salvo com sucesso.');
    } catch (e) {
      if (!screenContext.mounted) return;
      AppFeedback.showError(screenContext, 'Falha ao salvar orçamento: $e');
    }
  }

  Future<void> _excluirOrcamento(OrcamentoCategoria orcamento) async {
    final screenContext = context;
    final confirmar = await AppConfirmDialog.show(
      screenContext,
      title: 'Excluir orçamento',
      message:
          'Deseja excluir o orçamento de ${orcamento.categoriaPadrao.label}?',
    );

    if (!confirmar) return;
    if (!screenContext.mounted) return;

    try {
      await _orcamentosService.deletarOrcamento(orcamento.id);
      if (!screenContext.mounted) return;
      AppFeedback.showSuccess(screenContext, 'Orçamento removido.');
    } catch (e) {
      if (!screenContext.mounted) return;
      AppFeedback.showError(screenContext, 'Falha ao excluir orçamento: $e');
    }
  }

  // Widget para navegar entre os meses
  Widget _buildSeletorMes() {
    final mesFormatado = DateFormat(
      'MMMM yyyy',
      'pt_BR',
    ).format(_mesSelecionado).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _mudarMes(-1),
          ),
          Text(
            mesFormatado,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _mudarMes(1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos Globais')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orcamentos_add_fab',
        onPressed: () => _abrirFormularioOrcamento(resumos: const []),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: Column(
        children: [
          _buildSeletorMes(),
          Expanded(
            child: StreamBuilder<List<OrcamentoCategoriaResumo>>(
              stream: _resumosOrcamentoStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListSkeleton();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Text(
                        'Falha ao carregar orçamentos: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final resumos =
                    snapshot.data ?? <OrcamentoCategoriaResumo>[];

                if (resumos.isEmpty) {
                  return AppEmptyStateCta(
                    icon: Icons.savings_outlined,
                    title: 'Nenhum orçamento',
                    description:
                        'Crie um limite mensal global por categoria para acompanhar seus gastos.',
                    buttonLabel: 'Criar primeiro orçamento',
                    onPressed: () =>
                        _abrirFormularioOrcamento(resumos: resumos),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.s16,
                    right: AppSpacing.s16,
                    bottom: 80, // Espaço para o FAB
                  ),
                  itemCount: resumos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s12),
                  itemBuilder: (context, index) {
                    final resumo = resumos[index];

                    return OrcamentoCategoriaProgressItem(
                      resumo: resumo,
                      onTap: () => _abrirFormularioOrcamento(
                        existente: resumo.orcamento,
                        resumos: resumos,
                      ),
                      onDelete: () => _excluirOrcamento(resumo.orcamento),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

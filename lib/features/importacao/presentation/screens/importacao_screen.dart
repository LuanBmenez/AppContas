import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/di/service_locator.dart';
import 'package:paga_o_que_me_deve/core/errors/app_exceptions.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/cartoes/cartoes.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/cancelamento_csv_service.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/extrato_csv_service.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/importacao_service.dart';
import 'package:paga_o_que_me_deve/features/importacao/presentation/widgets/cancelamento_section.dart';
import 'package:paga_o_que_me_deve/features/importacao/presentation/widgets/importacao_sections.dart';

enum AcaoRecebimentoImportacao { vincular, criar, ignorar }

class ImportacaoScreen extends StatefulWidget {
  const ImportacaoScreen({super.key});

  @override
  State<ImportacaoScreen> createState() => _ImportacaoScreenState();
}

class _ImportacaoScreenState extends State<ImportacaoScreen> {
  final ExtratoCsvService _extratoService = ExtratoCsvService();
  final CancelamentoCsvService _cancelamentoService = CancelamentoCsvService();
  late final FinanceRepository _db;
  late final ImportacaoService _importacaoService;

  final ScrollController _scrollController = ScrollController();

  late final Stream<List<CartaoCredito>> _cartoesStream;
  late final Stream<List<RegraCategoriaImportacao>> _regrasStream;
  late final Stream<List<Conta>> _contasStream;

  final Map<int, CategoriaGasto> _categoriasOverride = <int, CategoriaGasto>{};
  final Map<String, bool> _acoesCancelamento = <String, bool>{};

  bool _carregandoArquivo = false;
  bool _salvando = false;
  bool _salvandoSugestoes = false;

  String? _nomeArquivo;
  ResultadoLeituraCsv? _csv;
  CartaoCredito? _cartaoSelecionado;

  String? _chaveDuplicadosCache;
  Future<int>? _duplicadosCache;

  final Map<String, AcaoRecebimentoImportacao> _acoesRecebimentos =
      <String, AcaoRecebimentoImportacao>{};
  final Map<String, String?> _vinculosRecebimentos = <String, String?>{};
  final Map<CampoExtrato, String?> _mapeamento = <CampoExtrato, String?>{};

  @override
  void initState() {
    super.initState();
    _db = getIt<FinanceRepository>();
    _importacaoService = ImportacaoService(_db);
    _cartoesStream = _importacaoService.cartoesCredito;
    _regrasStream = _importacaoService.regrasCategoriaImportacao;
    _contasStream = _importacaoService.contasAReceber;
    _resetarMapeamento();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetarMapeamento() {
    _mapeamento[CampoExtrato.dataLancamento] = null;
    _mapeamento[CampoExtrato.dataCompra] = null;
    _mapeamento[CampoExtrato.descricao] = null;
    _mapeamento[CampoExtrato.valor] = null;
    _mapeamento[CampoExtrato.parcela] = null;
  }

  void _limparEstadosDerivadosImportacao() {
    _acoesRecebimentos.clear();
    _vinculosRecebimentos.clear();
    _acoesCancelamento.clear();
    _categoriasOverride.clear();
    _chaveDuplicadosCache = null;
    _duplicadosCache = null;
  }

  Future<void> _manterPosicaoScrollDurante(
    Future<void> Function() action,
  ) async {
    final tinhaClientes = _scrollController.hasClients;
    final offsetAntes = tinhaClientes ? _scrollController.offset : 0.0;

    await action();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final destino = offsetAntes.clamp(0.0, maxScroll);

      if ((_scrollController.offset - destino).abs() > 1) {
        _scrollController.jumpTo(destino);
      }
    });
  }

  CartaoCredito _resolverCartaoSelecionado(List<CartaoCredito> cartoes) {
    final cartaoSelecionadoId = _cartaoSelecionado?.id;

    if (cartaoSelecionadoId == null) {
      return cartoes.first;
    }

    for (final cartao in cartoes) {
      if (cartao.id == cartaoSelecionadoId) {
        return cartao;
      }
    }

    return cartoes.first;
  }

  List<Gasto> _aplicarOverridesCategoria(List<Gasto> gastos) {
    return List<Gasto>.generate(gastos.length, (index) {
      final gasto = gastos[index];
      final categoriaOverride = _categoriasOverride[index];

      if (categoriaOverride == null || categoriaOverride == gasto.categoria) {
        return gasto;
      }

      return gasto.copyWith(categoria: categoriaOverride);
    });
  }

  List<Gasto> _filtrarGastosPorCancelamento(
    List<Gasto> gastos,
    List<TransacaoCanceladaDetectada> cancelados,
  ) {
    final idsIgnorar = cancelados
        .where((c) => _acoesCancelamento[c.id] == true)
        .map((c) => c.gasto.id)
        .toSet();

    return gastos.where((g) => !idsIgnorar.contains(g.id)).toList();
  }

  List<RecebimentoDetectado> _filtrarRecebimentosPorCancelamento(
    List<RecebimentoDetectado> recebimentos,
    List<TransacaoCanceladaDetectada> cancelados,
  ) {
    final idsIgnorar = cancelados
        .where((c) => _acoesCancelamento[c.id] == true)
        .map((c) => c.recebimento.id)
        .toSet();

    return recebimentos.where((r) => !idsIgnorar.contains(r.id)).toList();
  }

  Future<void> _selecionarArquivoCsv() async {
    setState(() => _carregandoArquivo = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }

      final conteudo = _decodificarTexto(bytes);
      final csv = _extratoService.lerCsv(conteudo);

      if (csv.cabecalhos.isEmpty) {
        throw Exception('CSV sem cabeçalho válido.');
      }

      _limparEstadosDerivadosImportacao();

      setState(() {
        _nomeArquivo = file.name;
        _csv = csv;

        _mapeamento[CampoExtrato.dataLancamento] = _sugerirCabecalho(
          csv.cabecalhos,
          <String>['data_lancamento', 'lancamento', 'data'],
        );
        _mapeamento[CampoExtrato.dataCompra] = _sugerirCabecalho(
          csv.cabecalhos,
          <String>['data_compra', 'compra'],
        );
        _mapeamento[CampoExtrato.descricao] = _sugerirCabecalho(
          csv.cabecalhos,
          <String>['descricao', 'historico', 'estabelecimento', 'titulo'],
        );
        _mapeamento[CampoExtrato.valor] = _sugerirCabecalho(
          csv.cabecalhos,
          <String>['valor', 'valor_rs', 'valor_total', 'amount'],
        );
        _mapeamento[CampoExtrato.parcela] = _sugerirCabecalho(
          csv.cabecalhos,
          <String>['parcela', 'installment'],
        );
      });
    } catch (e) {
      if (mounted) {
        final exception = AppException.from(e);
        AppFeedback.showError(context, exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoArquivo = false);
      }
    }
  }

  Future<void> _importar({
    required List<Gasto> gastos,
    required List<RecebimentoDetectado> recebimentos,
    required Map<String, List<SugestaoVinculoRecebimento>> sugestoesVinculo,
    required List<Conta> contasPendentes,
    required List<Conta> todasAsContas,
  }) async {
    if (gastos.isEmpty && recebimentos.isEmpty) {
      AppFeedback.showError(context, 'Nenhum item válido para importar.');
      return;
    }

    setState(() => _salvando = true);

    try {
      ResultadoImportacaoGastos? resultado;
      if (gastos.isNotEmpty) {
        resultado = await _importacaoService.importarGastosComDeduplicacao(
          gastos,
        );
      }

      var vinculados = 0;
      var criados = 0;
      var ignorados = 0;
      var duplicadosRecebimentos = 0;

      final contasPorId = <String, Conta>{
        for (final Conta conta in contasPendentes) conta.id: conta,
      };

      final contasConhecidas = List<Conta>.from(todasAsContas);

      for (final recebimento in recebimentos) {
        final jaImportado = _importacaoService.recebimentoJaImportado(
          contas: contasConhecidas,
          referenciaImportacao: recebimento.referenciaImportacao,
        );

        if (jaImportado) {
          duplicadosRecebimentos++;
          continue;
        }

        final sugestoes =
            sugestoesVinculo[recebimento.id] ??
            const <SugestaoVinculoRecebimento>[];

        final acao =
            _acoesRecebimentos[recebimento.id] ??
            _acaoPadraoRecebimento(recebimento, sugestoes);

        if (acao == AcaoRecebimentoImportacao.ignorar) {
          ignorados++;
          continue;
        }

        if (acao == AcaoRecebimentoImportacao.vincular) {
          final contaIdEscolhida =
              _vinculosRecebimentos[recebimento.id] ??
              (sugestoes.isEmpty ? null : sugestoes.first.conta.id);

          if (contaIdEscolhida == null) {
            ignorados++;
            continue;
          }

          final contaSelecionada =
              contasPorId[contaIdEscolhida] ??
              _buscarContaNasSugestoes(contaIdEscolhida, sugestoes);

          if (contaSelecionada == null) {
            ignorados++;
            continue;
          }

          await _importacaoService.vincularRecebimentoImportado(
            conta: contaSelecionada,
            referencia: recebimento.descricaoOriginal,
            referenciaImportacao: recebimento.referenciaImportacao,
            dataRecebimento: recebimento.data,
            valorRecebido: recebimento.valor,
          );

          contasConhecidas.removeWhere((c) => c.id == contaSelecionada.id);
          contasConhecidas.add(
            contaSelecionada.copyWith(
              foiPago: true,
              recebidaEm: recebimento.data,
              descricao:
                  '${contaSelecionada.descricao}\n'
                  '[Importacao CSV ID:${recebimento.referenciaImportacao}]',
            ),
          );

          vinculados++;
          continue;
        }

        await _importacaoService.criarRecebimentoAvulso(
          nome: recebimento.nomeExtraido ?? 'Recebimento importado',
          descricao: 'Importado via CSV: ${recebimento.descricaoOriginal}',
          data: recebimento.data,
          valor: recebimento.valor,
          referenciaImportacao: recebimento.referenciaImportacao,
        );

        contasConhecidas.add(
          Conta(
            id: 'temp_${recebimento.referenciaImportacao}',
            nome: recebimento.nomeExtraido ?? 'Recebimento importado',
            descricao:
                'Importado via CSV: ${recebimento.descricaoOriginal}\n'
                '[Importacao CSV ID:${recebimento.referenciaImportacao}]',
            valor: recebimento.valor,
            data: recebimento.data,
            foiPago: true,
            recebidaEm: recebimento.data,
          ),
        );

        criados++;
      }

      if (!mounted) return;

      final importados = resultado?.importados ?? 0;
      final duplicados = resultado?.duplicados ?? 0;

      AppFeedback.showSuccess(
        context,
        'Importação concluída: '
        '$importados gastos novos, '
        '$duplicados gastos duplicados ignorados, '
        '$duplicadosRecebimentos recebimentos duplicados ignorados, '
        '$vinculados recebimentos vinculados, '
        '$criados recebimentos avulsos, '
        '$ignorados recebimentos ignorados.',
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final exception = AppException.from(e);
      AppFeedback.showError(context, exception.message);
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _abrirTodasImportacoes(List<Gasto> gastos) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return ScaffoldMessenger(
              child: Scaffold(
                backgroundColor:
                    Colors.transparent, // Mantém o visual arredondado do modal
                body: Builder(
                  builder: (innerContext) {
                    // <--- Pegamos este context!
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s16,
                          AppSpacing.s8,
                          AppSpacing.s16,
                          AppSpacing.s16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Todas as importações (${gastos.length})',
                              style: Theme.of(modalContext).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            Expanded(
                              child: ListView.builder(
                                itemCount: gastos.length,
                                itemBuilder: (context, index) {
                                  final gasto = gastos[index];
                                  final categoriaAtual =
                                      _categoriasOverride[index] ??
                                      gasto.categoria;

                                  final parcela = gasto.parcelaLabel == null
                                      ? ''
                                      : ' • ${gasto.parcelaLabel}';
                                  final compra = gasto.dataCompra == null
                                      ? ''
                                      : ' • compra ${AppFormatters.dataCurta(gasto.dataCompra!)}';
                                  final theme = Theme.of(modalContext);

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.s12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Text(
                                              '${AppFormatters.dataCurta(gasto.data)}$compra • ${gasto.titulo}$parcela • ${AppFormatters.moeda(gasto.valor)}',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.s8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            PopupMenuButton<CategoriaGasto>(
                                              initialValue: categoriaAtual,
                                              tooltip:
                                                  'Alterar somente este item',
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: categoriaAtual.color
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8,
                                                      ),
                                                  border: Border.all(
                                                    color: categoriaAtual.color
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      categoriaAtual.icon,
                                                      size: 14,
                                                      color:
                                                          categoriaAtual.color,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      categoriaAtual.label,
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                categoriaAtual
                                                                    .color,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.arrow_drop_down,
                                                      size: 14,
                                                      color:
                                                          categoriaAtual.color,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              onSelected: (novaCategoria) {
                                                setState(() {
                                                  _categoriasOverride[index] =
                                                      novaCategoria;
                                                });
                                                setModalState(() {});
                                              },
                                              itemBuilder: (context) {
                                                return CategoriaGasto.values
                                                    .map((
                                                      cat,
                                                    ) {
                                                      return PopupMenuItem<
                                                        CategoriaGasto
                                                      >(
                                                        value: cat,
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              cat.icon,
                                                              size: 18,
                                                              color: cat.color,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(cat.label),
                                                          ],
                                                        ),
                                                      );
                                                    })
                                                    .toList();
                                              },
                                            ),
                                            const SizedBox(height: 4),
                                            TextButton(
                                              onPressed: () async {
                                                setState(() {
                                                  _categoriasOverride[index] =
                                                      categoriaAtual;
                                                });
                                                setModalState(() {});

                                                // Agora passamos o innerContext!
                                                await _aprenderNovaRegra(
                                                  gasto.titulo,
                                                  categoriaAtual,
                                                  feedbackContext: innerContext,
                                                );
                                              },
                                              child: const Text('Aprender'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Extrato (CSV)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<CartaoCredito>>(
        stream: _cartoesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cartoes = snapshot.data ?? <CartaoCredito>[];

          if (cartoes.isEmpty) {
            return _buildSemCartoes();
          }

          final cartaoSelecionadoAtual = _resolverCartaoSelecionado(cartoes);

          return StreamBuilder<List<RegraCategoriaImportacao>>(
            stream: _regrasStream,
            builder: (context, regrasSnapshot) {
              final regrasAprendidas =
                  regrasSnapshot.data ?? <RegraCategoriaImportacao>[];

              final preview = _gerarPreview(
                regrasAprendidas,
                cartaoSelecionadoAtual,
              );

              final previewComOverrides = _aplicarOverridesCategoria(
                preview.gastos,
              );

              final cancelamentosDetectados = _cancelamentoService
                  .detectarCancelamentos(
                    gastos: previewComOverrides,
                    recebimentos: preview.recebimentosDetectados,
                  );

              final cancelamentosVisiveis = cancelamentosDetectados
                  .where((c) => _acoesCancelamento[c.id] != true)
                  .toList();

              final sugestoesRegras = _extratoService.sugerirRegrasParaGastos(
                gastos: previewComOverrides,
                regrasExistentes: regrasAprendidas,
              );

              final duplicadosFuture = _obterDuplicadosFuture(
                previewComOverrides,
              );

              final itensPreviewLimitados = previewComOverrides
                  .take(8)
                  .toList();
              final temMaisImportacoes = previewComOverrides.length > 8;

              return StreamBuilder<List<Conta>>(
                stream: _contasStream,
                builder: (context, contasSnapshot) {
                  final todasAsContas = contasSnapshot.data ?? <Conta>[];
                  final contasPendentes = todasAsContas
                      .where((conta) => !conta.foiPago)
                      .toList();

                  final sugestoesVinculo = _extratoService
                      .sugerirVinculosRecebimentos(
                        recebimentos: preview.recebimentosDetectados,
                        contasPendentes: contasPendentes,
                      );

                  return ListView(
                    key: const PageStorageKey('lista_importacao_extrato'),
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    children: [
                      CartaoStepSection(
                        cartoes: cartoes,
                        cartaoSelecionado: cartaoSelecionadoAtual,
                        onCartaoChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _cartaoSelecionado = value;
                              _limparEstadosDerivadosImportacao();
                            });
                          }
                        },
                        onGerenciarCartoes: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartoesScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      ArquivoCsvStepSection(
                        carregandoArquivo: _carregandoArquivo,
                        nomeArquivo: _nomeArquivo,
                        onSelecionarArquivo: _selecionarArquivoCsv,
                      ),
                      if (_csv != null) ...[
                        const SizedBox(height: AppSpacing.s12),
                        MapeamentoColunasSection(
                          campoDataLancamento: _buildCampoMapeamento(
                            label: 'Data de lançamento*',
                            campo: CampoExtrato.dataLancamento,
                          ),
                          campoDescricao: _buildCampoMapeamento(
                            label: 'Descrição*',
                            campo: CampoExtrato.descricao,
                          ),
                          campoValor: _buildCampoMapeamento(
                            label: 'Valor*',
                            campo: CampoExtrato.valor,
                          ),
                          campoDataCompra: _buildCampoMapeamento(
                            label: 'Data da compra (opcional)',
                            campo: CampoExtrato.dataCompra,
                          ),
                          campoParcela: _buildCampoMapeamento(
                            label: 'Parcela (opcional)',
                            campo: CampoExtrato.parcela,
                          ),
                        ),
                        if (sugestoesRegras.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          _buildSugestoesRegrasCard(sugestoesRegras),
                        ],
                        if (cancelamentosVisiveis.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          CancelamentoSection(
                            cancelamentos: cancelamentosVisiveis,
                            onAcao: (par, ignorar) {
                              setState(() {
                                _acoesCancelamento[par.id] = ignorar;
                              });
                            },
                          ),
                        ],
                        if (preview.recebimentosDetectados.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          _buildRecebimentosDetectadosCard(
                            recebimentos: preview.recebimentosDetectados,
                            sugestoesVinculo: sugestoesVinculo,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (temMaisImportacoes)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _abrirTodasImportacoes(
                                      previewComOverrides,
                                    ),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: Text(
                                      'Ver todas (${previewComOverrides.length})',
                                    ),
                                  ),
                                ),
                              ),
                            PreviewImportacaoSection(
                              preview: ResultadoMapeamentoExtrato(
                                gastos: previewComOverrides,
                                ignorados: preview.ignorados,
                                recebimentosDetectados:
                                    preview.recebimentosDetectados,
                                ignoradosPorMotivo: preview.ignoradosPorMotivo,
                                categoriasPorFonte: preview.categoriasPorFonte,
                                possiveisErros: preview.possiveisErros,
                                amostraLinhasIgnoradas:
                                    preview.amostraLinhasIgnoradas,
                              ),
                              duplicadosFuture: duplicadosFuture,
                              salvando: _salvando,
                              podeImportar:
                                  _mapeamentoObrigatorioOk && !_salvando,
                              onImportar: () => _importar(
                                gastos: _filtrarGastosPorCancelamento(
                                  previewComOverrides,
                                  cancelamentosDetectados,
                                ),
                                recebimentos:
                                    _filtrarRecebimentosPorCancelamento(
                                      preview.recebimentosDetectados,
                                      cancelamentosDetectados,
                                    ),
                                sugestoesVinculo: sugestoesVinculo,
                                contasPendentes: contasPendentes,
                                todasAsContas: todasAsContas,
                              ),
                              itensPreview: List<Widget>.generate(
                                itensPreviewLimitados.length,
                                (index) => _buildItemPreview(
                                  itensPreviewLimitados[index],
                                  itemKey: index,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  bool get _mapeamentoObrigatorioOk {
    return _mapeamento[CampoExtrato.dataLancamento] != null &&
        _mapeamento[CampoExtrato.descricao] != null &&
        _mapeamento[CampoExtrato.valor] != null;
  }

  ResultadoMapeamentoExtrato _gerarPreview(
    List<RegraCategoriaImportacao> regrasAprendidas,
    CartaoCredito cartao,
  ) {
    final csv = _csv;

    if (csv == null || !_mapeamentoObrigatorioOk) {
      return const ResultadoMapeamentoExtrato(
        gastos: <Gasto>[],
        ignorados: 0,
      );
    }

    return _extratoService.mapearParaGastos(
      csv: csv,
      mapeamento: _mapeamento,
      cartao: cartao,
      regrasAprendidas: regrasAprendidas,
    );
  }

  Future<int> _obterDuplicadosFuture(List<Gasto> gastos) {
    final hashes =
        gastos
            .map((g) => g.hashImportacao ?? '')
            .where((h) => h.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (hashes.isEmpty) {
      return Future<int>.value(0);
    }

    final chave = hashes.join('|');
    if (_duplicadosCache != null && _chaveDuplicadosCache == chave) {
      return _duplicadosCache!;
    }

    _chaveDuplicadosCache = chave;
    _duplicadosCache = _importacaoService.contarDuplicadosPorHash(hashes);
    return _duplicadosCache!;
  }

  Future<void> _aceitarSugestoesRegras(
    List<SugestaoRegraCategoria> sugestoes,
  ) async {
    if (sugestoes.isEmpty) return;

    setState(() => _salvandoSugestoes = true);

    await _manterPosicaoScrollDurante(() async {
      try {
        for (final sugestao in sugestoes) {
          await _importacaoService.salvarRegraCategoriaImportacao(
            termo: sugestao.termo,
            categoria: sugestao.categoria,
          );
        }

        if (mounted) {
          AppFeedback.showSuccess(
            context,
            '${sugestoes.length} sugestões aplicadas e aprendidas.',
          );
        }
      } catch (e) {
        if (mounted) {
          final exception = AppException.from(e);
          AppFeedback.showError(context, exception.message);
        }
      } finally {
        if (mounted) {
          setState(() => _salvandoSugestoes = false);
        }
      }
    });
  }

  Widget _buildSugestoesRegrasCard(List<SugestaoRegraCategoria> sugestoes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '4) Sugestões de categorização',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s8),
            const Text(
              'Revise e aceite em lote para treinar regras das próximas importações.',
            ),
            const SizedBox(height: AppSpacing.s12),
            ...sugestoes
                .take(8)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                    child: Text(
                      '${s.ocorrencias}x ${s.termo} -> ${s.categoria.label}',
                    ),
                  ),
                ),
            if (sugestoes.length > 8)
              Text('... e mais ${sugestoes.length - 8} sugestões'),
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _salvandoSugestoes
                    ? null
                    : () => _aceitarSugestoesRegras(sugestoes),
                icon: _salvandoSugestoes
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(
                  _salvandoSugestoes
                      ? 'Aplicando sugestões...'
                      : 'Aceitar ${sugestoes.length} sugestões',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecebimentosDetectadosCard({
    required List<RecebimentoDetectado> recebimentos,
    required Map<String, List<SugestaoVinculoRecebimento>> sugestoesVinculo,
  }) {
    final total = recebimentos.fold<double>(
      0,
      (sum, item) => sum + item.valor,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '5) Recebimentos detectados',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '${recebimentos.length} entradas positivas detectadas (${AppFormatters.moeda(total)})',
            ),
            const SizedBox(height: AppSpacing.s12),
            ...recebimentos.map(
              (recebimento) => _buildRecebimentoItem(
                recebimento: recebimento,
                sugestoes:
                    sugestoesVinculo[recebimento.id] ??
                    const <SugestaoVinculoRecebimento>[],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecebimentoItem({
    required RecebimentoDetectado recebimento,
    required List<SugestaoVinculoRecebimento> sugestoes,
  }) {
    final acaoSelecionada =
        _acoesRecebimentos[recebimento.id] ??
        _acaoPadraoRecebimento(recebimento, sugestoes);

    final sugestaoPadraoId = sugestoes.isEmpty
        ? null
        : sugestoes.first.conta.id;

    final contaSelecionadaIdAtual =
        _vinculosRecebimentos[recebimento.id] ?? sugestaoPadraoId;

    final contaSelecionadaExiste =
        !(contaSelecionadaIdAtual == null) &&
        sugestoes.any((s) => s.conta.id == contaSelecionadaIdAtual);

    final contaSelecionadaId = contaSelecionadaExiste
        ? contaSelecionadaIdAtual
        : sugestaoPadraoId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppFormatters.dataCurta(recebimento.data)} • ${AppFormatters.moeda(recebimento.valor)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(recebimento.descricaoOriginal),
              const SizedBox(height: AppSpacing.s4),
              Text('Tipo: ${recebimento.tipo.label}'),
              if ((recebimento.nomeExtraido ?? '').isNotEmpty)
                Text('Nome extraído: ${recebimento.nomeExtraido}'),
              if (recebimento.valorSuspeito)
                Text(
                  'Valor muito baixo/suspeito. Recomenda-se ignorar.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: AppSpacing.s8),
              DropdownButtonFormField<AcaoRecebimentoImportacao>(
                initialValue: acaoSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ação',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<AcaoRecebimentoImportacao>>[
                  DropdownMenuItem(
                    value: AcaoRecebimentoImportacao.vincular,
                    child: Text(
                      'Vincular à cobrança',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: AcaoRecebimentoImportacao.criar,
                    child: Text(
                      'Criar recebimento',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: AcaoRecebimentoImportacao.ignorar,
                    child: Text(
                      'Ignorar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _acoesRecebimentos[recebimento.id] = value;
                    if (value != AcaoRecebimentoImportacao.vincular) {
                      _vinculosRecebimentos.remove(recebimento.id);
                    }
                  });
                },
              ),
              if (acaoSelecionada == AcaoRecebimentoImportacao.vincular) ...[
                const SizedBox(height: AppSpacing.s8),
                if (sugestoes.isEmpty)
                  const Text(
                    'Nenhuma cobrança pendente compatível encontrada. Escolha criar ou ignorar.',
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: contaSelecionadaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cobrança sugerida',
                      border: OutlineInputBorder(),
                    ),
                    items: sugestoes.map((sugestao) {
                      final valorConta = AppFormatters.moeda(
                        sugestao.conta.valor,
                      );
                      final statusValor = sugestao.valorCompativel
                          ? 'valor compatível'
                          : 'dif. ${AppFormatters.moeda(sugestao.diferencaValorAbsoluta)}';

                      return DropdownMenuItem<String>(
                        value: sugestao.conta.id,
                        child: Text(
                          '${sugestao.conta.nome} • $valorConta • $statusValor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _vinculosRecebimentos[recebimento.id] = value;
                      });
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  AcaoRecebimentoImportacao _acaoPadraoRecebimento(
    RecebimentoDetectado recebimento,
    List<SugestaoVinculoRecebimento> sugestoes,
  ) {
    if (recebimento.valorSuspeito ||
        recebimento.tipo == TipoRecebimentoDetectado.reembolso ||
        recebimento.tipo == TipoRecebimentoDetectado.estorno) {
      return AcaoRecebimentoImportacao.ignorar;
    }

    if (sugestoes.isNotEmpty) {
      final melhor = sugestoes.first;
      if (melhor.valorCompativel && melhor.score >= 0.8) {
        return AcaoRecebimentoImportacao.vincular;
      }
    }

    return AcaoRecebimentoImportacao.criar;
  }

  Conta? _buscarContaNasSugestoes(
    String contaId,
    List<SugestaoVinculoRecebimento> sugestoes,
  ) {
    for (final sugestao in sugestoes) {
      if (sugestao.conta.id == contaId) {
        return sugestao.conta;
      }
    }
    return null;
  }

  Widget _buildSemCartoes() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.credit_card_off_outlined, size: 72),
            const SizedBox(height: AppSpacing.s12),
            const Text(
              'Cadastre pelo menos um cartão para importar extrato.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CartoesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_card),
              label: const Text('Cadastrar cartão'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoMapeamento({
    required String label,
    required CampoExtrato campo,
  }) {
    final csv = _csv;
    if (csv == null) {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<String?>(
      initialValue: _mapeamento[campo],
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          child: Text(
            'Não usar esta coluna',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...csv.cabecalhos.map(
          (header) => DropdownMenuItem<String?>(
            value: header,
            child: Text(header, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _mapeamento[campo] = value;
          _limparEstadosDerivadosImportacao();
        });
      },
    );
  }

  Widget _buildItemPreview(Gasto gasto, {required int itemKey}) {
    final categoriaAtual = _categoriasOverride[itemKey] ?? gasto.categoria;
    final parcela = gasto.parcelaLabel == null
        ? ''
        : ' • ${gasto.parcelaLabel}';
    final compra = gasto.dataCompra == null
        ? ''
        : ' • compra ${AppFormatters.dataCurta(gasto.dataCompra!)}';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${AppFormatters.dataCurta(gasto.data)}$compra • ${gasto.titulo}$parcela • ${AppFormatters.moeda(gasto.valor)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<CategoriaGasto>(
                initialValue: categoriaAtual,
                tooltip: 'Alterar somente este item',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: categoriaAtual.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: categoriaAtual.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoriaAtual.icon,
                        size: 14,
                        color: categoriaAtual.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        categoriaAtual.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: categoriaAtual.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 14,
                        color: categoriaAtual.color,
                      ),
                    ],
                  ),
                ),
                onSelected: (novaCategoria) {
                  setState(() {
                    _categoriasOverride[itemKey] = novaCategoria;
                  });
                },
                itemBuilder: (context) {
                  return CategoriaGasto.values.map((cat) {
                    return PopupMenuItem<CategoriaGasto>(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(cat.icon, size: 18, color: cat.color),
                          const SizedBox(width: 8),
                          Text(cat.label),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  setState(() {
                    _categoriasOverride[itemKey] = categoriaAtual;
                  });
                  await _aprenderNovaRegra(gasto.titulo, categoriaAtual);
                },
                child: const Text('Aprender'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _aprenderNovaRegra(
    String titulo,
    CategoriaGasto categoria, {
    int? itemKey,
    BuildContext? feedbackContext,
  }) async {
    final termo = _extrairTermoRegra(titulo);

    if (itemKey != null) {
      setState(() {
        _categoriasOverride[itemKey] = categoria;
      });
    }

    await _manterPosicaoScrollDurante(() async {
      try {
        await _importacaoService.salvarRegraCategoriaImportacao(
          termo: termo,
          categoria: categoria,
        );
        final ctx = feedbackContext ?? context;

        if (!ctx.mounted) return;

        ScaffoldMessenger.of(ctx).clearSnackBars();
        AppFeedback.showSuccess(
          ctx,
          'Regra aprendida! "$termo" -> ${categoria.label}.',
        );
      } catch (e) {
        final ctx = feedbackContext ?? context;
        if (!ctx.mounted) return;

        AppFeedback.showError(ctx, AppException.from(e).message);
      }
    });
  }

  String _extrairTermoRegra(String titulo) {
    var texto = titulo.trim();

    final prefixosRemover = <String>[
      'compra no débito -',
      'compra no credito -',
      'compra no crédito -',
      'compra no debito -',
      'compra -',
      'pagamento de',
      'pagamento -',
      'pix enviado para',
      'pix recebido de',
      'transferencia para',
      'transferência para',
      'transferencia de',
      'transferência de',
      'transferencia enviada',
      'transferência enviada',
      'pelo pix',
    ];

    final lower = texto.toLowerCase();

    for (final prefixo in prefixosRemover) {
      if (lower.startsWith(prefixo)) {
        texto = texto.substring(prefixo.length).trim();
        break;
      }
    }

    texto = texto
        .replaceAll(RegExp(r'^\-\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final partes = texto
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) => !RegExp(r'^\d+$').hasMatch(e))
        .toList();

    if (partes.isEmpty) {
      return titulo.trim();
    }

    if (partes.length == 1) {
      return partes.first;
    }

    return partes.take(2).join(' ');
  }

  String _decodificarTexto(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  String? _sugerirCabecalho(List<String> cabecalhos, List<String> possiveis) {
    final normalizados = <String, String>{
      for (final String cabecalho in cabecalhos)
        _normalizar(cabecalho): cabecalho,
    };

    for (final campo in possiveis) {
      final match = normalizados[_normalizar(campo)];
      if (match != null) {
        return match;
      }
    }

    return null;
  }

  String _normalizar(String texto) => TextNormalizer.normalizeForHeader(texto);
}

typedef ImportarExtratoScreen = ImportacaoScreen;

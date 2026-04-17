import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/cartoes/cartoes.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/cancelamento_csv_service.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/extrato_csv_service.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/importacao_service.dart';

import '../widgets/cancelamento_section.dart';
import '../widgets/importacao_sections.dart';

enum AcaoRecebimentoImportacao { vincular, criar, ignorar }

class ImportacaoScreen extends StatefulWidget {
  const ImportacaoScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<ImportacaoScreen> createState() => _ImportacaoScreenState();
}

class _ImportacaoScreenState extends State<ImportacaoScreen> {
  final ExtratoCsvService _extratoService = ExtratoCsvService();
  final CancelamentoCsvService _cancelamentoService = CancelamentoCsvService();
  late final ImportacaoService _importacaoService;

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
  final Map<TransacaoCanceladaDetectada, bool> _acoesCancelamento =
      <TransacaoCanceladaDetectada, bool>{};

  @override
  void initState() {
    super.initState();
    _importacaoService = ImportacaoService(widget.db);
    _resetarMapeamento();
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
    _chaveDuplicadosCache = null;
    _duplicadosCache = null;
  }

  CartaoCredito _resolverCartaoSelecionado(List<CartaoCredito> cartoes) {
    final String? cartaoSelecionadoId = _cartaoSelecionado?.id;

    if (cartaoSelecionadoId == null) {
      return cartoes.first;
    }

    for (final CartaoCredito cartao in cartoes) {
      if (cartao.id == cartaoSelecionadoId) {
        return cartao;
      }
    }

    return cartoes.first;
  }

  List<Gasto> _filtrarGastosPorCancelamento(
    List<Gasto> gastos,
    List<TransacaoCanceladaDetectada> cancelados,
  ) {
    final Set<String> idsIgnorar = cancelados
        .where((c) => _acoesCancelamento[c] == true)
        .map((c) => c.gasto.id)
        .toSet();

    return gastos.where((g) => !idsIgnorar.contains(g.id)).toList();
  }

  List<RecebimentoDetectado> _filtrarRecebimentosPorCancelamento(
    List<RecebimentoDetectado> recebimentos,
    List<TransacaoCanceladaDetectada> cancelados,
  ) {
    final Set<String> idsIgnorar = cancelados
        .where((c) => _acoesCancelamento[c] == true)
        .map((c) => c.recebimento.id)
        .toSet();

    return recebimentos.where((r) => !idsIgnorar.contains(r.id)).toList();
  }

  Future<void> _selecionarArquivoCsv() async {
    setState(() => _carregandoArquivo = true);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final PlatformFile file = result.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }

      final String conteudo = _decodificarTexto(bytes);
      final ResultadoLeituraCsv csv = _extratoService.lerCsv(conteudo);

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
        AppFeedback.showError(context, 'Erro ao importar CSV: $e');
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

      int vinculados = 0;
      int criados = 0;
      int ignorados = 0;
      int duplicadosRecebimentos = 0;

      final Map<String, Conta> contasPorId = <String, Conta>{
        for (final Conta conta in contasPendentes) conta.id: conta,
      };

      final List<Conta> contasConhecidas = List<Conta>.from(todasAsContas);

      for (final RecebimentoDetectado recebimento in recebimentos) {
        final bool jaImportado = _importacaoService.recebimentoJaImportado(
          contas: contasConhecidas,
          referenciaImportacao: recebimento.referenciaImportacao,
        );

        if (jaImportado) {
          duplicadosRecebimentos++;
          continue;
        }

        final List<SugestaoVinculoRecebimento> sugestoes =
            sugestoesVinculo[recebimento.id] ??
            const <SugestaoVinculoRecebimento>[];

        final AcaoRecebimentoImportacao acao =
            _acoesRecebimentos[recebimento.id] ??
            _acaoPadraoRecebimento(recebimento, sugestoes);

        if (acao == AcaoRecebimentoImportacao.ignorar) {
          ignorados++;
          continue;
        }

        if (acao == AcaoRecebimentoImportacao.vincular) {
          final String? contaIdEscolhida =
              _vinculosRecebimentos[recebimento.id] ??
              (sugestoes.isEmpty ? null : sugestoes.first.conta.id);

          if (contaIdEscolhida == null) {
            ignorados++;
            continue;
          }

          final Conta? contaSelecionada =
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

      final int importados = resultado?.importados ?? 0;
      final int duplicados = resultado?.duplicados ?? 0;

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
      AppFeedback.showError(context, 'Falha ao salvar importação: $e');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Extrato (CSV)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<CartaoCredito>>(
        stream: _importacaoService.cartoesCredito,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<CartaoCredito> cartoes =
              snapshot.data ?? <CartaoCredito>[];

          if (cartoes.isEmpty) {
            return _buildSemCartoes();
          }

          final CartaoCredito cartaoSelecionadoAtual =
              _resolverCartaoSelecionado(cartoes);

          return StreamBuilder<List<RegraCategoriaImportacao>>(
            stream: _importacaoService.regrasCategoriaImportacao,
            builder: (context, regrasSnapshot) {
              final List<RegraCategoriaImportacao> regrasAprendidas =
                  regrasSnapshot.data ?? <RegraCategoriaImportacao>[];

              final ResultadoMapeamentoExtrato preview = _gerarPreview(
                regrasAprendidas,
                cartaoSelecionadoAtual,
              );

              final List<TransacaoCanceladaDetectada> cancelamentosDetectados =
                  _cancelamentoService.detectarCancelamentos(
                    gastos: preview.gastos,
                    recebimentos: preview.recebimentosDetectados,
                  );

              final List<SugestaoRegraCategoria> sugestoesRegras =
                  _extratoService.sugerirRegrasParaGastos(
                    gastos: preview.gastos,
                    regrasExistentes: regrasAprendidas,
                  );

              final Future<int> duplicadosFuture = _obterDuplicadosFuture(
                preview.gastos,
              );

              return StreamBuilder<List<Conta>>(
                stream: _importacaoService.contasAReceber,
                builder: (context, contasSnapshot) {
                  final List<Conta> todasAsContas =
                      contasSnapshot.data ?? <Conta>[];
                  final List<Conta> contasPendentes = todasAsContas
                      .where((conta) => !conta.foiPago)
                      .toList();

                  final Map<String, List<SugestaoVinculoRecebimento>>
                  sugestoesVinculo = _extratoService
                      .sugerirVinculosRecebimentos(
                        recebimentos: preview.recebimentosDetectados,
                        contasPendentes: contasPendentes,
                      );

                  return ListView(
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
                              builder: (_) =>
                                  CartoesCreditoScreen(db: widget.db),
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
                        if (cancelamentosDetectados.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          CancelamentoSection(
                            cancelamentos: cancelamentosDetectados,
                            onAcao: (par, ignorar) {
                              setState(() {
                                _acoesCancelamento[par] = ignorar;
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
                        PreviewImportacaoSection(
                          preview: preview,
                          duplicadosFuture: duplicadosFuture,
                          salvando: _salvando,
                          podeImportar: _mapeamentoObrigatorioOk && !_salvando,
                          onImportar: () => _importar(
                            gastos: _filtrarGastosPorCancelamento(
                              preview.gastos,
                              cancelamentosDetectados,
                            ),
                            recebimentos: _filtrarRecebimentosPorCancelamento(
                              preview.recebimentosDetectados,
                              cancelamentosDetectados,
                            ),
                            sugestoesVinculo: sugestoesVinculo,
                            contasPendentes: contasPendentes,
                            todasAsContas: todasAsContas,
                          ),
                          itensPreview: preview.gastos
                              .take(8)
                              .map((gasto) => _buildItemPreview(gasto))
                              .toList(),
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
    final ResultadoLeituraCsv? csv = _csv;

    if (csv == null || !_mapeamentoObrigatorioOk) {
      return const ResultadoMapeamentoExtrato(
        gastos: <Gasto>[],
        ignorados: 0,
        ignoradosPorMotivo: <String, int>{},
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
    final List<String> hashes =
        gastos
            .map((g) => g.hashImportacao ?? '')
            .where((h) => h.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (hashes.isEmpty) {
      return Future<int>.value(0);
    }

    final String chave = hashes.join('|');
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
    try {
      for (final SugestaoRegraCategoria sugestao in sugestoes) {
        await _importacaoService.salvarRegraCategoriaImportacao(
          termo: sugestao.termo,
          categoria: sugestao.categoria,
        );
      }

      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        '${sugestoes.length} sugestões aplicadas e aprendidas.',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'Falha ao salvar sugestões: $e');
    } finally {
      if (mounted) {
        setState(() => _salvandoSugestoes = false);
      }
    }
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
    final double total = recebimentos.fold<double>(
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
    final AcaoRecebimentoImportacao acaoSelecionada =
        _acoesRecebimentos[recebimento.id] ??
        _acaoPadraoRecebimento(recebimento, sugestoes);

    final String? sugestaoPadraoId = sugestoes.isEmpty
        ? null
        : sugestoes.first.conta.id;

    final String? contaSelecionadaIdAtual =
        _vinculosRecebimentos[recebimento.id] ?? sugestaoPadraoId;

    final bool contaSelecionadaExiste = contaSelecionadaIdAtual == null
        ? false
        : sugestoes.any((s) => s.conta.id == contaSelecionadaIdAtual);

    final String? contaSelecionadaId = contaSelecionadaExiste
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
                      final String valorConta = AppFormatters.moeda(
                        sugestao.conta.valor,
                      );
                      final String statusValor = sugestao.valorCompativel
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
      final SugestaoVinculoRecebimento melhor = sugestoes.first;
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
    for (final SugestaoVinculoRecebimento sugestao in sugestoes) {
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
                    builder: (_) => CartoesCreditoScreen(db: widget.db),
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
    final ResultadoLeituraCsv? csv = _csv;
    if (csv == null) {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<String?>(
      initialValue:
          _mapeamento[campo], // <-- Troque 'value' por 'initialValue' aqui
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
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

  Widget _buildItemPreview(Gasto gasto) {
    final String parcela = gasto.parcelaLabel == null
        ? ''
        : ' • ${gasto.parcelaLabel}';
    final String compra = gasto.dataCompra == null
        ? ''
        : ' • compra ${AppFormatters.dataCurta(gasto.dataCompra!)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Text(
        '${AppFormatters.dataCurta(gasto.data)}$compra • ${gasto.titulo}$parcela • ${AppFormatters.moeda(gasto.valor)} • ${gasto.categoria.label}',
      ),
    );
  }

  String _decodificarTexto(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  String? _sugerirCabecalho(List<String> cabecalhos, List<String> possiveis) {
    final Map<String, String> normalizados = <String, String>{
      for (final String cabecalho in cabecalhos)
        _normalizar(cabecalho): cabecalho,
    };

    for (final String campo in possiveis) {
      final String? match = normalizados[_normalizar(campo)];
      if (match != null) {
        return match;
      }
    }

    return null;
  }

  String _normalizar(String texto) => TextNormalizer.normalizeForHeader(texto);
}

typedef ImportarExtratoScreen = ImportacaoScreen;

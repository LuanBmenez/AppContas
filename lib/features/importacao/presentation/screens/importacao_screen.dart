import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/cartoes/cartoes.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/extrato_csv_service.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/importacao_service.dart';

import '../widgets/importacao_sections.dart';

class ImportacaoScreen extends StatefulWidget {
  const ImportacaoScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<ImportacaoScreen> createState() => _ImportacaoScreenState();
}

class _ImportacaoScreenState extends State<ImportacaoScreen> {
  final ExtratoCsvService _extratoService = ExtratoCsvService();
  late final ImportacaoService _importacaoService;

  bool _carregandoArquivo = false;
  bool _salvando = false;
  bool _salvandoSugestoes = false;
  String? _nomeArquivo;
  ResultadoLeituraCsv? _csv;
  CartaoCredito? _cartaoSelecionado;
  String? _chaveDuplicadosCache;
  Future<int>? _duplicadosCache;

  final Map<CampoExtrato, String?> _mapeamento = <CampoExtrato, String?>{};

  @override
  void initState() {
    super.initState();
    _importacaoService = ImportacaoService(widget.db);
    _mapeamento[CampoExtrato.dataLancamento] = null;
    _mapeamento[CampoExtrato.dataCompra] = null;
    _mapeamento[CampoExtrato.descricao] = null;
    _mapeamento[CampoExtrato.valor] = null;
    _mapeamento[CampoExtrato.parcela] = null;
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
        throw Exception('Nao foi possivel ler o arquivo selecionado.');
      }

      final String conteudo = _decodificarTexto(bytes);
      final ResultadoLeituraCsv csv = _extratoService.lerCsv(conteudo);

      if (csv.cabecalhos.isEmpty) {
        throw Exception('CSV sem cabecalho valido.');
      }

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

  Future<void> _importar(List<Gasto> gastos) async {
    if (gastos.isEmpty) {
      AppFeedback.showError(context, 'Nenhum gasto valido para importar.');
      return;
    }

    setState(() => _salvando = true);

    try {
      final resultado = await _importacaoService.importarGastosComDeduplicacao(
        gastos,
      );

      if (!mounted) {
        return;
      }

      AppFeedback.showSuccess(
        context,
        'Importacao concluida: ${resultado.importados} novos, ${resultado.duplicados} duplicados ignorados.',
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      AppFeedback.showError(context, 'Falha ao salvar importacao: $e');
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

          final String? cartaoSelecionadoId = _cartaoSelecionado?.id;
          final CartaoCredito cartaoSelecionadoAtual = cartoes.firstWhere(
            (c) => c.id == cartaoSelecionadoId,
            orElse: () => cartoes.first,
          );
          _cartaoSelecionado = cartaoSelecionadoAtual;

          return StreamBuilder<List<RegraCategoriaImportacao>>(
            stream: _importacaoService.regrasCategoriaImportacao,
            builder: (context, regrasSnapshot) {
              final List<RegraCategoriaImportacao> regrasAprendidas =
                  regrasSnapshot.data ?? <RegraCategoriaImportacao>[];
              final ResultadoMapeamentoExtrato preview = _gerarPreview(
                regrasAprendidas,
              );
              final List<SugestaoRegraCategoria> sugestoesRegras =
                  _extratoService.sugerirRegrasParaGastos(
                    gastos: preview.gastos,
                    regrasExistentes: regrasAprendidas,
                  );
              final Future<int> duplicadosFuture = _obterDuplicadosFuture(
                preview.gastos,
              );

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.s16),
                children: [
                  CartaoStepSection(
                    cartoes: cartoes,
                    cartaoSelecionado: _cartaoSelecionado,
                    onCartaoChanged: (value) {
                      if (value != null) {
                        setState(() => _cartaoSelecionado = value);
                      }
                    },
                    onGerenciarCartoes: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CartoesCreditoScreen(db: widget.db),
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
                        label: 'Data de lancamento*',
                        campo: CampoExtrato.dataLancamento,
                      ),
                      campoDescricao: _buildCampoMapeamento(
                        label: 'Descricao*',
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
                    const SizedBox(height: AppSpacing.s12),
                    PreviewImportacaoSection(
                      preview: preview,
                      duplicadosFuture: duplicadosFuture,
                      salvando: _salvando,
                      podeImportar: _mapeamentoObrigatorioOk && !_salvando,
                      onImportar: () => _importar(preview.gastos),
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
  ) {
    final ResultadoLeituraCsv? csv = _csv;
    final CartaoCredito? cartao = _cartaoSelecionado;

    if (csv == null || cartao == null || !_mapeamentoObrigatorioOk) {
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
    if (sugestoes.isEmpty) {
      return;
    }

    setState(() => _salvandoSugestoes = true);
    try {
      for (final SugestaoRegraCategoria sugestao in sugestoes) {
        await _importacaoService.salvarRegraCategoriaImportacao(
          termo: sugestao.termo,
          categoria: sugestao.categoria,
        );
      }

      if (!mounted) {
        return;
      }
      AppFeedback.showSuccess(
        context,
        '${sugestoes.length} sugestoes aplicadas e aprendidas.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(context, 'Falha ao salvar sugestoes: $e');
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
              '4) Sugestoes de categorizacao',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s8),
            const Text(
              'Revise e aceite em lote para treinar regras das proximas importacoes.',
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
              Text('... e mais ${sugestoes.length - 8} sugestoes'),
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
                      ? 'Aplicando sugestoes...'
                      : 'Aceitar ${sugestoes.length} sugestoes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              'Cadastre pelo menos um cartao para importar extrato.',
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
              label: const Text('Cadastrar cartao'),
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
      initialValue: _mapeamento[campo],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Nao usar esta coluna'),
        ),
        ...csv.cabecalhos.map(
          (header) =>
              DropdownMenuItem<String?>(value: header, child: Text(header)),
        ),
      ],
      onChanged: (value) {
        setState(() => _mapeamento[campo] = value);
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

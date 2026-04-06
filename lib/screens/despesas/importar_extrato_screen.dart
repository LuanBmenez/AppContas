import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/cartao_credito_model.dart';
import '../../models/gasto_model.dart';
import '../../models/regra_categoria_importacao_model.dart';
import '../../services/database_service.dart';
import '../../services/extrato_csv_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_formatters.dart';
import 'cartoes_credito_screen.dart';

class ImportarExtratoScreen extends StatefulWidget {
  const ImportarExtratoScreen({super.key, required this.db});

  final DatabaseService db;

  @override
  State<ImportarExtratoScreen> createState() => _ImportarExtratoScreenState();
}

class _ImportarExtratoScreenState extends State<ImportarExtratoScreen> {
  final ExtratoCsvService _extratoService = ExtratoCsvService();

  bool _carregandoArquivo = false;
  bool _salvando = false;
  String? _nomeArquivo;
  ResultadoLeituraCsv? _csv;
  CartaoCredito? _cartaoSelecionado;
  String? _chaveDuplicadosCache;
  Future<int>? _duplicadosCache;

  final Map<CampoExtrato, String?> _mapeamento = <CampoExtrato, String?>{};

  @override
  void initState() {
    super.initState();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao importar CSV: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoArquivo = false);
      }
    }
  }

  Future<void> _importar(List<Gasto> gastos) async {
    if (gastos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum gasto valido para importar.')),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final ResultadoImportacaoGastos resultado = await widget.db
          .importarGastosComDeduplicacao(gastos);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importacao concluida: ${resultado.importados} novos, ${resultado.duplicados} duplicados ignorados.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao salvar importacao: $e')));
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
        stream: widget.db.cartoesCredito,
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
            stream: widget.db.regrasCategoriaImportacao,
            builder: (context, regrasSnapshot) {
              final List<RegraCategoriaImportacao> regrasAprendidas =
                  regrasSnapshot.data ?? <RegraCategoriaImportacao>[];
              final ResultadoMapeamentoExtrato preview = _gerarPreview(
                regrasAprendidas,
              );
              final Future<int> duplicadosFuture = _obterDuplicadosFuture(
                preview.gastos,
              );

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.s16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1) Escolha o cartao',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          DropdownButtonFormField<CartaoCredito>(
                            value: _cartaoSelecionado, // Corrigido para value
                            decoration: const InputDecoration(
                              labelText: 'Cartao',
                              border: OutlineInputBorder(),
                            ),
                            items: cartoes
                                .map(
                                  (cartao) => DropdownMenuItem<CartaoCredito>(
                                    value: cartao,
                                    child: Text(cartao.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _cartaoSelecionado = value);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CartoesCreditoScreen(db: widget.db),
                                ),
                              );
                            },
                            icon: const Icon(Icons.credit_card),
                            label: const Text('Gerenciar cartoes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '2) Selecione o CSV da fatura',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          OutlinedButton.icon(
                            onPressed: _carregandoArquivo
                                ? null
                                : _selecionarArquivoCsv,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(
                              _nomeArquivo == null
                                  ? 'Escolher arquivo CSV'
                                  : 'Arquivo: $_nomeArquivo',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          const Text(
                            'OFX ainda nao implementado nesta primeira versao.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_csv != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '3) Mapeie as colunas',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            _buildCampoMapeamento(
                              label: 'Data de lancamento*',
                              campo: CampoExtrato.dataLancamento,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            _buildCampoMapeamento(
                              label: 'Descricao*',
                              campo: CampoExtrato.descricao,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            _buildCampoMapeamento(
                              label: 'Valor*',
                              campo: CampoExtrato.valor,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            _buildCampoMapeamento(
                              label: 'Data da compra (opcional)',
                              campo: CampoExtrato.dataCompra,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            _buildCampoMapeamento(
                              label: 'Parcela (opcional)',
                              campo: CampoExtrato.parcela,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: FutureBuilder<int>(
                          future: duplicadosFuture,
                          builder: (context, duplicadosSnapshot) {
                            final int duplicadosDetectados =
                                duplicadosSnapshot.data ?? 0;
                            final int importaveis =
                                preview.gastos.length - duplicadosDetectados;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '4) Previa antes de salvar',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                Text(
                                  '${importaveis < 0 ? 0 : importaveis} gastos serao importados',
                                ),
                                Text('${preview.ignorados} linhas ignoradas'),
                                if (duplicadosSnapshot.connectionState ==
                                    ConnectionState.waiting)
                                  const Text('Analisando duplicados...')
                                else
                                  Text(
                                    '$duplicadosDetectados duplicados detectados',
                                  ),
                                if (preview.ignoradosPorMotivo.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.s8),
                                  const Text(
                                    'Motivos de ignorados:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s4),
                                  ...preview.ignoradosPorMotivo.entries.map(
                                    (entry) =>
                                        Text('• ${entry.value}x ${entry.key}'),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.s12),
                                ...preview.gastos
                                    .take(8)
                                    .map((gasto) => _buildItemPreview(gasto)),
                                if (preview.gastos.length > 8)
                                  Text(
                                    '... e mais ${preview.gastos.length - 8} registros',
                                  ),
                                const SizedBox(height: AppSpacing.s16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed:
                                        _salvando || !_mapeamentoObrigatorioOk
                                        ? null
                                        : () => _importar(preview.gastos),
                                    icon: _salvando
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save_alt_outlined),
                                    label: Text(
                                      _salvando
                                          ? 'Importando...'
                                          : 'Salvar gastos importados',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ], // Fim do if(_csv != null)
                ],
              );
            },
          );
        },
      ),
    );
  } // Fim do método build

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
    _duplicadosCache = widget.db.contarDuplicadosPorHash(hashes);
    return _duplicadosCache!;
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
      value:
          _mapeamento[campo], // Trocado initialValue por value para funcionar corretamente o onChanged
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

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

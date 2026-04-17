import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/app_tokens.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/features/gastos/data/services/categorias_service.dart';
import 'package:paga_o_que_me_deve/features/gastos/data/services/gastos_service.dart';
import 'package:paga_o_que_me_deve/features/gastos/presentation/controllers/novo_gasto_categoria_controller.dart';

class NovoGastoScreen extends StatefulWidget {
  const NovoGastoScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<NovoGastoScreen> createState() => _NovoGastoScreenState();
}

class _NovoGastoScreenState extends State<NovoGastoScreen> {
  bool _isDisposed = false;

  late final GastosService _gastosService;
  late final CategoriasService _categoriasService;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController? _tituloController = TextEditingController();
  TextEditingController? _valorController = TextEditingController();
  TextEditingController? _buscaCategoriaController = TextEditingController();

  StreamSubscription<List<CategoriaPersonalizada>>? _categoriasSub;
  StreamSubscription<List<RegraCategoriaImportacao>>? _regrasSub;
  Timer? _timerSugestaoRecorrencia;
  Timer? _timerDuplicados;

  CategoriaGasto _categoriaSelecionada = CategoriaGasto.outros;
  String? _categoriaPersonalizadaSelecionadaId;
  String? _categoriaPendenteSelecionarId;
  CategoriaGasto? _categoriaSugerida;
  String? _categoriaPersonalizadaSugeridaId;
  TipoGasto _tipoSelecionado = TipoGasto.variavel;
  DateTime _dataSelecionada = DateTime.now();

  bool _salvando = false;
  bool _carregandoPreferencias = true;
  bool _selecaoCategoriaManual = false;
  bool _recorrenciaAtiva = false;
  bool _recorrenciaConfiguradaManual = false;
  bool _carregandoSugestaoRecorrencia = false;
  bool _carregandoDuplicados = false;
  bool _salvandoCategoria = false;

  int _recorrenciaMesesFuturos = 3;
  int _possiveisDuplicados = 0;
  SugestaoRecorrenciaDespesa? _sugestaoRecorrencia;

  List<CategoriaPersonalizada> _categoriasPersonalizadas =
      <CategoriaPersonalizada>[];
  List<RegraCategoriaImportacao> _regrasAprendidas =
      <RegraCategoriaImportacao>[];

  @override
  void initState() {
    super.initState();
    _gastosService = GastosService(widget.db);
    _categoriasService = CategoriasService(widget.db);

    _tituloController?.addListener(_onCamposAlterados);
    _tituloController?.addListener(_onTituloAlteradoParaSugestao);
    _valorController?.addListener(_onCamposAlterados);
    _buscaCategoriaController?.addListener(_onCamposAlterados);

    _inicializarCategorias();
    _agendarSugestaoRecorrencia();
  }

  @override
  void dispose() {
    _categoriasSub?.cancel();
    _regrasSub?.cancel();
    _timerSugestaoRecorrencia?.cancel();
    _timerDuplicados?.cancel();

    _tituloController?.removeListener(_onCamposAlterados);
    _tituloController?.removeListener(_onTituloAlteradoParaSugestao);
    _valorController?.removeListener(_onCamposAlterados);
    _buscaCategoriaController?.removeListener(_onCamposAlterados);

    _isDisposed = true;

    _tituloController?.dispose();
    _valorController?.dispose();
    _buscaCategoriaController?.dispose();
    _tituloController = null;
    _valorController = null;
    _buscaCategoriaController = null;
    super.dispose();
  }

  Future<void> _inicializarCategorias() async {
    final PreferenciasNovoGasto preferencias = await _categoriasService
        .carregarPreferenciasNovoGasto();

    if (!mounted) {
      return;
    }

    setState(() {
      _tipoSelecionado = preferencias.ultimoTipo ?? _tipoSelecionado;
      _categoriaSelecionada =
          preferencias.ultimaCategoriaPadrao ?? _categoriaSelecionada;
      _categoriaPersonalizadaSelecionadaId =
          preferencias.ultimaCategoriaPersonalizadaId;
      _carregandoPreferencias = false;
    });

    _categoriasSub = _categoriasService.categoriasPersonalizadas.listen((
      categorias,
    ) {
      if (!mounted) {
        return;
      }

      final List<CategoriaPersonalizada> categoriasAtivas = _categoriasService
          .categoriasAtivas(categorias);

      final CategoriaSugestaoResultado sugestao =
          NovoGastoCategoriaController.sugerirPorTitulo(
            titulo: _tituloController?.text ?? '',
            categoriasAtivas: categoriasAtivas,
            regrasAprendidas: _regrasAprendidas,
          );

      final bool categoriaPendenteChegou =
          _categoriaPendenteSelecionarId != null &&
          categorias.any((c) => c.id == _categoriaPendenteSelecionarId);

      setState(() {
        _categoriasPersonalizadas = categorias;

        if (_categoriaPersonalizadaSelecionadaId != null &&
            !_categoriasPersonalizadas.any(
              (c) => c.id == _categoriaPersonalizadaSelecionadaId,
            )) {
          _categoriaPersonalizadaSelecionadaId = null;
        }

        if (categoriaPendenteChegou) {
          _categoriaPersonalizadaSelecionadaId = _categoriaPendenteSelecionarId;
          _categoriaPendenteSelecionarId = null;
          _selecaoCategoriaManual = true;
          _categoriaSugerida = null;
          _categoriaPersonalizadaSugeridaId = null;
          return;
        }

        _categoriaSugerida = sugestao.categoriaPadrao;
        _categoriaPersonalizadaSugeridaId = sugestao.categoriaPersonalizadaId;

        if (!_selecaoCategoriaManual) {
          if (sugestao.categoriaPersonalizadaId != null) {
            _categoriaPersonalizadaSelecionadaId =
                sugestao.categoriaPersonalizadaId;
          } else if (sugestao.categoriaPadrao != null) {
            _categoriaPersonalizadaSelecionadaId = null;
            _categoriaSelecionada = sugestao.categoriaPadrao!;
          }
        }
      });
    });

    _regrasSub = _categoriasService.regrasCategoriaImportacao.listen((regras) {
      if (!mounted) {
        return;
      }

      final CategoriaSugestaoResultado sugestao =
          NovoGastoCategoriaController.sugerirPorTitulo(
            titulo: _tituloController?.text ?? '',
            categoriasAtivas: _categoriasAtivas,
            regrasAprendidas: regras,
          );

      setState(() {
        _regrasAprendidas = regras;
        _categoriaSugerida = sugestao.categoriaPadrao;
        _categoriaPersonalizadaSugeridaId = sugestao.categoriaPersonalizadaId;

        if (!_selecaoCategoriaManual) {
          if (sugestao.categoriaPersonalizadaId != null) {
            _categoriaPersonalizadaSelecionadaId =
                sugestao.categoriaPersonalizadaId;
          } else if (sugestao.categoriaPadrao != null) {
            _categoriaPersonalizadaSelecionadaId = null;
            _categoriaSelecionada = sugestao.categoriaPadrao!;
          }
        }
      });
    });
  }

  void _onCamposAlterados() {
    _agendarVerificacaoDuplicados();
    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  void _onTituloAlteradoParaSugestao() {
    if (_isDisposed) return;
    _sincronizarSugestaoPorTitulo(
      aplicarAutomaticamente: !_selecaoCategoriaManual,
    );
    _agendarSugestaoRecorrencia();
  }

  void _agendarSugestaoRecorrencia() {
    _timerSugestaoRecorrencia?.cancel();
    _timerSugestaoRecorrencia = Timer(
      const Duration(milliseconds: 350),
      _buscarSugestaoRecorrenciaPorHistorico,
    );
  }

  void _agendarVerificacaoDuplicados() {
    _timerDuplicados?.cancel();
    _timerDuplicados = Timer(
      const Duration(milliseconds: 300),
      _verificarPossiveisDuplicados,
    );
  }

  CategoriaSugestaoResultado _calcularSugestaoPorTitulo() {
    return NovoGastoCategoriaController.sugerirPorTitulo(
      titulo: _tituloController?.text ?? '',
      categoriasAtivas: _categoriasAtivas,
      regrasAprendidas: _regrasAprendidas,
    );
  }

  void _sincronizarSugestaoPorTitulo({required bool aplicarAutomaticamente}) {
    final CategoriaSugestaoResultado sugestao = _calcularSugestaoPorTitulo();

    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      _categoriaSugerida = sugestao.categoriaPadrao;
      _categoriaPersonalizadaSugeridaId = sugestao.categoriaPersonalizadaId;

      if (!aplicarAutomaticamente) {
        return;
      }

      if (sugestao.categoriaPersonalizadaId != null) {
        _categoriaPersonalizadaSelecionadaId =
            sugestao.categoriaPersonalizadaId;
      } else if (sugestao.categoriaPadrao != null) {
        _categoriaPersonalizadaSelecionadaId = null;
        _categoriaSelecionada = sugestao.categoriaPadrao!;
      }
    });
  }

  Future<void> _verificarPossiveisDuplicados() async {
    final String titulo = _tituloController?.text.trim() ?? '';
    final double? valor = _valorAtualOuNull();

    if (titulo.length < 3 || valor == null || valor <= 0) {
      if (!mounted || _isDisposed) {
        return;
      }
      setState(() {
        _possiveisDuplicados = 0;
        _carregandoDuplicados = false;
      });
      return;
    }

    if (!mounted || _isDisposed) {
      return;
    }
    setState(() => _carregandoDuplicados = true);

    try {
      final int duplicados = await _gastosService
          .contarPossiveisDuplicadosNoMesmoDia(
            titulo: titulo,
            valor: valor,
            data: _dataSelecionada,
          );

      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _carregandoDuplicados = false;
        _possiveisDuplicados = duplicados;
      });
    } catch (_) {
      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _carregandoDuplicados = false;
        _possiveisDuplicados = 0;
      });
    }
  }

  Future<void> _buscarSugestaoRecorrenciaPorHistorico() async {
    final String titulo = _tituloController?.text.trim() ?? '';

    if (titulo.length < 3) {
      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _carregandoSugestaoRecorrencia = false;
        _sugestaoRecorrencia = null;
      });
      return;
    }

    if (!mounted || _isDisposed) {
      return;
    }
    setState(() => _carregandoSugestaoRecorrencia = true);

    final SugestaoRecorrenciaDespesa? sugestao = await _gastosService
        .sugerirRecorrenciaPorTitulo(titulo);

    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      _carregandoSugestaoRecorrencia = false;
      _sugestaoRecorrencia = sugestao;

      if (!_recorrenciaConfiguradaManual && sugestao != null) {
        _recorrenciaAtiva = true;
        if (_tipoSelecionado != TipoGasto.fixo) {
          _tipoSelecionado = TipoGasto.fixo;
        }
      }
    });
  }

  String _normalizarMensagemErro(Object error) {
    final String lower = error.toString().toLowerCase();
    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return 'Erro no Firestore. Tente novamente.';
    }
    return 'Erro ao salvar gasto.';
  }

  String _formatarData(DateTime data) => AppFormatters.dataCurta(data);

  double? _valorAtualOuNull() {
    try {
      return AppFormatters.parseMoedaInput(_valorController?.text ?? '');
    } catch (_) {
      return null;
    }
  }

  String _formatarValorPreview() {
    final double? valor = _valorAtualOuNull();
    if (valor == null) {
      return 'R\$ 0,00';
    }
    return AppFormatters.moeda(valor);
  }

  List<CategoriaPersonalizada> get _categoriasAtivas {
    return _categoriasService.categoriasAtivas(_categoriasPersonalizadas);
  }

  CategoriaPersonalizada? get _categoriaCustomSelecionada {
    return _categoriasService.buscarCategoriaAtivaPorId(
      categorias: _categoriasPersonalizadas,
      id: _categoriaPersonalizadaSelecionadaId,
    );
  }

  Color get _categoriaCorPreview {
    final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;
    if (custom != null) {
      return custom.cor;
    }
    return _categoriaSelecionada.color;
  }

  IconData get _categoriaIconePreview {
    final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;
    if (custom != null) {
      return custom.icone;
    }
    return _categoriaSelecionada.icon;
  }

  String get _categoriaNomePreview {
    final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;
    if (custom != null) {
      return custom.nome;
    }
    return _categoriaSelecionada.label;
  }

  List<CategoriaPersonalizada> _categoriasPersonalizadasFiltradas() {
    return _categoriasService.filtrarCategoriasAtivas(
      textoBusca: _buscaCategoriaController?.text ?? '',
      categorias: _categoriasPersonalizadas,
    );
  }

  List<CategoriaGasto> _categoriasPadraoFiltradas() {
    return NovoGastoCategoriaController.filtrarCategoriasPadrao(
      _buscaCategoriaController?.text ?? '',
    );
  }

  Future<void> _selecionarData() async {
    final DateTime? novaData = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Escolha a data do gasto',
    );

    if (novaData == null) {
      return;
    }

    setState(() => _dataSelecionada = novaData);
    _agendarVerificacaoDuplicados();
  }

  void _selecionarCategoriaPadrao(CategoriaGasto categoria) {
    setState(() {
      _selecaoCategoriaManual = true;
      _categoriaPersonalizadaSelecionadaId = null;
      _categoriaSelecionada = categoria;
    });
  }

  void _selecionarCategoriaPersonalizada(String id) {
    setState(() {
      _selecaoCategoriaManual = true;
      _categoriaPersonalizadaSelecionadaId = id;
      _categoriaPendenteSelecionarId = null;
    });
  }

  void _aplicarSugestaoRecorrencia() {
    setState(() {
      _recorrenciaAtiva = true;
      _recorrenciaConfiguradaManual = true;
      _tipoSelecionado = TipoGasto.fixo;
    });
  }

  Future<void> _salvarGasto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final double valor = AppFormatters.parseMoedaInput(
        _valorController?.text ?? '',
      );
      final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;

      final Gasto novoGasto = Gasto(
        id: '',
        titulo: _tituloController?.text.trim() ?? '',
        valor: valor,
        data: _dataSelecionada,
        categoria: custom == null
            ? _categoriaSelecionada
            : CategoriaGasto.outros,
        categoriaPersonalizadaId: custom?.id,
        categoriaPersonalizadaNome: custom?.nome,
        categoriaPersonalizadaCorValue: custom?.corValue,
        categoriaPersonalizadaIconeCodePoint: custom?.iconeCodePoint,
        tipo: _tipoSelecionado,
      );

      await _gastosService.salvarGastoComRecorrencias(
        gastoBase: novoGasto,
        recorrenciaAtiva: _recorrenciaAtiva,
        mesesFuturos: _recorrenciaAtiva ? _recorrenciaMesesFuturos : 0,
      );

      await _gastosService.registrarUsoNovoGasto(
        categoriaPadrao: custom == null ? _categoriaSelecionada : null,
        categoriaPersonalizadaId: custom?.id,
        tipo: _tipoSelecionado,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      AppFeedback.showSuccess(context, 'Gasto salvo com sucesso.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      AppFeedback.showError(context, _normalizarMensagemErro(e));
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _abrirModalNovaCategoria() async {
    if (_salvandoCategoria) return;

    final _NovaCategoriaDialogResult? result =
        await showDialog<_NovaCategoriaDialogResult>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => const _NovaCategoriaDialog(),
        );

    if (!mounted || result == null) {
      return;
    }

    final String nome = result.nome.trim();

    if (nome.length < 3) {
      AppFeedback.showError(
        context,
        'Informe um nome com ao menos 3 caracteres.',
      );
      return;
    }

    if (_categoriasService.nomeCategoriaDuplicado(
      nome: nome,
      categorias: _categoriasPersonalizadas,
    )) {
      AppFeedback.showError(context, 'Já existe uma categoria com esse nome.');
      return;
    }

    setState(() => _salvandoCategoria = true);

    try {
      final CategoriaPersonalizada categoria = CategoriaPersonalizada(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        nome: nome,
        corValue: result.cor.toARGB32(),
        iconeCodePoint: result.icone.codePoint,
        favorita: result.favorita,
        arquivada: false,
        usoCount: 0,
      );

      await _categoriasService.salvarCategoriaPersonalizada(categoria);

      if (!mounted) return;

      setState(() {
        _categoriaPendenteSelecionarId = categoria.id;
        _selecaoCategoriaManual = true;
      });

      AppFeedback.showSuccess(
        context,
        'Categoria personalizada criada com sucesso.',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'Não foi possível criar a categoria: $e');
    } finally {
      if (mounted) {
        setState(() => _salvandoCategoria = false);
      }
    }
  }

  Widget _buildAvisoDuplicados() {
    if (_carregandoDuplicados) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.s8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.s8),
            Text('Verificando duplicados...'),
          ],
        ),
      );
    }

    if (_possiveisDuplicados <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber.shade700.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          _possiveisDuplicados == 1
              ? 'Atenção: 1 lançamento parecido já existe nesta data.'
              : 'Atenção: $_possiveisDuplicados lançamentos parecidos já existem nesta data.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ThemeData theme) {
    return AppSectionCard(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: _categoriaCorPreview.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _categoriaCorPreview.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prévia rápida',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: _categoriaCorPreview,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _categoriaCorPreview.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _categoriaIconePreview,
                    color: _categoriaCorPreview,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_tituloController?.text.trim().isEmpty ?? true)
                            ? 'Sem título'
                            : _tituloController!.text.trim(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        _categoriaNomePreview,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              _formatarValorPreview(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: _categoriaCorPreview,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '${_tipoSelecionado.label} • ${_formatarData(_dataSelecionada)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriaSection(ThemeData theme) {
    final List<CategoriaGasto> padrao = _categoriasPadraoFiltradas();
    final List<CategoriaPersonalizada> personalizadas =
        _categoriasPersonalizadasFiltradas();

    final String? categoriaPersonalizadaSelecionadaValida =
        _categoriaPersonalizadaSelecionadaId != null &&
            personalizadas.any(
              (c) => c.id == _categoriaPersonalizadaSelecionadaId,
            )
        ? _categoriaPersonalizadaSelecionadaId
        : null;

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categoria',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _buscaCategoriaController,
            decoration: const InputDecoration(
              labelText: 'Buscar categoria',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (_categoriaSugerida != null ||
              _categoriaPersonalizadaSugeridaId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _categoriaPersonalizadaSugeridaId != null
                    ? 'Sugestão detectada: categoria personalizada.'
                    : 'Sugestão detectada: ${_categoriaSugerida!.label}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.s12),
          DropdownButtonFormField<CategoriaGasto>(
            initialValue: _categoriaSelecionada,
            decoration: const InputDecoration(
              labelText: 'Categoria padrão',
              border: OutlineInputBorder(),
            ),
            items: padrao
                .map(
                  (categoria) => DropdownMenuItem<CategoriaGasto>(
                    value: categoria,
                    child: Text(categoria.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                _selecionarCategoriaPadrao(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _salvandoCategoria ? null : _abrirModalNovaCategoria,
              icon: _salvandoCategoria
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(
                _salvandoCategoria
                    ? 'Criando categoria...'
                    : 'Nova categoria personalizada',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          DropdownButtonFormField<String?>(
            initialValue: categoriaPersonalizadaSelecionadaValida,
            decoration: const InputDecoration(
              labelText: 'Categoria personalizada',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Nenhuma'),
              ),
              ...personalizadas.map(
                (categoria) => DropdownMenuItem<String?>(
                  value: categoria.id,
                  child: Text(categoria.nome),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null || value.isEmpty) {
                setState(() {
                  _categoriaPersonalizadaSelecionadaId = null;
                  _categoriaPendenteSelecionarId = null;
                });
                return;
              }
              _selecionarCategoriaPersonalizada(value);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_carregandoPreferencias) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          Text(
            'Novo gasto',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            'Cadastre uma despesa e use sugestões automáticas para acelerar o preenchimento.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dados principais',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextFormField(
                  controller: _tituloController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final String texto = (value ?? '').trim();
                    if (texto.length < 3) {
                      return 'Informe um título com ao menos 3 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    hintText: 'Ex: 39,90',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final double? valor = _valorAtualOuNull();
                    if (valor == null || valor <= 0) {
                      return 'Informe um valor válido.';
                    }
                    return null;
                  },
                ),
                _buildAvisoDuplicados(),
                const SizedBox(height: AppSpacing.s12),
                DropdownButtonFormField<TipoGasto>(
                  initialValue: _tipoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: TipoGasto.values
                      .map(
                        (tipo) => DropdownMenuItem<TipoGasto>(
                          value: tipo,
                          child: Text(tipo.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _tipoSelecionado = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
                FilledButton.tonalIcon(
                  onPressed: _selecionarData,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_formatarData(_dataSelecionada)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          _buildCategoriaSection(theme),
          const SizedBox(height: AppSpacing.s12),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recorrência',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _recorrenciaAtiva,
                  onChanged: (value) {
                    setState(() {
                      _recorrenciaAtiva = value;
                      _recorrenciaConfiguradaManual = true;
                      if (value) {
                        _tipoSelecionado = TipoGasto.fixo;
                      }
                    });
                  },
                  title: const Text('Criar recorrência mensal'),
                  subtitle: const Text(
                    'Gera automaticamente os próximos lançamentos.',
                  ),
                ),
                if (_recorrenciaAtiva) ...[
                  const SizedBox(height: AppSpacing.s8),
                  DropdownButtonFormField<int>(
                    initialValue: _recorrenciaMesesFuturos,
                    decoration: const InputDecoration(
                      labelText: 'Gerar próximos meses',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem<int>(value: 2, child: Text('2 meses')),
                      DropdownMenuItem<int>(value: 3, child: Text('3 meses')),
                      DropdownMenuItem<int>(value: 6, child: Text('6 meses')),
                      DropdownMenuItem<int>(value: 12, child: Text('12 meses')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _recorrenciaMesesFuturos = value);
                      }
                    },
                  ),
                ],
                if (_carregandoSugestaoRecorrencia) ...[
                  const SizedBox(height: AppSpacing.s8),
                  const LinearProgressIndicator(),
                ],
                if (_sugestaoRecorrencia != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.42,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sugestão automática: parece ${_sugestaoRecorrencia!.periodicidade}.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          '${_sugestaoRecorrencia!.ocorrencias} ocorrências, dia ${_sugestaoRecorrencia!.diaPreferencial}, média ${AppFormatters.moeda(_sugestaoRecorrencia!.valorMedio)}.',
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        OutlinedButton.icon(
                          onPressed: _aplicarSugestaoRecorrencia,
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('Aplicar sugestão'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          _buildPreviewCard(theme),
          const SizedBox(height: AppSpacing.s16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _salvando ? null : _salvarGasto,
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_salvando ? 'Salvando...' : 'Salvar gasto'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NovaCategoriaDialogResult {
  const _NovaCategoriaDialogResult({
    required this.nome,
    required this.cor,
    required this.icone,
    required this.favorita,
  });

  final String nome;
  final Color cor;
  final IconData icone;
  final bool favorita;
}

class _NovaCategoriaDialog extends StatefulWidget {
  const _NovaCategoriaDialog();

  @override
  State<_NovaCategoriaDialog> createState() => _NovaCategoriaDialogState();
}

class _NovaCategoriaDialogState extends State<_NovaCategoriaDialog> {
  late final TextEditingController _nomeController;

  Color _corSelecionada = Colors.teal;
  IconData _iconeSelecionado = Icons.category_rounded;
  bool _favorita = false;

  final List<Color> _cores = <Color>[
    Colors.teal,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.green,
    Colors.indigo,
    Colors.pink,
  ];

  final List<IconData> _icones = <IconData>[
    Icons.category_rounded,
    Icons.shopping_bag_outlined,
    Icons.restaurant_outlined,
    Icons.local_gas_station_outlined,
    Icons.home_outlined,
    Icons.health_and_safety_outlined,
    Icons.school_outlined,
    Icons.sports_esports_outlined,
    Icons.work_outline,
    Icons.pets_outlined,
    Icons.flight_takeoff_outlined,
    Icons.store_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  void _salvar() {
    final String nome = _nomeController.text.trim();

    Navigator.of(context).pop(
      _NovaCategoriaDialogResult(
        nome: nome,
        cor: _corSelecionada,
        icone: _iconeSelecionado,
        favorita: _favorita,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria personalizada'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nomeController,
              maxLength: 24,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _salvar(),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Cor',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: _cores.map((cor) {
                final bool selecionada =
                    cor.toARGB32() == _corSelecionada.toARGB32();

                return InkWell(
                  onTap: () {
                    setState(() {
                      _corSelecionada = cor;
                    });
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selecionada ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Ícone',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: _icones.map((icone) {
                final bool selecionado =
                    icone.codePoint == _iconeSelecionado.codePoint;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _iconeSelecionado = icone;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selecionado
                          ? _corSelecionada.withValues(alpha: 0.16)
                          : Colors.transparent,
                      border: Border.all(
                        color: selecionado
                            ? _corSelecionada
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Icon(icone),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _favorita,
              onChanged: (value) {
                setState(() {
                  _favorita = value;
                });
              },
              title: const Text('Favorita'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}

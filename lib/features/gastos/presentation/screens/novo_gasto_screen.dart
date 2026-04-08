import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/gastos/presentation/controllers/novo_gasto_categoria_controller.dart';

import '../widgets/novo_gasto_sections.dart';

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
  final TextEditingController _buscaCategoriaController =
      TextEditingController();

  StreamSubscription<List<CategoriaPersonalizada>>? _categoriasSub;
  StreamSubscription<List<RegraCategoriaImportacao>>? _regrasSub;
  Timer? _timerSugestaoRecorrencia;
  Timer? _timerDuplicados;

  CategoriaGasto _categoriaSelecionada = CategoriaGasto.outros;
  String? _categoriaPersonalizadaSelecionadaId;
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
  int _recorrenciaMesesFuturos = 3;
  int _possiveisDuplicados = 0;
  SugestaoRecorrenciaDespesa? _sugestaoRecorrencia;

  PreferenciasNovoGasto _preferencias = const PreferenciasNovoGasto();
  List<CategoriaPersonalizada> _categoriasPersonalizadas =
      <CategoriaPersonalizada>[];
  List<RegraCategoriaImportacao> _regrasAprendidas =
      <RegraCategoriaImportacao>[];

  static const List<Color> _coresCategoria = <Color>[
    Color(0xFF0D9488),
    Color(0xFF2563EB),
    Color(0xFF9333EA),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFFB91C1C),
    Color(0xFF65A30D),
    Color(0xFF0891B2),
    Color(0xFF475569),
    Color(0xFF7C2D12),
    Color(0xFF0369A1),
    Color(0xFF4D7C0F),
  ];

  static const List<IconData> _iconesCategoria = <IconData>[
    Icons.shopping_cart_outlined,
    Icons.restaurant_outlined,
    Icons.local_gas_station_outlined,
    Icons.home_outlined,
    Icons.school_outlined,
    Icons.health_and_safety_outlined,
    Icons.sports_esports_outlined,
    Icons.work_outline,
    Icons.pets_outlined,
    Icons.flight_takeoff_outlined,
    Icons.fastfood_outlined,
    Icons.store_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tituloController.addListener(_onCamposAlterados);
    _tituloController.addListener(_onTituloAlteradoParaSugestao);
    _valorController.addListener(_onCamposAlterados);
    _buscaCategoriaController.addListener(_onCamposAlterados);
    _inicializarCategorias();
    _agendarSugestaoRecorrencia();
  }

  @override
  void dispose() {
    _categoriasSub?.cancel();
    _regrasSub?.cancel();
    _timerSugestaoRecorrencia?.cancel();
    _tituloController.removeListener(_onCamposAlterados);
    _tituloController.removeListener(_onTituloAlteradoParaSugestao);
    _valorController.removeListener(_onCamposAlterados);
    _buscaCategoriaController.removeListener(_onCamposAlterados);
    _tituloController.dispose();
    _valorController.dispose();
    _buscaCategoriaController.dispose();
    _timerDuplicados?.cancel();
    super.dispose();
  }

  Future<void> _inicializarCategorias() async {
    final PreferenciasNovoGasto preferencias = await widget.db
        .carregarPreferenciasNovoGasto();

    if (!mounted) {
      return;
    }

    setState(() {
      _preferencias = preferencias;
      _tipoSelecionado = preferencias.ultimoTipo ?? _tipoSelecionado;
      _categoriaSelecionada =
          preferencias.ultimaCategoriaPadrao ?? _categoriaSelecionada;
      _categoriaPersonalizadaSelecionadaId =
          preferencias.ultimaCategoriaPersonalizadaId;
      _carregandoPreferencias = false;
    });

    _categoriasSub = widget.db.categoriasPersonalizadas.listen((categorias) {
      if (!mounted) {
        return;
      }

      setState(() {
        _categoriasPersonalizadas = categorias;
        if (_categoriaPersonalizadaSelecionadaId != null &&
            !_categoriasPersonalizadas.any(
              (c) => c.id == _categoriaPersonalizadaSelecionadaId,
            )) {
          _categoriaPersonalizadaSelecionadaId = null;
        }
      });

      _atualizarSugestaoPorTitulo(aplicarAutomaticamente: true);
    });

    _regrasSub = widget.db.regrasCategoriaImportacao.listen((regras) {
      if (!mounted) {
        return;
      }

      setState(() {
        _regrasAprendidas = regras;
      });

      _atualizarSugestaoPorTitulo(
        aplicarAutomaticamente: !_selecaoCategoriaManual,
      );
    });
  }

  void _onCamposAlterados() {
    _agendarVerificacaoDuplicados();
    if (mounted) {
      setState(() {});
    }
  }

  void _onTituloAlteradoParaSugestao() {
    _atualizarSugestaoPorTitulo(
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

  Future<void> _verificarPossiveisDuplicados() async {
    final String titulo = _tituloController.text.trim();
    if (titulo.length < 3) {
      if (!mounted) {
        return;
      }
      setState(() {
        _possiveisDuplicados = 0;
        _carregandoDuplicados = false;
      });
      return;
    }

    final double? valor = _valorAtualOuNull();
    if (valor == null || valor <= 0) {
      if (!mounted) {
        return;
      }
      setState(() {
        _possiveisDuplicados = 0;
        _carregandoDuplicados = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _carregandoDuplicados = true);

    final List<Gasto> gastos = await widget.db.meusGastos.first;
    final String tituloNormalizado = TextNormalizer.normalizeForSearch(titulo);
    final DateTime dataBase = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
    );

    int duplicados = 0;
    for (final Gasto gasto in gastos) {
      final DateTime dataGasto = DateTime(
        gasto.data.year,
        gasto.data.month,
        gasto.data.day,
      );
      if (dataGasto != dataBase) {
        continue;
      }

      if ((gasto.valor - valor).abs() > 0.001) {
        continue;
      }

      final String tituloExistente = TextNormalizer.normalizeForSearch(
        gasto.titulo,
      );
      if (tituloExistente == tituloNormalizado) {
        duplicados++;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _carregandoDuplicados = false;
      _possiveisDuplicados = duplicados;
    });
  }

  Future<void> _buscarSugestaoRecorrenciaPorHistorico() async {
    final String titulo = _tituloController.text.trim();
    if (titulo.length < 3) {
      if (!mounted) {
        return;
      }
      setState(() {
        _carregandoSugestaoRecorrencia = false;
        _sugestaoRecorrencia = null;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _carregandoSugestaoRecorrencia = true);

    final SugestaoRecorrenciaDespesa? sugestao = await widget.db
        .sugerirRecorrenciaPorTitulo(titulo);

    if (!mounted) {
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

  void _atualizarSugestaoPorTitulo({required bool aplicarAutomaticamente}) {
    final CategoriaSugestaoResultado sugestao =
        NovoGastoCategoriaController.sugerirPorTitulo(
          titulo: _tituloController.text,
          categoriasAtivas: _categoriasAtivas,
          regrasAprendidas: _regrasAprendidas,
        );

    if (sugestao.categoriaPadrao == null &&
        sugestao.categoriaPersonalizadaId == null) {
      setState(() {
        _categoriaSugerida = null;
        _categoriaPersonalizadaSugeridaId = null;
      });
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

  double? _valorAtualOuNull() {
    try {
      return AppFormatters.parseMoedaInput(_valorController.text);
    } catch (_) {
      return null;
    }
  }

  List<CategoriaPersonalizada> get _categoriasAtivas {
    return _categoriasPersonalizadas
        .where((categoria) => !categoria.arquivada)
        .toList();
  }

  CategoriaPersonalizada? get _categoriaCustomSelecionada {
    final String? id = _categoriaPersonalizadaSelecionadaId;
    if (id == null) {
      return null;
    }
    for (final CategoriaPersonalizada categoria in _categoriasPersonalizadas) {
      if (categoria.id == id) {
        return categoria;
      }
    }
    return null;
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

  bool get _categoriaPersonalizadaAtiva => _categoriaCustomSelecionada != null;

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
      _agendarVerificacaoDuplicados();
    }
  }

  Future<void> _salvarGasto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final double valor = AppFormatters.parseMoedaInput(_valorController.text);
      final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;

      final Gasto novoGasto = Gasto(
        id: '',
        titulo: _tituloController.text.trim(),
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

      await widget.db.adicionarGasto(novoGasto);

      if (_recorrenciaAtiva) {
        final List<Gasto> futuros = _gerarRecorrenciasFuturas(
          base: novoGasto,
          mesesFuturos: _recorrenciaMesesFuturos,
        );
        for (final Gasto gasto in futuros) {
          await widget.db.adicionarGasto(gasto);
        }
      }

      await widget.db.registrarUsoNovoGasto(
        categoriaPadrao: custom == null ? _categoriaSelecionada : null,
        categoriaPersonalizadaId: custom?.id,
        tipo: _tipoSelecionado,
      );

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

  DateTime _adicionarMesesPreservandoDia(DateTime dataBase, int meses) {
    final int ano = dataBase.year + ((dataBase.month - 1 + meses) ~/ 12);
    final int mes = ((dataBase.month - 1 + meses) % 12) + 1;
    final int ultimoDiaMes = DateTime(ano, mes + 1, 0).day;
    final int dia = dataBase.day > ultimoDiaMes ? ultimoDiaMes : dataBase.day;
    return DateTime(ano, mes, dia);
  }

  List<Gasto> _gerarRecorrenciasFuturas({
    required Gasto base,
    required int mesesFuturos,
  }) {
    final List<Gasto> futuros = <Gasto>[];
    for (int i = 1; i <= mesesFuturos; i++) {
      futuros.add(
        base.copyWith(
          id: '',
          data: _adicionarMesesPreservandoDia(base.data, i),
          dataCompra: base.dataCompra == null
              ? null
              : _adicionarMesesPreservandoDia(base.dataCompra!, i),
          dataLancamento: base.dataLancamento == null
              ? null
              : _adicionarMesesPreservandoDia(base.dataLancamento!, i),
          hashImportacao: null,
        ),
      );
    }
    return futuros;
  }

  void _aplicarSugestaoRecorrencia() {
    setState(() {
      _recorrenciaAtiva = true;
      _recorrenciaConfiguradaManual = true;
      _tipoSelecionado = TipoGasto.fixo;
    });
  }

  Widget _buildSectionCard({required Widget child}) {
    return AppSectionCard(child: child);
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
    });
  }

  List<CategoriaGasto> _categoriasPadraoFiltradas() {
    return NovoGastoCategoriaController.filtrarCategoriasPadrao(
      _buscaCategoriaController.text,
    );
  }

  List<CategoriaPersonalizada> _categoriasPersonalizadasFiltradas() {
    return NovoGastoCategoriaController.filtrarCategoriasPersonalizadas(
      _buscaCategoriaController.text,
      _categoriasAtivas,
    );
  }

  CategoriaPersonalizada? _buscarCategoriaAtivaPorId(String id) {
    return NovoGastoCategoriaController.buscarCategoriaAtivaPorId(
      _categoriasAtivas,
      id,
    );
  }

  bool _nomeCategoriaDuplicado(String nome, {String? ignorarId}) {
    return NovoGastoCategoriaController.nomeCategoriaDuplicado(
      nome: nome,
      categoriasAtivas: _categoriasAtivas,
      ignorarId: ignorarId,
    );
  }

  double _contrastRatio(Color a, Color b) {
    final double l1 = a.computeLuminance();
    final double l2 = b.computeLuminance();
    final double claro = l1 > l2 ? l1 : l2;
    final double escuro = l1 > l2 ? l2 : l1;
    return (claro + 0.05) / (escuro + 0.05);
  }

  bool _temContrasteAcessivel(Color cor) {
    final double comBranco = _contrastRatio(cor, Colors.white);
    final double comPreto = _contrastRatio(cor, Colors.black);
    return comBranco >= 4.5 || comPreto >= 4.5;
  }

  Future<void> _abrirModalCategoria({CategoriaPersonalizada? categoria}) async {
    final TextEditingController nomeController = TextEditingController(
      text: categoria?.nome ?? '',
    );
    int corValue = categoria?.corValue ?? _coresCategoria.first.toARGB32();
    int iconeCodePoint =
        categoria?.iconeCodePoint ?? _iconesCategoria.first.codePoint;
    bool favorita = categoria?.favorita ?? false;

    final bool? salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Color corAtual = Color(corValue);
            final IconData iconeAtual = IconData(
              iconeCodePoint,
              fontFamily: 'MaterialIcons',
            );
            final Color texto = _contrastRatio(corAtual, Colors.white) >= 4.5
                ? Colors.white
                : Colors.black;

            return AlertDialog(
              title: Text(
                categoria == null ? 'Nova categoria' : 'Editar categoria',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nomeController,
                      maxLength: 24,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: corAtual,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(iconeAtual, color: texto),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              nomeController.text.trim().isEmpty
                                  ? 'Prévia da categoria'
                                  : nomeController.text.trim(),
                              style: TextStyle(
                                color: texto,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      'Cor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: _coresCategoria.map((cor) {
                        final bool selecionada = cor.toARGB32() == corValue;
                        return InkWell(
                          onTap: () =>
                              setDialogState(() => corValue = cor.toARGB32()),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selecionada
                                    ? Colors.black
                                    : Colors.transparent,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: _iconesCategoria.map((icone) {
                        final bool selecionado =
                            icone.codePoint == iconeCodePoint;
                        return InkWell(
                          onTap: () => setDialogState(
                            () => iconeCodePoint = icone.codePoint,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selecionado
                                  ? Color(corValue).withValues(alpha: 0.16)
                                  : Colors.transparent,
                              border: Border.all(
                                color: selecionado
                                    ? Color(corValue)
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
                      value: favorita,
                      onChanged: (value) =>
                          setDialogState(() => favorita = value),
                      title: const Text('Favorita'),
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
                  onPressed: () async {
                    final String nome = nomeController.text.trim();
                    final bool categoriaNova = categoria == null;
                    final String categoriaId =
                        categoria?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString();
                    if (nome.length < 3) {
                      AppFeedback.showError(
                        context,
                        'Nome deve ter ao menos 3 caracteres.',
                      );
                      return;
                    }
                    if (_nomeCategoriaDuplicado(
                      nome,
                      ignorarId: categoria?.id,
                    )) {
                      AppFeedback.showError(
                        context,
                        'Já existe uma categoria com esse nome.',
                      );
                      return;
                    }
                    if (!_temContrasteAcessivel(Color(corValue))) {
                      AppFeedback.showError(
                        context,
                        'Escolha uma cor com melhor contraste.',
                      );
                      return;
                    }

                    final CategoriaPersonalizada nova = CategoriaPersonalizada(
                      id: categoriaId,
                      nome: nome,
                      corValue: corValue,
                      iconeCodePoint: iconeCodePoint,
                      favorita: favorita,
                      arquivada: false,
                      usoCount: categoria?.usoCount ?? 0,
                      criadaEm: categoria?.criadaEm,
                    );

                    await widget.db.salvarCategoriaPersonalizada(nova);
                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _selecaoCategoriaManual = true;
                      _categoriaPersonalizadaSelecionadaId = categoriaId;

                      if (categoriaNova) {
                        _categoriasPersonalizadas = <CategoriaPersonalizada>[
                          ..._categoriasPersonalizadas,
                          nova,
                        ];
                      } else {
                        _categoriasPersonalizadas = _categoriasPersonalizadas
                            .map((item) => item.id == categoriaId ? nova : item)
                            .toList();
                      }
                    });

                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (salvar == true && mounted) {
      AppFeedback.showSuccess(context, 'Categoria salva com sucesso.');
    }
  }

  Future<void> _abrirAcoesCategoriaPersonalizada(
    CategoriaPersonalizada categoria,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Renomear / Trocar cor e ícone'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _abrirModalCategoria(categoria: categoria);
                },
              ),
              ListTile(
                leading: Icon(
                  categoria.favorita ? Icons.star : Icons.star_outline,
                ),
                title: Text(categoria.favorita ? 'Desfavoritar' : 'Favoritar'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _categoriasPersonalizadas = _categoriasPersonalizadas
                        .map(
                          (item) => item.id == categoria.id
                              ? item.copyWith(favorita: !categoria.favorita)
                              : item,
                        )
                        .toList();
                  });
                  await widget.db.alternarFavoritaCategoriaPersonalizada(
                    categoria.id,
                    !categoria.favorita,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  categoria.arquivada
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(categoria.arquivada ? 'Desarquivar' : 'Arquivar'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final bool novoArquivada = !categoria.arquivada;
                  setState(() {
                    _categoriasPersonalizadas = _categoriasPersonalizadas
                        .map(
                          (item) => item.id == categoria.id
                              ? item.copyWith(arquivada: novoArquivada)
                              : item,
                        )
                        .toList();
                  });
                  await widget.db.arquivarCategoriaPersonalizada(
                    categoria.id,
                    novoArquivada,
                  );
                  if (_categoriaPersonalizadaSelecionadaId == categoria.id &&
                      novoArquivada) {
                    setState(() {
                      _categoriaPersonalizadaSelecionadaId = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Excluir'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final bool emUso = await widget.db
                      .categoriaPersonalizadaEmUso(categoria.id);
                  if (emUso) {
                    if (!mounted) return;
                    AppFeedback.showError(
                      context,
                      'Categoria em uso. Apenas arquivamento é permitido.',
                    );
                    setState(() {
                      _categoriasPersonalizadas = _categoriasPersonalizadas
                          .map(
                            (item) => item.id == categoria.id
                                ? item.copyWith(arquivada: true)
                                : item,
                          )
                          .toList();
                      if (_categoriaPersonalizadaSelecionadaId ==
                          categoria.id) {
                        _categoriaPersonalizadaSelecionadaId = null;
                      }
                    });
                    await widget.db.arquivarCategoriaPersonalizada(
                      categoria.id,
                      true,
                    );
                    return;
                  }

                  if (!mounted) return;
                  final bool confirmar = await AppConfirmDialog.show(
                    context,
                    title: 'Excluir categoria',
                    message: 'Deseja excluir ${categoria.nome}?',
                  );
                  if (!confirmar) {
                    return;
                  }

                  await widget.db.deletarCategoriaPersonalizada(categoria.id);
                  if (!mounted) return;
                  setState(() {
                    _categoriasPersonalizadas = _categoriasPersonalizadas
                        .where((item) => item.id != categoria.id)
                        .toList();
                    if (_categoriaPersonalizadaSelecionadaId == categoria.id) {
                      _categoriaPersonalizadaSelecionadaId = null;
                    }
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChipSugestao() {
    final String? customId = _categoriaPersonalizadaSugeridaId;
    final CategoriaGasto? padrao = _categoriaSugerida;
    if (customId == null && padrao == null) {
      return const SizedBox.shrink();
    }

    String label;
    if (customId != null) {
      final CategoriaPersonalizada? custom = _buscarCategoriaAtivaPorId(
        customId,
      );
      label = custom?.nome ?? 'Categoria personalizada';
    } else {
      label = padrao!.label;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text('Sugestão: $label'),
          onPressed: () {
            if (customId != null) {
              _selecionarCategoriaPersonalizada(customId);
            } else if (padrao != null) {
              _selecionarCategoriaPadrao(padrao);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoriaSection() {
    final List<CategoriaGasto> padrao = _categoriasPadraoFiltradas();
    final List<CategoriaPersonalizada> personalizadas =
        _categoriasPersonalizadasFiltradas();
    final bool compact = MediaQuery.sizeOf(context).width < 420;
    final int colunas = compact ? 2 : 3;

    final List<Widget> recentes = <Widget>[];

    for (final String id in _preferencias.recentesPersonalizadas) {
      final CategoriaPersonalizada? item = _buscarCategoriaAtivaPorId(id);
      if (item == null) {
        continue;
      }
      recentes.add(
        NovoGastoCategoriaQuickChip(
          label: item.nome,
          color: item.cor,
          icon: item.icone,
          onTap: () => _selecionarCategoriaPersonalizada(item.id),
        ),
      );
      if (recentes.length >= 5) {
        break;
      }
    }

    if (recentes.length < 5) {
      for (final CategoriaGasto item in _preferencias.recentesPadrao) {
        recentes.add(
          NovoGastoCategoriaQuickChip(
            label: item.label,
            color: item.color,
            icon: item.icon,
            onTap: () => _selecionarCategoriaPadrao(item),
          ),
        );
        if (recentes.length >= 5) {
          break;
        }
      }
    }

    return NovoGastoCategoriaSection(
      categoriaPersonalizadaAtiva: _categoriaPersonalizadaAtiva,
      buscaCategoriaController: _buscaCategoriaController,
      recentes: recentes,
      categoriasPadrao: padrao,
      categoriasPersonalizadas: personalizadas,
      categoriaPersonalizadaSelecionadaId: _categoriaPersonalizadaSelecionadaId,
      categoriaSelecionada: _categoriaSelecionada,
      onSelecionarCategoriaPadrao: _selecionarCategoriaPadrao,
      onSelecionarCategoriaPersonalizada: _selecionarCategoriaPersonalizada,
      onNovaCategoria: _abrirModalCategoria,
      onAbrirAcoesCategoria: _abrirAcoesCategoriaPersonalizada,
      colunas: colunas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String valorPreview = _formatarValorPreview();
    final Color previewAccent = _categoriaCorPreview;
    final Color previewSurface = Theme.of(context).colorScheme.primaryContainer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Gasto'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      bottomNavigationBar: AppFormSubmitBar(
        onPressed: _salvarGasto,
        label: 'SALVAR GASTO',
        isLoading: _salvando,
      ),
      body: _carregandoPreferencias
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    NovoGastoPreviewCard(
                      titulo: _tituloController.text.trim(),
                      categoriaNome: _categoriaNomePreview,
                      categoriaPersonalizadaAtiva: _categoriaPersonalizadaAtiva,
                      categoriaIcone: _categoriaIconePreview,
                      valorPreview: valorPreview,
                      tipoSelecionado: _tipoSelecionado,
                      dataFormatada: _formatarData(_dataSelecionada),
                      previewAccent: previewAccent,
                      previewSurface: previewSurface,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildSectionCard(
                      child: Column(
                        children: [
                          TextFormField(
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
                          _buildChipSugestao(),
                        ],
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
                        inputFormatters: <TextInputFormatter>[
                          MoedaInputFormatter(),
                        ],
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
                    ),
                    _buildAvisoDuplicados(),
                    const SizedBox(height: AppSpacing.s16),
                    _buildCategoriaSection(),
                    const SizedBox(height: AppSpacing.s16),
                    NovoGastoTipoSection(
                      tipoSelecionado: _tipoSelecionado,
                      onChanged: (tipo) {
                        setState(() {
                          _tipoSelecionado = tipo;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    NovoGastoRecorrenciaSection(
                      ativo: _recorrenciaAtiva,
                      mesesFuturos: _recorrenciaMesesFuturos,
                      carregandoSugestao: _carregandoSugestaoRecorrencia,
                      sugestao: _sugestaoRecorrencia,
                      onAlterarAtivo: (ativo) {
                        setState(() {
                          _recorrenciaAtiva = ativo;
                          _recorrenciaConfiguradaManual = true;
                          if (ativo) {
                            _tipoSelecionado = TipoGasto.fixo;
                          }
                        });
                      },
                      onAlterarMeses: (meses) {
                        setState(() {
                          _recorrenciaMesesFuturos = meses;
                          _recorrenciaConfiguradaManual = true;
                        });
                      },
                      onAplicarSugestao: _aplicarSugestaoRecorrencia,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    NovoGastoDataSection(
                      dataFormatada: _formatarData(_dataSelecionada),
                      onSelecionarData: _selecionarData,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

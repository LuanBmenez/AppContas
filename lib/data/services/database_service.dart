import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paga_o_que_me_deve/core/utils/text_normalizer.dart';
import 'package:paga_o_que_me_deve/domain/models/cartao_credito.dart';
import 'package:paga_o_que_me_deve/domain/models/categoria_personalizada.dart';
import 'package:paga_o_que_me_deve/domain/models/conta.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/guardado.dart';
import 'package:paga_o_que_me_deve/domain/models/preferencias_novo_gasto.dart';
import 'package:paga_o_que_me_deve/domain/models/regra_categoria_importacao.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/domain/services/recorrencia_despesa_service.dart';
import 'package:rxdart/rxdart.dart';

class DatabaseService implements FinanceRepository {
  @override
  Future<({double gastos, double receber, List<String> nomesReceber})>
  buscarResumoParaNotificacao(DateTime data) async {
    final inicioDia = DateTime(data.year, data.month, data.day);
    final fimDia = inicioDia.add(const Duration(days: 1));
    // Busca os gastos do dia
    final gastosSnap = await _gastosCollection
        .where('data', isGreaterThanOrEqualTo: inicioDia)
        .where('data', isLessThan: fimDia)
        .get();

    final receberSnap = await _receberCollection
        .where('data', isGreaterThanOrEqualTo: inicioDia)
        .where('data', isLessThan: fimDia)
        .where('foiPago', isEqualTo: false)
        .get();

    double totalGastos = 0;
    for (final doc in gastosSnap.docs) {
      totalGastos += (doc.data()['valor'] as num).toDouble();
    }

    double totalReceber = 0;
    final nomes = <String>[];

    for (final doc in receberSnap.docs) {
      final dataDoc = doc.data();
      final valor = (dataDoc['valor'] as num).toDouble();
      totalReceber += valor;
      nomes.add("${dataDoc['nome']} (R\$ ${valor.toStringAsFixed(2)})");
    }

    return (gastos: totalGastos, receber: totalReceber, nomesReceber: nomes);
  }

  static bool _persistenciaConfigurada = false;
  DatabaseService() {
    _configurarPersistenciaOffline();
  }

  void _configurarPersistenciaOffline() {
    if (!_persistenciaConfigurada) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        _persistenciaConfigurada = true;
      } catch (e) {
        // Ignora o erro silenciosamente caso o Firestore já tenha sido
      }
    }
  }

  final RecorrenciaDespesaService _recorrenciaDespesaService =
      const RecorrenciaDespesaService();

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Usuario nao autenticado.');
    }
    return user.uid;
  }

  String get _workspaceId => _uid;

  DocumentReference<Map<String, dynamic>> get _workspaceDoc =>
      FirebaseFirestore.instance.collection('workspaces').doc(_workspaceId);

  CollectionReference<Map<String, dynamic>> get _receberCollection =>
      _workspaceDoc.collection('recebiveis');

  CollectionReference<Map<String, dynamic>> get _gastosCollection =>
      _workspaceDoc.collection('gastos');

  CollectionReference<Map<String, dynamic>> get _guardadosCollection =>
      _workspaceDoc.collection('guardados');

  CollectionReference<Map<String, dynamic>> get _cartoesCollection =>
      _workspaceDoc.collection('cartoes');

  CollectionReference<Map<String, dynamic>> get _regrasCategoriaCollection =>
      _workspaceDoc.collection('regras_importacao');

  CollectionReference<Map<String, dynamic>> get _categoriasPersonalizadas =>
      _workspaceDoc.collection('categorias_personalizadas');

  CollectionReference<Map<String, dynamic>> get _preferenciasCollection =>
      _workspaceDoc.collection('preferencias');

  @override
  Future<void> adicionarRecebivel(Conta conta) async {
    final docRef = _receberCollection.doc();
    final agora = DateTime.now();
    final dataRecebimento = conta.recebidaEm ?? (conta.foiPago ? agora : null);

    final contaComId = conta.copyWith(
      id: docRef.id,
      data: conta.data,
      atualizadaEm: agora,
      recebidaEm: dataRecebimento,
      historico: conta.historico.isEmpty
          ? <ContaHistoricoEvento>[
              ContaHistoricoEvento(
                tipo: ContaHistoricoTipo.criada,
                descricao: 'Cobrança criada',
                data: agora,
              ),
              if (conta.foiPago)
                ContaHistoricoEvento(
                  tipo: ContaHistoricoTipo.recebida,
                  descricao: 'Cobrança marcada como recebida',
                  data: dataRecebimento ?? agora,
                ),
            ]
          : conta.historico,
    );

    await docRef.set(contaComId.toMap());
  }

  @override
  Stream<List<Conta>> get contasAReceber {
    return _receberCollection.orderBy('data', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => Conta.fromMap(doc.data(), doc.id))
            .toList();
      },
    );
  }

  @override
  Stream<List<Guardado>> get guardados {
    return _guardadosCollection
        .orderBy('data', descending: true)
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map((doc) => Guardado.fromMap(doc.data(), doc.id))
                .toList();
          },
        );
  }

  @override
  Future<void> alternarStatusRecebivel(String id, bool statusAtual) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final docRef = _receberCollection.doc(id);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        return;
      }

      final atual = Conta.fromMap(
        snapshot.data() ?? <String, dynamic>{},
        id,
      );
      final novoStatus = !statusAtual;
      final agora = DateTime.now();
      final historico = <ContaHistoricoEvento>[
        ...atual.historico,
        ContaHistoricoEvento(
          tipo: novoStatus
              ? ContaHistoricoTipo.recebida
              : ContaHistoricoTipo.reaberta,
          descricao: novoStatus
              ? 'Cobrança marcada como recebida'
              : 'Cobrança reaberta como pendente',
          data: agora,
        ),
      ];

      transaction.set(
        docRef,
        atual
            .copyWith(
              foiPago: novoStatus,
              recebidaEm: novoStatus ? agora : null,
              atualizadaEm: agora,
              historico: historico,
            )
            .toMap(),
        SetOptions(merge: false),
      );
    });
  }

  @override
  Future<void> deletarRecebivel(String id) async {
    await _receberCollection.doc(id).delete();
  }

  @override
  Future<void> atualizarRecebivel(Conta conta) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final docRef = _receberCollection.doc(conta.id);
      final snapshot = await transaction.get(docRef);

      final atual = snapshot.exists
          ? Conta.fromMap(snapshot.data() ?? <String, dynamic>{}, conta.id)
          : conta;
      final agora = DateTime.now();
      final novaRecebidaEm = conta.recebidaEm ?? atual.recebidaEm;
      final virouRecebidaAgora =
          conta.foiPago &&
          novaRecebidaEm != null &&
          atual.recebidaEm != novaRecebidaEm;

      final historico = <ContaHistoricoEvento>[
        ...atual.historico,
        ContaHistoricoEvento(
          tipo: virouRecebidaAgora
              ? ContaHistoricoTipo.recebida
              : ContaHistoricoTipo.atualizada,
          descricao: virouRecebidaAgora
              ? 'Cobrança marcada como recebida'
              : 'Cobrança atualizada',
          data: virouRecebidaAgora ? novaRecebidaEm : agora,
        ),
      ];

      transaction.set(
        docRef,
        conta
            .copyWith(
              id: conta.id,
              data: atual.data,
              recebidaEm: novaRecebidaEm,
              atualizadaEm: agora,
              historico: historico,
            )
            .toMap(),
        SetOptions(merge: false),
      );
    });
  }

  @override
  Future<void> restaurarRecebivel(Conta conta) async {
    await _receberCollection
        .doc(conta.id)
        .set(
          conta
              .copyWith(
                atualizadaEm: DateTime.now(),
                historico: <ContaHistoricoEvento>[
                  ...conta.historico,
                  ContaHistoricoEvento(
                    tipo: ContaHistoricoTipo.atualizada,
                    descricao: 'Cobrança restaurada',
                    data: DateTime.now(),
                  ),
                ],
              )
              .toMap(),
          SetOptions(merge: false),
        );
  }

  @override
  Future<void> salvarGuardado(Guardado guardado) async {
    final docRef = guardado.id.isEmpty
        ? _guardadosCollection.doc()
        : _guardadosCollection.doc(guardado.id);

    final guardadoComId = guardado.copyWith(
      id: docRef.id,
      competencia: Guardado.competenciaFromDate(guardado.data),
    );

    await docRef.set(guardadoComId.toMap());
  }

  @override
  Future<void> atualizarGuardado(Guardado guardado) async {
    final atualizado = guardado.copyWith(
      competencia: Guardado.competenciaFromDate(guardado.data),
    );

    await _guardadosCollection.doc(atualizado.id).set(atualizado.toMap());
  }

  @override
  Future<void> deletarGuardado(String id) async {
    await _guardadosCollection.doc(id).delete();
  }

  @override
  Future<void> adicionarGasto(Gasto gasto) async {
    final docRef = _gastosCollection.doc();
    final gastoComId = gasto.copyWith(id: docRef.id);

    await docRef.set(gastoComId.toMap());
    await _registrarRegraCategoriaAutomatica(gastoComId);
  }

  @override
  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  ) async {
    if (gastos.isEmpty) {
      return const ResultadoImportacaoGastos(importados: 0, duplicados: 0);
    }

    final semHash = <Gasto>[];
    final porHash = <String, Gasto>{};
    var importados = 0;
    var duplicados = 0;

    for (final gasto in gastos) {
      final hash = gasto.hashImportacao;
      if (hash == null || hash.isEmpty) {
        semHash.add(gasto);
        continue;
      }

      if (porHash.containsKey(hash)) {
        duplicados++;
        continue;
      }

      porHash[hash] = gasto;
    }

    importados += await _gravarGastosSemHash(semHash);

    final hashesExistentes = await _buscarHashesExistentes(
      porHash.keys,
    );

    final paraInserir = <MapEntry<String, Gasto>>[];
    for (final entry in porHash.entries) {
      if (hashesExistentes.contains(entry.key)) {
        duplicados++;
      } else {
        paraInserir.add(entry);
      }
    }

    if (paraInserir.isNotEmpty) {
      const tamanhoLote = 200;

      for (var i = 0; i < paraInserir.length; i += tamanhoLote) {
        final fim = (i + tamanhoLote < paraInserir.length)
            ? i + tamanhoLote
            : paraInserir.length;
        final lote = paraInserir.sublist(i, fim);

        final parcial = await FirebaseFirestore.instance.runTransaction((
          transaction,
        ) async {
          var importadosLote = 0;
          var duplicadosLote = 0;
          final verificacoes =
              <
                ({
                  DocumentReference<Map<String, dynamic>> ref,
                  Gasto gasto,
                  DocumentSnapshot<Map<String, dynamic>> snap,
                })
              >[];

          for (final entry in lote) {
            final docRef = _gastosCollection.doc(
              _idDeterministicoImportacao(entry.key),
            );
            final existente = await transaction.get(docRef);

            verificacoes.add((
              ref: docRef,
              gasto: entry.value,
              snap: existente,
            ));
          }

          for (final verificacao in verificacoes) {
            if (verificacao.snap.exists) {
              duplicadosLote++;
              continue;
            }

            transaction.set(
              verificacao.ref,
              verificacao.gasto.copyWith(id: verificacao.ref.id).toMap(),
            );
            importadosLote++;
          }

          return ResultadoImportacaoGastos(
            importados: importadosLote,
            duplicados: duplicadosLote,
          );
        });

        importados += parcial.importados;
        duplicados += parcial.duplicados;
      }
    }

    return ResultadoImportacaoGastos(
      importados: importados,
      duplicados: duplicados,
    );
  }

  @override
  Future<int> contarDuplicadosPorHash(List<String> hashes) async {
    final hashesValidos = hashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList();

    if (hashesValidos.isEmpty) {
      return 0;
    }

    var duplicados = 0;
    for (var i = 0; i < hashesValidos.length; i += 10) {
      final fim = (i + 10 < hashesValidos.length)
          ? i + 10
          : hashesValidos.length;
      final lote = hashesValidos.sublist(i, fim);

      final encontrados = await _gastosCollection
          .where('hashImportacao', whereIn: lote)
          .get();
      duplicados += encontrados.docs.length;
    }

    return duplicados;
  }

  @override
  Stream<List<Gasto>> get meusGastos {
    return _gastosCollection.orderBy('data', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => Gasto.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<List<Gasto>> streamGastosPorPeriodo({
    required DateTime inicio,
    required DateTime fimExclusivo,
    int? limite,
  }) {
    var query = _gastosCollection
        .where('data', isGreaterThanOrEqualTo: inicio)
        .where('data', isLessThan: fimExclusivo)
        .orderBy('data', descending: true);

    if (limite != null && limite > 0) {
      query = query.limit(limite);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Gasto.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<PaginaGastosResultado> buscarGastosPorPeriodoPaginado({
    required DateTime inicio,
    required DateTime fimExclusivo,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int limite = 80,
  }) async {
    var query = _gastosCollection
        .where('data', isGreaterThanOrEqualTo: inicio)
        .where('data', isLessThan: fimExclusivo)
        .orderBy('data', descending: true)
        .limit(limite);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final gastos = snapshot.docs
        .map((doc) => Gasto.fromMap(doc.data(), doc.id))
        .toList();

    return PaginaGastosResultado(
      gastos: gastos,
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : cursor,
      temMais: snapshot.docs.length == limite,
    );
  }

  @override
  Stream<DashboardResumo> get dashboardResumo {
    return Rx.combineLatest2<List<Gasto>, List<Conta>, DashboardResumo>(
      meusGastos,
      contasAReceber,
      DashboardResumo.new,
    );
  }

  @override
  Future<void> deletarGasto(String id) async {
    await _gastosCollection.doc(id).delete();
  }

  @override
  Future<void> atualizarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
    await _registrarRegraCategoriaAutomatica(gasto);
  }

  @override
  Future<void> restaurarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
  }

  @override
  Future<void> adicionarCartaoCredito(CartaoCredito cartao) async {
    final docRef = _cartoesCollection.doc();
    final cartaoComId = cartao.copyWith(id: docRef.id);

    await docRef.set(cartaoComId.toMap());
  }

  @override
  Stream<List<CartaoCredito>> get cartoesCredito {
    return _cartoesCollection.orderBy('nome').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CartaoCredito.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> deletarCartaoCredito(String id) async {
    await _cartoesCollection.doc(id).delete();
  }

  @override
  Stream<List<CategoriaPersonalizada>> get categoriasPersonalizadas {
    return _categoriasPersonalizadas
        .orderBy('favorita', descending: true)
        .orderBy('usoCount', descending: true)
        .orderBy('nome')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CategoriaPersonalizada.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  @override
  Future<void> salvarCategoriaPersonalizada(CategoriaPersonalizada categoria) {
    final now = DateTime.now();
    final docRef = categoria.id.isEmpty
        ? _categoriasPersonalizadas.doc()
        : _categoriasPersonalizadas.doc(categoria.id);

    final atualizado = categoria.copyWith(
      id: docRef.id,
      criadaEm: categoria.criadaEm ?? now,
      atualizadaEm: now,
    );

    return docRef.set(atualizado.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> arquivarCategoriaPersonalizada(String id, bool arquivada) {
    return _categoriasPersonalizadas.doc(id).set({
      'arquivada': arquivada,
      'atualizadaEm': DateTime.now(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> alternarFavoritaCategoriaPersonalizada(
    String id,
    bool favorita,
  ) {
    return _categoriasPersonalizadas.doc(id).set({
      'favorita': favorita,
      'atualizadaEm': DateTime.now(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deletarCategoriaPersonalizada(String id) async {
    await _categoriasPersonalizadas.doc(id).delete();
  }

  @override
  Future<bool> categoriaPersonalizadaEmUso(String id) async {
    final snapshot = await _gastosCollection
        .where('categoriaPersonalizadaId', isEqualTo: id)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<PreferenciasNovoGasto> carregarPreferenciasNovoGasto() async {
    final doc = await _preferenciasCollection.doc('novo_gasto').get();

    final data = doc.data() ?? <String, dynamic>{};
    final recentesPadraoRaw =
        (data['recentesPadrao'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e.toString())
            .toList();
    final recentesPadrao = recentesPadraoRaw
        .map(
          (nome) => CategoriaGasto.values.firstWhere(
            (e) => e.name == nome,
            orElse: () => CategoriaGasto.outros,
          ),
        )
        .toList();

    return PreferenciasNovoGasto(
      ultimaCategoriaPadrao: _parseCategoria(data['ultimaCategoriaPadrao']),
      ultimaCategoriaPersonalizadaId: data['ultimaCategoriaPersonalizadaId']
          ?.toString(),
      ultimoTipo: _parseTipo(data['ultimoTipo']),
      recentesPadrao: recentesPadrao,
      recentesPersonalizadas:
          (data['recentesPersonalizadas'] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList(),
    );
  }

  @override
  Future<void> registrarUsoNovoGasto({
    required TipoGasto tipo,
    CategoriaGasto? categoriaPadrao,
    String? categoriaPersonalizadaId,
  }) async {
    final docRef = _preferenciasCollection.doc('novo_gasto');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final recentesPadrao =
          (data['recentesPadrao'] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList();
      final recentesPersonalizadas =
          (data['recentesPersonalizadas'] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList();

      if (categoriaPadrao != null) {
        recentesPadrao.remove(categoriaPadrao.name);
        recentesPadrao.insert(0, categoriaPadrao.name);
      }

      if (categoriaPersonalizadaId != null &&
          categoriaPersonalizadaId.isNotEmpty) {
        recentesPersonalizadas.remove(categoriaPersonalizadaId);
        recentesPersonalizadas.insert(0, categoriaPersonalizadaId);
      }

      tx.set(docRef, {
        'ultimaCategoriaPadrao': categoriaPadrao?.name,
        'ultimaCategoriaPersonalizadaId': categoriaPersonalizadaId,
        'ultimoTipo': tipo.name,
        'recentesPadrao': recentesPadrao.take(5).toList(),
        'recentesPersonalizadas': recentesPersonalizadas.take(5).toList(),
        'atualizadoEm': DateTime.now(),
      }, SetOptions(merge: true));

      if (categoriaPersonalizadaId != null &&
          categoriaPersonalizadaId.isNotEmpty) {
        tx.set(
          _categoriasPersonalizadas.doc(categoriaPersonalizadaId),
          {'usoCount': FieldValue.increment(1), 'atualizadaEm': DateTime.now()},
          SetOptions(merge: true),
        );
      }
    });
  }

  @override
  Stream<List<RegraCategoriaImportacao>> get regrasCategoriaImportacao {
    return _regrasCategoriaCollection.orderBy('termo').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => RegraCategoriaImportacao.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> salvarRegraCategoriaImportacao({
    required String termo,
    required CategoriaGasto categoria,
  }) async {
    final termoNormalizado = _normalizarTextoBusca(termo);
    if (termoNormalizado.isEmpty) {
      return;
    }

    await _regrasCategoriaCollection.doc(termoNormalizado).set({
      'termo': termoNormalizado,
      'categoria': categoria.name,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<SugestaoRecorrenciaDespesa?> sugerirRecorrenciaPorTitulo(
    String titulo,
  ) async {
    final tituloNormalizado = _normalizarTextoBusca(titulo);
    if (tituloNormalizado.length < 3) {
      return null;
    }

    var candidatos = <Gasto>[];

    final queryDireta = await _gastosCollection
        .where('tituloNormalizado', isEqualTo: tituloNormalizado)
        .limit(24)
        .get();
    candidatos = queryDireta.docs
        .map((doc) => Gasto.fromMap(doc.data(), doc.id))
        .toList();

    if (candidatos.length < 3) {
      final fallback = await _gastosCollection
          .orderBy('data', descending: true)
          .limit(300)
          .get();
      candidatos = fallback.docs
          .map((doc) => Gasto.fromMap(doc.data(), doc.id))
          .where(
            (gasto) => _normalizarTextoBusca(gasto.titulo) == tituloNormalizado,
          )
          .toList();
    }

    return _recorrenciaDespesaService.detectarMensal(candidatos);
  }

  @override
  Future<RelatorioMensalFinanceiro> buscarRelatorioMensal(
    DateTime referencia,
  ) async {
    final inicioMes = DateTime(referencia.year, referencia.month);
    final fimMes = DateTime(referencia.year, referencia.month + 1);

    final gastosSnapshot = await _gastosCollection
        .where('data', isGreaterThanOrEqualTo: inicioMes)
        .where('data', isLessThan: fimMes)
        .orderBy('data', descending: true)
        .get();

    final gastos = gastosSnapshot.docs
        .map((doc) => Gasto.fromMap(doc.data(), doc.id))
        .toList();

    final pendentesSnapshot = await _receberCollection
        .where('foiPago', isEqualTo: false)
        .get();
    final pendentes = pendentesSnapshot.docs
        .map((doc) => Conta.fromMap(doc.data(), doc.id))
        .toList();

    final totalPorCategoria = <CategoriaGasto, double>{};
    for (final gasto in gastos) {
      totalPorCategoria[gasto.categoria] =
          (totalPorCategoria[gasto.categoria] ?? 0) + gasto.valor;
    }

    return RelatorioMensalFinanceiro(
      mesReferencia: inicioMes,
      gastosMes: gastos,
      contasPendentes: pendentes,
      totalPorCategoria: totalPorCategoria,
    );
  }

  String _normalizarTextoBusca(String texto) =>
      TextNormalizer.normalizeForSearch(texto);

  CategoriaGasto? _parseCategoria(dynamic raw) {
    if (raw == null) return null;
    return CategoriaGasto.values.asNameMap()[raw.toString()];
  }

  TipoGasto? _parseTipo(dynamic raw) {
    if (raw == null) return null;
    return TipoGasto.values.asNameMap()[raw.toString()];
  }

  Future<int> _gravarGastosSemHash(List<Gasto> gastos) async {
    if (gastos.isEmpty) {
      return 0;
    }

    var importados = 0;
    for (var i = 0; i < gastos.length; i += 450) {
      final fim = (i + 450 < gastos.length) ? i + 450 : gastos.length;
      final batch = FirebaseFirestore.instance.batch();

      for (final gasto in gastos.sublist(i, fim)) {
        final docRef = _gastosCollection.doc();
        batch.set(docRef, gasto.copyWith(id: docRef.id).toMap());
        importados++;
      }

      await batch.commit();
    }

    return importados;
  }

  Future<Set<String>> _buscarHashesExistentes(Iterable<String> hashes) async {
    final hashesValidos = hashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList();

    if (hashesValidos.isEmpty) {
      return <String>{};
    }

    final existentes = <String>{};
    for (var i = 0; i < hashesValidos.length; i += 10) {
      final fim = (i + 10 < hashesValidos.length)
          ? i + 10
          : hashesValidos.length;
      final lote = hashesValidos.sublist(i, fim);

      final encontrados = await _gastosCollection
          .where('hashImportacao', whereIn: lote)
          .get();
      for (final doc in encontrados.docs) {
        final hash = (doc.data()['hashImportacao'] ?? '').toString();
        if (hash.isNotEmpty) {
          existentes.add(hash);
        }
      }
    }

    return existentes;
  }

  String _idDeterministicoImportacao(String hash) {
    return 'imp_$hash';
  }

  Future<void> _registrarRegraCategoriaAutomatica(Gasto gasto) async {
    if (gasto.origem != OrigemGasto.manual) {
      return;
    }
    if (gasto.categoria == CategoriaGasto.outros) {
      return;
    }

    final termo = _extrairTermoAprendizado(gasto.titulo);
    if (termo == null) {
      return;
    }

    await salvarRegraCategoriaImportacao(
      termo: termo,
      categoria: gasto.categoria,
    );
  }

  String? _extrairTermoAprendizado(String titulo) {
    final normalizado = _normalizarTextoBusca(titulo);
    if (normalizado.isEmpty) {
      return null;
    }

    const stopwords = <String>{
      'COMPRA',
      'PAGAMENTO',
      'PAGTO',
      'PGTO',
      'PARCELA',
      'FATURA',
      'CREDITO',
      'DEBITO',
      'CARTAO',
      'TRANSFERENCIA',
      'ONLINE',
      'PIX',
      'VIA',
      'APP',
    };

    final tokens = normalizado
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.length >= 3)
        .where((t) => !RegExp(r'^\d+$').hasMatch(t))
        .where((t) => !stopwords.contains(t))
        .toList();

    if (tokens.isEmpty) {
      return null;
    }

    return tokens.first;
  }
}

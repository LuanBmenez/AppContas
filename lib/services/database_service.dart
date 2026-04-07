import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../domain/repositories/finance_repository.dart';
import '../models/cartao_credito_model.dart';
import '../models/categoria_personalizada_model.dart';
import '../models/conta_model.dart';
import '../models/gasto_model.dart';
import '../models/preferencias_novo_gasto_model.dart';
import '../models/regra_categoria_importacao_model.dart';
import '../utils/text_normalizer.dart';

class DatabaseService implements FinanceRepository {
  final CollectionReference<Map<String, dynamic>> _receberCollection =
      FirebaseFirestore.instance.collection('a_receber');
  final CollectionReference<Map<String, dynamic>> _gastosCollection =
      FirebaseFirestore.instance.collection('meus_gastos');
  final CollectionReference<Map<String, dynamic>> _cartoesCollection =
      FirebaseFirestore.instance.collection('cartoes_credito');
  final CollectionReference<Map<String, dynamic>> _regrasCategoriaCollection =
      FirebaseFirestore.instance.collection('regras_categoria_importacao');
  final CollectionReference<Map<String, dynamic>> _categoriasPersonalizadas =
      FirebaseFirestore.instance.collection('categorias_personalizadas');
  final CollectionReference<Map<String, dynamic>> _preferenciasCollection =
      FirebaseFirestore.instance.collection('preferencias_app');

  @override
  Future<void> adicionarRecebivel(Conta conta) async {
    final DocumentReference<Map<String, dynamic>> docRef = _receberCollection
        .doc();
    final DateTime agora = DateTime.now();
    final Conta contaComId = conta.copyWith(
      id: docRef.id,
      data: conta.data,
      atualizadaEm: agora,
      recebidaEm: conta.foiPago ? agora : conta.recebidaEm,
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
                  data: agora,
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
  Future<void> alternarStatusRecebivel(String id, bool statusAtual) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final DocumentReference<Map<String, dynamic>> docRef = _receberCollection
          .doc(id);
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(docRef);

      if (!snapshot.exists) {
        return;
      }

      final Conta atual = Conta.fromMap(
        snapshot.data() ?? <String, dynamic>{},
        id,
      );
      final bool novoStatus = !statusAtual;
      final DateTime agora = DateTime.now();
      final List<ContaHistoricoEvento> historico = <ContaHistoricoEvento>[
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
      final DocumentReference<Map<String, dynamic>> docRef = _receberCollection
          .doc(conta.id);
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(docRef);

      final Conta atual = snapshot.exists
          ? Conta.fromMap(snapshot.data() ?? <String, dynamic>{}, conta.id)
          : conta;
      final DateTime agora = DateTime.now();
      final List<ContaHistoricoEvento> historico = <ContaHistoricoEvento>[
        ...atual.historico,
        ContaHistoricoEvento(
          tipo: ContaHistoricoTipo.atualizada,
          descricao: 'Cobrança atualizada',
          data: agora,
        ),
      ];

      transaction.set(
        docRef,
        conta
            .copyWith(
              id: conta.id,
              data: atual.data,
              recebidaEm: atual.recebidaEm,
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
  Future<void> adicionarGasto(Gasto gasto) async {
    final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
        .doc();
    final Gasto gastoComId = gasto.copyWith(id: docRef.id);

    await docRef.set(gastoComId.toMap());
  }

  @override
  Future<ResultadoImportacaoGastos> importarGastosComDeduplicacao(
    List<Gasto> gastos,
  ) async {
    if (gastos.isEmpty) {
      return const ResultadoImportacaoGastos(importados: 0, duplicados: 0);
    }

    final List<Gasto> semHash = <Gasto>[];
    final Map<String, Gasto> porHash = <String, Gasto>{};
    int importados = 0;
    int duplicados = 0;

    for (final Gasto gasto in gastos) {
      final String? hash = gasto.hashImportacao;
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

    final Set<String> hashesExistentes = await _buscarHashesExistentes(
      porHash.keys,
    );

    final List<MapEntry<String, Gasto>> paraInserir =
        <MapEntry<String, Gasto>>[];
    for (final MapEntry<String, Gasto> entry in porHash.entries) {
      if (hashesExistentes.contains(entry.key)) {
        duplicados++;
      } else {
        paraInserir.add(entry);
      }
    }

    if (paraInserir.isNotEmpty) {
      const int tamanhoLote = 200;

      for (int i = 0; i < paraInserir.length; i += tamanhoLote) {
        final int fim = (i + tamanhoLote < paraInserir.length)
            ? i + tamanhoLote
            : paraInserir.length;
        final List<MapEntry<String, Gasto>> lote = paraInserir.sublist(i, fim);

        final ResultadoImportacaoGastos parcial = await FirebaseFirestore
            .instance
            .runTransaction((transaction) async {
              int importadosLote = 0;
              int duplicadosLote = 0;

              for (final MapEntry<String, Gasto> entry in lote) {
                final DocumentReference<Map<String, dynamic>> docRef =
                    _gastosCollection.doc(
                      _idDeterministicoImportacao(entry.key),
                    );
                final DocumentSnapshot<Map<String, dynamic>> existente =
                    await transaction.get(docRef);

                if (existente.exists) {
                  duplicadosLote++;
                  continue;
                }

                transaction.set(
                  docRef,
                  entry.value.copyWith(id: docRef.id).toMap(),
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
    final List<String> hashesValidos = hashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList();

    if (hashesValidos.isEmpty) {
      return 0;
    }

    int duplicados = 0;
    for (int i = 0; i < hashesValidos.length; i += 10) {
      final int fim = (i + 10 < hashesValidos.length)
          ? i + 10
          : hashesValidos.length;
      final List<String> lote = hashesValidos.sublist(i, fim);

      final QuerySnapshot<Map<String, dynamic>> encontrados =
          await _gastosCollection.where('hashImportacao', whereIn: lote).get();
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
    Query<Map<String, dynamic>> query = _gastosCollection
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
    Query<Map<String, dynamic>> query = _gastosCollection
        .where('data', isGreaterThanOrEqualTo: inicio)
        .where('data', isLessThan: fimExclusivo)
        .orderBy('data', descending: true)
        .limit(limite);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    final List<Gasto> gastos = snapshot.docs
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
      (gastos, contas) => DashboardResumo(gastos, contas),
    );
  }

  @override
  Future<void> deletarGasto(String id) async {
    await _gastosCollection.doc(id).delete();
  }

  @override
  Future<void> atualizarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
  }

  @override
  Future<void> restaurarGasto(Gasto gasto) async {
    await _gastosCollection.doc(gasto.id).set(gasto.toMap());
  }

  @override
  Future<void> adicionarCartaoCredito(CartaoCredito cartao) async {
    final DocumentReference<Map<String, dynamic>> docRef = _cartoesCollection
        .doc();
    final CartaoCredito cartaoComId = cartao.copyWith(id: docRef.id);

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
    final DateTime now = DateTime.now();
    final DocumentReference<Map<String, dynamic>> docRef = categoria.id.isEmpty
        ? _categoriasPersonalizadas.doc()
        : _categoriasPersonalizadas.doc(categoria.id);

    final CategoriaPersonalizada atualizado = categoria.copyWith(
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
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _gastosCollection
        .where('categoriaPersonalizadaId', isEqualTo: id)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<PreferenciasNovoGasto> carregarPreferenciasNovoGasto() async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _preferenciasCollection.doc('novo_gasto').get();

    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final List<String> recentesPadraoRaw =
        (data['recentesPadrao'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e.toString())
            .toList();
    final List<CategoriaGasto> recentesPadrao = recentesPadraoRaw
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
    CategoriaGasto? categoriaPadrao,
    String? categoriaPersonalizadaId,
    required TipoGasto tipo,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        _preferenciasCollection.doc('novo_gasto');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(docRef);
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      final List<String> recentesPadrao =
          (data['recentesPadrao'] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList();
      final List<String> recentesPersonalizadas =
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
    final String termoNormalizado = _normalizarTextoBusca(termo);
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
  Future<RelatorioMensalFinanceiro> buscarRelatorioMensal(
    DateTime referencia,
  ) async {
    final DateTime inicioMes = DateTime(referencia.year, referencia.month, 1);
    final DateTime fimMes = DateTime(referencia.year, referencia.month + 1, 1);

    final QuerySnapshot<Map<String, dynamic>> gastosSnapshot =
        await _gastosCollection
            .where('data', isGreaterThanOrEqualTo: inicioMes)
            .where('data', isLessThan: fimMes)
            .orderBy('data', descending: true)
            .get();

    final List<Gasto> gastos = gastosSnapshot.docs
        .map((doc) => Gasto.fromMap(doc.data(), doc.id))
        .toList();

    final QuerySnapshot<Map<String, dynamic>> pendentesSnapshot =
        await _receberCollection.where('foiPago', isEqualTo: false).get();
    final List<Conta> pendentes = pendentesSnapshot.docs
        .map((doc) => Conta.fromMap(doc.data(), doc.id))
        .toList();

    final Map<CategoriaGasto, double> totalPorCategoria =
        <CategoriaGasto, double>{};
    for (final Gasto gasto in gastos) {
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
    if (raw == null) {
      return null;
    }
    final String valor = raw.toString();
    for (final CategoriaGasto item in CategoriaGasto.values) {
      if (item.name == valor) {
        return item;
      }
    }
    return null;
  }

  TipoGasto? _parseTipo(dynamic raw) {
    if (raw == null) {
      return null;
    }
    final String valor = raw.toString();
    for (final TipoGasto item in TipoGasto.values) {
      if (item.name == valor) {
        return item;
      }
    }
    return null;
  }

  Future<int> _gravarGastosSemHash(List<Gasto> gastos) async {
    if (gastos.isEmpty) {
      return 0;
    }

    int importados = 0;
    for (int i = 0; i < gastos.length; i += 450) {
      final int fim = (i + 450 < gastos.length) ? i + 450 : gastos.length;
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      for (final Gasto gasto in gastos.sublist(i, fim)) {
        final DocumentReference<Map<String, dynamic>> docRef = _gastosCollection
            .doc();
        batch.set(docRef, gasto.copyWith(id: docRef.id).toMap());
        importados++;
      }

      await batch.commit();
    }

    return importados;
  }

  Future<Set<String>> _buscarHashesExistentes(Iterable<String> hashes) async {
    final List<String> hashesValidos = hashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList();

    if (hashesValidos.isEmpty) {
      return <String>{};
    }

    final Set<String> existentes = <String>{};
    for (int i = 0; i < hashesValidos.length; i += 10) {
      final int fim = (i + 10 < hashesValidos.length)
          ? i + 10
          : hashesValidos.length;
      final List<String> lote = hashesValidos.sublist(i, fim);

      final QuerySnapshot<Map<String, dynamic>> encontrados =
          await _gastosCollection.where('hashImportacao', whereIn: lote).get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in encontrados.docs) {
        final String hash = (doc.data()['hashImportacao'] ?? '').toString();
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
}

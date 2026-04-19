import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paga_o_que_me_deve/domain/models/gasto.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';
import 'package:paga_o_que_me_deve/features/orcamentos/domain/models/orcamento_categoria.dart';
import 'package:rxdart/rxdart.dart';

class OrcamentosService {
  OrcamentosService({
    required FinanceRepository repository,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _repository = repository,
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FinanceRepository _repository;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Usuario nao autenticado.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _orcamentosCollection {
    return _firestore
        .collection('workspaces')
        .doc(_uid)
        .collection('orcamentos_categoria');
  }

  Stream<List<OrcamentoCategoria>> listarOrcamentos() {
    return _auth.authStateChanges().startWith(_auth.currentUser).switchMap((
      user,
    ) {
      if (user == null) {
        return Stream<List<OrcamentoCategoria>>.value(<OrcamentoCategoria>[]);
      }

      return _firestore
          .collection('workspaces')
          .doc(user.uid)
          .collection('orcamentos_categoria')
          .snapshots()
          .map((snapshot) {
            final itens = snapshot.docs
                .map((doc) => OrcamentoCategoria.fromMap(doc.data(), doc.id))
                .toList();

            itens.sort(
              (a, b) =>
                  a.categoriaPadrao.index.compareTo(b.categoriaPadrao.index),
            );

            return itens;
          });
    });
  }

  Future<void> criarOrcamento({
    required CategoriaGasto categoriaPadrao,
    required double valorLimite,
  }) async {
    final existente = await _orcamentosCollection
        .where('categoriaPadrao', isEqualTo: categoriaPadrao.name)
        .limit(1)
        .get();

    if (existente.docs.isNotEmpty) {
      final ref = existente.docs.first.reference;
      await ref.set({
        'categoriaPadrao': categoriaPadrao.name,
        'valorLimite': valorLimite,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await _orcamentosCollection.add({
      'categoriaPadrao': categoriaPadrao.name,
      'valorLimite': valorLimite,
      'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> atualizarOrcamento({
    required String id,
    required CategoriaGasto categoriaPadrao,
    required double valorLimite,
  }) {
    return _orcamentosCollection.doc(id).set({
      'categoriaPadrao': categoriaPadrao.name,
      'valorLimite': valorLimite,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deletarOrcamento(String id) {
    return _orcamentosCollection.doc(id).delete();
  }

  Stream<List<OrcamentoCategoriaResumo>> calcularResumoPorCategoria(
    DateTime mesReferencia, {
    int? limite,
  }) {
    final inicio = DateTime(
      mesReferencia.year,
      mesReferencia.month,
    );
    final fimExclusivo = DateTime(
      mesReferencia.year,
      mesReferencia.month + 1,
    );

    final orcamentosStream = listarOrcamentos().startWith(
      const <OrcamentoCategoria>[],
    );
    final gastosStream = _repository
        .streamGastosPorPeriodo(inicio: inicio, fimExclusivo: fimExclusivo)
        .startWith(const <Gasto>[]);

    return Rx.combineLatest2<
          List<OrcamentoCategoria>,
          List<Gasto>,
          List<OrcamentoCategoriaResumo>
        >(orcamentosStream, gastosStream, (orcamentos, gastosMes) {
          final totais = <CategoriaGasto, double>{};

          for (final gasto in gastosMes) {
            if (gasto.usaCategoriaPersonalizada) {
              continue;
            }
            totais[gasto.categoria] =
                (totais[gasto.categoria] ?? 0) + gasto.valor;
          }

          final resumos =
              orcamentos.map((orc) {
                final valorGasto = totais[orc.categoriaPadrao] ?? 0;
                final limiteCategoria = orc.valorLimite;
                final percentual = limiteCategoria <= 0
                    ? 0.00
                    : valorGasto / limiteCategoria;
                final restante = limiteCategoria - valorGasto;

                final OrcamentoCategoriaStatus status;
                if (percentual >= 1) {
                  status = OrcamentoCategoriaStatus.estourado;
                } else if (percentual >= 0.8) {
                  status = OrcamentoCategoriaStatus.alerta;
                } else {
                  status = OrcamentoCategoriaStatus.normal;
                }

                return OrcamentoCategoriaResumo(
                  orcamento: orc,
                  valorGasto: valorGasto,
                  valorRestante: restante,
                  percentualUtilizado: percentual,
                  status: status,
                );
              }).toList()..sort(
                (a, b) =>
                    b.percentualUtilizado.compareTo(a.percentualUtilizado),
              );

          if (limite != null && limite > 0 && resumos.length > limite) {
            return resumos.take(limite).toList();
          }

          return resumos;
        })
        .shareReplay(maxSize: 1);
  }
}

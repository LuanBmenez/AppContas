import 'package:paga_o_que_me_deve/domain/models/recebimento.dart';

abstract class RecebimentosRepository {
  Stream<List<Recebimento>> streamRecebimentosPorMes(String competenciaMes);
  Future<void> salvarRecebimento(Recebimento recebimento);
  Future<void> deletarRecebimento(String id);
}

import 'package:paga_o_que_me_deve/domain/models/models.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class GuardadoService {
  const GuardadoService(this._repository);

  final FinanceRepository _repository;

  Stream<List<Guardado>> get guardados => _repository.guardados;

  Future<void> salvarGuardado(Guardado guardado) {
    return _repository.salvarGuardado(guardado);
  }

  Future<void> atualizarGuardado(Guardado guardado) {
    return _repository.atualizarGuardado(guardado);
  }

  Future<void> deletarGuardado(String id) {
    return _repository.deletarGuardado(id);
  }
}

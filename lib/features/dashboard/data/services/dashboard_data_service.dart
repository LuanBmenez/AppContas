import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class DashboardDataService {
  const DashboardDataService(this._repository);

  final FinanceRepository _repository;

  Stream<DashboardResumo> get dashboardResumo => _repository.dashboardResumo;

  Future<RelatorioMensalFinanceiro> buscarRelatorioMensal(DateTime referencia) {
    return _repository.buscarRelatorioMensal(referencia);
  }
}

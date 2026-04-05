import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static const List<String> _meses = <String>[
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static String moeda(double valor) {
    final String numero = valor.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $numero';
  }

  static double parseMoedaInput(String input) {
    final String limpo = input
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '');

    if (limpo.isEmpty) {
      throw const FormatException('Valor vazio.');
    }

    try {
      final NumberFormat br = NumberFormat.decimalPattern('pt_BR');
      final num parsed = br.parse(limpo);
      return parsed.toDouble();
    } catch (_) {
      // Fallback para entradas parcialmente normalizadas.
      final String normalizado = limpo.replaceAll('.', '').replaceAll(',', '.');
      final double? valor = double.tryParse(normalizado);
      if (valor == null) {
        throw FormatException('Valor invalido: $input');
      }
      return valor;
    }
  }

  static String dataCurta(DateTime data) {
    final String dia = data.day.toString().padLeft(2, '0');
    final String mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  static String mesAno(DateTime data) {
    return '${_meses[data.month - 1]} de ${data.year}';
  }

  static String nomeMes(int mes) {
    return _meses[mes - 1];
  }
}

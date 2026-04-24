import 'package:flutter/services.dart';
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
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    return formatter.format(valor);
  }

  static double parseMoedaInput(String input) {
    final limpo = input
        .replaceAll(r'R$', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp('[^0-9,.-]'), '');

    if (limpo.isEmpty) {
      throw const FormatException('Valor vazio.');
    }

    try {
      final br = NumberFormat.decimalPattern('pt_BR');
      final parsed = br.parse(limpo);
      return parsed.toDouble();
    } catch (_) {
      final normalizado = limpo.replaceAll('.', '').replaceAll(',', '.');
      final valor = double.tryParse(normalizado);
      if (valor == null) {
        throw FormatException('Valor invalido: $input');
      }
      return valor;
    }
  }

  /// Usa o DateFormat para garantir o padrão dd/MM/yyyy facilmente
  static String dataCurta(DateTime data) {
    return DateFormat('dd/MM/yyyy').format(data);
  }

  static String mesAno(DateTime data) {
    return '${_meses[data.month - 1]} de ${data.year}';
  }

  static String nomeMes(int mes) {
    return _meses[mes - 1];
  }
}

class MoedaInputFormatter extends TextInputFormatter {
  MoedaInputFormatter()
    : _formatter = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
        decimalDigits: 2,
      );

  final NumberFormat _formatter;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp('[^0-9]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    final value = double.parse(digits) / 100;
    final formatted = _formatter.format(value).replaceAll('\u00A0', ' ').trim();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

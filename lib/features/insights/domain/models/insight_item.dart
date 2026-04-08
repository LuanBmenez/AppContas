import 'package:flutter/material.dart';

enum InsightNivel { alerta, atencao, info }

class InsightItem {
  const InsightItem({
    required this.nivel,
    required this.mensagem,
    required this.icone,
  });

  final InsightNivel nivel;
  final String mensagem;
  final IconData icone;
}

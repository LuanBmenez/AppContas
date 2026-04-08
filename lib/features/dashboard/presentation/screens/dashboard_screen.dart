import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paga_o_que_me_deve/app/routes/app_routes.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.db, this.onTapSaidas});

  final FinanceRepository db;
  final VoidCallback? onTapSaidas;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            _buildHeader(theme),
            const SizedBox(height: 20),
            _buildResumoCard(theme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    titulo: 'Saídas',
                    subtitulo: 'Ver e gerenciar gastos',
                    icon: Icons.arrow_downward_rounded,
                    color: theme.colorScheme.error,
                    onTap:
                        onTapSaidas ??
                        () {
                          context.push(AppRoutes.gastosPath);
                        },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    titulo: 'Recebimentos',
                    subtitulo: 'Abrir nova tela de recebimentos',
                    icon: Icons.account_balance_wallet_outlined,
                    color: theme.colorScheme.primary,
                    onTap: () {
                      context.push(AppRoutes.receberPath);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    titulo: 'Orçamentos',
                    subtitulo: 'Acompanhar limites por categoria',
                    icon: Icons.pie_chart_outline_rounded,
                    color: Colors.orange,
                    onTap: () {
                      context.push(AppRoutes.orcamentosPath);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    titulo: 'Importar CSV',
                    subtitulo: 'Trazer lançamentos do cartão',
                    icon: Icons.upload_file_outlined,
                    color: Colors.teal,
                    onTap: () {
                      context.push(AppRoutes.importarPath);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQuickActions(theme, context),
            const SizedBox(height: 20),
            _buildInfoCard(
              theme: theme,
              titulo: 'Dashboard estabilizada',
              descricao:
                  'Esta versão removeu os trechos quebrados da integração anterior e mantém a navegação principal funcionando.',
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              theme: theme,
              titulo: 'Próximo passo',
              descricao:
                  'Depois que o projeto voltar a compilar, o ideal é reintegrar os serviços reais do dashboard usando os arquivos originais do repositório.',
              icon: Icons.build_circle_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo financeiro',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Painel principal do app',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildResumoCard(ThemeData theme) {
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ??
        const AppSemanticColors(
          success: Color(0xFF0F9D7A),
          successContainer: Color(0xFFE5F6F2),
          warning: Color(0xFFC26A00),
          warningContainer: Color(0xFFFFEED9),
          error: Color(0xFFD64545),
          errorContainer: Color(0xFFFDE8E8),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [semantic.success, semantic.success.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: semantic.success.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppFormatters.moeda(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Versão segura para restaurar a compilação e manter a navegação do app funcionando.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ações rápidas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.novoGastoPath),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Novo gasto'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.novoRecebivelPath),
                icon: const Icon(Icons.attach_money_rounded),
                label: const Text('Novo recebível'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.cartoesPath),
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Cartões'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.recorrenciasPath),
                icon: const Icon(Icons.repeat_rounded),
                label: const Text('Recorrências'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required String titulo,
    required String descricao,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descricao,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.titulo,
    required this.subtitulo,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitulo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

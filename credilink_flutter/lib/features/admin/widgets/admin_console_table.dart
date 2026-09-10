import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';

/// Dense table-style panel for Admin web directories (stores / users).
class AdminConsoleTable extends StatelessWidget {
  const AdminConsoleTable({
    super.key,
    required this.columns,
    required this.rows,
    this.empty,
  });

  final List<String> columns;
  final List<AdminConsoleTableRow> rows;
  final Widget? empty;

  static bool get isConsoleLayout => kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return empty ??
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CredTheme.spaceLg),
            child: Center(child: Text('No results')),
          );
    }

    return Container(
      decoration: BoxDecoration(
        color: CredTheme.cardBackground,
        borderRadius: BorderRadius.circular(CredTheme.radiusCard),
        border: Border.all(color: CredTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: CredTheme.inputBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    flex: i == 0 ? 3 : 2,
                    child: Text(
                      columns[i],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CredTheme.subtitleText,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: CredTheme.border),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: CredTheme.border),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: rows[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      for (var c = 0; c < rows[i].cells.length; c++)
                        Expanded(
                          flex: c == 0 ? 3 : 2,
                          child: rows[i].cells[c],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminConsoleTableRow {
  const AdminConsoleTableRow({
    required this.cells,
    this.onTap,
  });

  final List<Widget> cells;
  final VoidCallback? onTap;
}

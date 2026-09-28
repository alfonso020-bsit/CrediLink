import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/cred_theme.dart';
import '../../../shared/widgets/common/empty_state.dart';

/// One header in an admin directory table.
///
/// [width] keeps a short column (status, actions) from stretching.
/// Other columns share the remaining space by [flex].
class AdminConsoleColumn {
  const AdminConsoleColumn(
    this.label, {
    this.flex = 1,
    this.width,
  });

  final String label;
  final int flex;
  final double? width;
}

/// Dense table-style panel for Admin web directories (stores / users).
class AdminConsoleTable extends StatelessWidget {
  const AdminConsoleTable({
    super.key,
    required this.columns,
    required this.rows,
    this.empty,
  });

  final List<AdminConsoleColumn> columns;
  final List<AdminConsoleTableRow> rows;
  final Widget? empty;

  static bool get isConsoleLayout => kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return empty ??
          const EmptyState(
            title: 'No results',
            message: 'Nothing matches these filters.',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++)
                  _slot(
                    i,
                    Text(
                      columns[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var c = 0; c < rows[i].cells.length && c < columns.length; c++)
                        _slot(c, rows[i].cells[c]),
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

  Widget _slot(int index, Widget child) {
    final column = columns[index];
    final isLast = index == columns.length - 1;
    final padded = Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : 16),
      child: child,
    );
    if (column.width != null) {
      return SizedBox(width: column.width, child: padded);
    }
    return Expanded(flex: column.flex, child: padded);
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

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

/// GitHub-style activity heatmap showing the last 12 weeks of dog
/// identification activity. Each cell represents one day, with color
/// intensity mapped to the number of dogs identified.
class CollectionHeatmap extends StatefulWidget {
  /// Map of date keys (YYYY-MM-DD) to identification counts.
  final Map<String, int> activityData;

  const CollectionHeatmap({
    super.key,
    required this.activityData,
  });

  @override
  State<CollectionHeatmap> createState() => _CollectionHeatmapState();
}

class _CollectionHeatmapState extends State<CollectionHeatmap> {
  String? _selectedDateKey;
  int? _selectedCount;

  static const int _weeks = 12;
  static const int _daysPerWeek = 7;
  static const double _cellSize = 14.0;
  static const double _cellGap = 3.0;
  static const double _leftLabelWidth = 20.0;
  static const double _topLabelHeight = 18.0;

  static const _dayLabels = ['', 'M', '', 'W', '', 'F', ''];

  Color _colorForCount(int count) {
    if (count == 0) return bgCard;
    if (count == 1) return const Color(0xFF1B5E20);
    if (count == 2) return const Color(0xFF2E7D32);
    if (count <= 4) return const Color(0xFFD4874E);
    return Colors.amber; // 5+
  }

  /// Build ordered list of 84 days ending today, organized into columns (weeks).
  List<List<_DayCell>> _buildGrid() {
    final today = DateTime.now();
    const totalDays = _weeks * _daysPerWeek;
    // Start from `totalDays - 1` days ago so today is the last cell.
    final startDate = today.subtract(Duration(days: totalDays - 1));

    // Align start to Monday (weekday 1 in Dart).
    final adjustedStart = startDate.subtract(
      Duration(days: (startDate.weekday - 1) % 7),
    );

    final weeks = <List<_DayCell>>[];
    var current = adjustedStart;

    for (int w = 0; w < _weeks; w++) {
      final week = <_DayCell>[];
      for (int d = 0; d < _daysPerWeek; d++) {
        final key =
            '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        final count = widget.activityData[key] ?? 0;
        final isFuture = current.isAfter(today);
        week.add(_DayCell(
          dateKey: key,
          date: current,
          count: count,
          isFuture: isFuture,
        ));
        current = current.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    return weeks;
  }

  /// Month label positions — show a label at the first week that starts a new month.
  List<(int weekIndex, String label)> _monthLabels(List<List<_DayCell>> grid) {
    final labels = <(int, String)>[];
    int? lastMonth;
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    for (int w = 0; w < grid.length; w++) {
      // Use the Monday (first day) of each week column.
      final month = grid[w].first.date.month;
      if (month != lastMonth) {
        labels.add((w, monthNames[month - 1]));
        lastMonth = month;
      }
    }

    return labels;
  }

  String _formatTooltipDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final grid = _buildGrid();
    final monthLabels = _monthLabels(grid);

    const totalWidth =
        _leftLabelWidth + (_weeks * (_cellSize + _cellGap)) - _cellGap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tooltip
        if (_selectedDateKey != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              '$_selectedCount dog${_selectedCount == 1 ? '' : 's'} on '
              '${_formatTooltipDate(DateTime.parse(_selectedDateKey!))}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ).animate().fadeIn(duration: 150.ms),

        SizedBox(
          width: totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month labels row
              SizedBox(
                height: _topLabelHeight,
                child: Stack(
                  children: [
                    for (final (weekIdx, label) in monthLabels)
                      Positioned(
                        left:
                            _leftLabelWidth + weekIdx * (_cellSize + _cellGap),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Grid
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day labels column
                  SizedBox(
                    width: _leftLabelWidth,
                    child: Column(
                      children: List.generate(_daysPerWeek, (d) {
                        return SizedBox(
                          height: _cellSize + _cellGap,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _dayLabels[d],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Heatmap cells
                  ...List.generate(grid.length, (w) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: w < grid.length - 1 ? _cellGap : 0,
                      ),
                      child: Column(
                        children: List.generate(_daysPerWeek, (d) {
                          final cell = grid[w][d];
                          final isSelected = _selectedDateKey == cell.dateKey;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: _cellGap),
                            child: GestureDetector(
                              onTap: cell.isFuture
                                  ? null
                                  : () {
                                      setState(() {
                                        if (_selectedDateKey == cell.dateKey) {
                                          _selectedDateKey = null;
                                          _selectedCount = null;
                                        } else {
                                          _selectedDateKey = cell.dateKey;
                                          _selectedCount = cell.count;
                                        }
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _cellSize,
                                height: _cellSize,
                                decoration: BoxDecoration(
                                  color: cell.isFuture
                                      ? Colors.transparent
                                      : _colorForCount(cell.count),
                                  borderRadius: BorderRadius.circular(3),
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.white70,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideX(begin: -0.05, end: 0, duration: 400.ms),

        // Legend
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Less',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
            const SizedBox(width: 4),
            for (final count in [0, 1, 2, 4, 5])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: _colorForCount(count),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 4),
            const Text(
              'More',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayCell {
  final String dateKey;
  final DateTime date;
  final int count;
  final bool isFuture;

  const _DayCell({
    required this.dateKey,
    required this.date,
    required this.count,
    required this.isFuture,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carcare_service/app/theme/app_theme.dart';

// ─── Localization constants ────────────────────────────────────────────────────

const _kWeekdays = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];
const _kMonths = [
  '1-р сар',
  '2-р сар',
  '3-р сар',
  '4-р сар',
  '5-р сар',
  '6-р сар',
  '7-р сар',
  '8-р сар',
  '9-р сар',
  '10-р сар',
  '11-р сар',
  '12-р сар',
];

// ─── Public API ───────────────────────────────────────────────────────────────

/// Огноо сонгогч (цаггүй). Returns null if dismissed.
Future<DateTime?> showMnDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MnPickerSheet(
      initial: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      withTime: false,
    ),
  );
}

/// Огноо + цаг сонгогч (30 мин интервал). Returns null if dismissed.
Future<DateTime?> showMnDateTimePicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
  int startHour = 8,
  int endHour = 20,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MnPickerSheet(
      initial: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      withTime: true,
      startHour: startHour,
      endHour: endHour,
    ),
  );
}

// ─── Sheet ─────────────────────────────────────────────────────────────────────

class _MnPickerSheet extends StatefulWidget {
  final DateTime initial;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool withTime;
  final int startHour;
  final int endHour;

  const _MnPickerSheet({
    required this.initial,
    this.firstDate,
    this.lastDate,
    required this.withTime,
    this.startHour = 8,
    this.endHour = 20,
  });

  @override
  State<_MnPickerSheet> createState() => _MnPickerSheetState();
}

class _MnPickerSheetState extends State<_MnPickerSheet> {
  late int _year;
  late int _month;
  late DateTime _selDate;
  late int _selHour;
  late int _selMin;
  late final ScrollController _timeScroll;
  late final TextEditingController _inputCtrl;
  late final FocusNode _inputFocus;
  bool _inputError = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _year = d.year;
    _month = d.month;
    _selDate = DateTime(d.year, d.month, d.day);
    _timeScroll = ScrollController();
    _inputFocus = FocusNode();

    if (widget.withTime) {
      _selMin = d.minute >= 30 ? 30 : 0;
      _selHour = d.hour.clamp(widget.startHour, widget.endHour);
    } else {
      _selHour = widget.startHour;
      _selMin = 0;
    }

    _inputCtrl = TextEditingController(text: _formatInput());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.withTime) _scrollToSelected();
    });
  }

  @override
  void dispose() {
    _timeScroll.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ─── Text ↔ state sync ─────────────────────────────────────────────────────

  String _formatInput() {
    final d = _selDate;
    final date =
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    if (!widget.withTime) return date;
    return '$date  ${_selHour.toString().padLeft(2, '0')}:${_selMin.toString().padLeft(2, '0')}';
  }

  /// Called after calendar/time picks — only syncs text when field not focused.
  void _syncTextField() {
    if (_inputFocus.hasFocus) return;
    final text = _formatInput();
    if (_inputCtrl.text != text) {
      _inputCtrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (_inputError) setState(() => _inputError = false);
  }

  /// Parses `ЖЖЖЖ/СС/ӨӨ` or `ЖЖЖЖ/СС/ӨӨ  ЦЦ:МС` typed by the user.
  void _onDateTyped(String raw) {
    final v = raw.trim().replaceAll('.', '/').replaceAll('-', '/');

    // Split date and time
    final spaceIdx = v.indexOf(RegExp(r'\s'));
    final datePart = spaceIdx == -1 ? v : v.substring(0, spaceIdx).trim();
    final timePart = spaceIdx == -1 ? null : v.substring(spaceIdx).trim();

    // Parse date
    final parts = datePart.split('/');
    if (parts.length != 3) {
      if (v.length > 6) setState(() => _inputError = true);
      return;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null ||
        month == null ||
        day == null ||
        year < 1900 ||
        year > 2100 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      setState(() => _inputError = true);
      return;
    }
    // Validate the date is real (e.g. Feb 30 is invalid)
    final candidate = DateTime(year, month, day);
    if (candidate.month != month || candidate.day != day) {
      setState(() => _inputError = true);
      return;
    }
    // Check firstDate / lastDate bounds
    if (widget.firstDate != null) {
      final f = widget.firstDate!;
      if (candidate.isBefore(DateTime(f.year, f.month, f.day))) {
        setState(() => _inputError = true);
        return;
      }
    }
    if (widget.lastDate != null) {
      final l = widget.lastDate!;
      if (candidate.isAfter(DateTime(l.year, l.month, l.day))) {
        setState(() => _inputError = true);
        return;
      }
    }

    // Parse time (optional, only when withTime)
    int? newHour;
    int? newMin;
    if (widget.withTime && timePart != null && timePart.contains(':')) {
      final tp = timePart.split(':');
      if (tp.length == 2) {
        newHour = int.tryParse(tp[0]);
        newMin = int.tryParse(tp[1]);
        if (newHour == null ||
            newMin == null ||
            newHour < 0 ||
            newHour > 23 ||
            newMin < 0 ||
            newMin > 59) {
          setState(() => _inputError = true);
          return;
        }
        // Snap to nearest 30-min slot
        newMin = newMin >= 30 ? 30 : 0;
        newHour = newHour.clamp(widget.startHour, widget.endHour);
      }
    }

    setState(() {
      _selDate = candidate;
      _year = year;
      _month = month;
      if (newHour != null && newMin != null) {
        _selHour = newHour;
        _selMin = newMin;
      }
      _inputError = false;
    });

    // Scroll time list to the new slot
    if (widget.withTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  // ─── Calendar helpers ──────────────────────────────────────────────────────

  List<DateTime?> _buildCells() {
    final first = DateTime(_year, _month, 1);
    final offset = (first.weekday - 1) % 7;
    final days = DateTime(_year, _month + 1, 0).day;
    final cells = <DateTime?>[
      ...List.filled(offset, null),
      for (int d = 1; d <= days; d++) DateTime(_year, _month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  bool _isDisabled(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    if (widget.firstDate != null) {
      final f = widget.firstDate!;
      if (date.isBefore(DateTime(f.year, f.month, f.day))) return true;
    }
    if (widget.lastDate != null) {
      final l = widget.lastDate!;
      if (date.isAfter(DateTime(l.year, l.month, l.day))) return true;
    }
    return false;
  }

  void _selectDay(DateTime day) {
    setState(() => _selDate = DateTime(day.year, day.month, day.day));
    _syncTextField();
  }

  void _prevMonth() => setState(() {
    if (_month == 1) {
      _year--;
      _month = 12;
    } else {
      _month--;
    }
  });

  void _nextMonth() => setState(() {
    if (_month == 12) {
      _year++;
      _month = 1;
    } else {
      _month++;
    }
  });

  // ─── Time helpers ──────────────────────────────────────────────────────────

  List<(int, int)> _buildSlots() {
    final slots = <(int, int)>[];
    for (int h = widget.startHour; h <= widget.endHour; h++) {
      slots.add((h, 0));
      if (h < widget.endHour) slots.add((h, 30));
    }
    return slots;
  }

  void _selectSlot(int h, int m) {
    setState(() {
      _selHour = h;
      _selMin = m;
    });
    _syncTextField();
  }

  void _scrollToSelected() {
    if (!_timeScroll.hasClients) return;
    final idx = (_selHour - widget.startHour) * 2 + (_selMin ~/ 30);
    const chipW = 72.0;
    final vp = _timeScroll.position.viewportDimension;
    final target = (idx * chipW - vp / 2 + chipW / 2).clamp(
      0.0,
      _timeScroll.position.maxScrollExtent,
    );
    _timeScroll.jumpTo(target);
  }

  // ─── Confirm ───────────────────────────────────────────────────────────────

  DateTime get _result => widget.withTime
      ? DateTime(_selDate.year, _selDate.month, _selDate.day, _selHour, _selMin)
      : _selDate;

  String get _confirmLabel {
    final d = _selDate;
    final ds =
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    if (!widget.withTime) return ds;
    return '$ds  ${_selHour.toString().padLeft(2, '0')}:${_selMin.toString().padLeft(2, '0')}';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final cells = _buildCells();
    final now = DateTime.now();
    final slots = _buildSlots();

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Writable date/time input ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _inputError
                    ? context.colors.danger.withOpacity(0.04)
                    : context.colors.background,
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                border: Border.all(
                  color: _inputError
                      ? context.colors.danger
                      : _inputFocus.hasFocus
                      ? context.colors.accent
                      : context.colors.divider,
                  width: _inputFocus.hasFocus || _inputError ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      _inputError
                          ? Icons.error_outline_rounded
                          : Icons.edit_calendar_rounded,
                      size: 18,
                      color: _inputError
                          ? context.colors.danger
                          : context.colors.accent,
                    ),
                  ),
                  Expanded(
                    child: Focus(
                      onFocusChange: (gained) {
                        setState(() {}); // repaint border
                        if (!gained) {
                          // On blur: if field is empty or error, reset to current selection
                          if (_inputCtrl.text.trim().isEmpty || _inputError) {
                            _inputCtrl.value = TextEditingValue(
                              text: _formatInput(),
                              selection: TextSelection.collapsed(
                                offset: _formatInput().length,
                              ),
                            );
                            setState(() => _inputError = false);
                          }
                        }
                      },
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _inputFocus,
                        onChanged: _onDateTyped,
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d/.\-: ]'),
                          ),
                        ],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _inputError
                              ? context.colors.danger
                              : context.colors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.withTime
                              ? 'ЖЖЖЖ/СС/ӨӨ  ЦЦ:ММ'
                              : 'ЖЖЖЖ/СС/ӨӨ',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: context.colors.textHint,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  if (_inputError)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        'Буруу',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.colors.danger,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        widget.withTime ? 'ЖЖЖЖ/СС/ӨӨ  ЦЦ:ММ' : 'ЖЖЖЖ/СС/ӨӨ',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textHint,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Calendar section (dark) ──────────────────────────────────────
          Container(
            color: context.colors.brandSurface,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            child: Column(
              children: [
                // Month navigation
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _prevMonth,
                    ),
                    Expanded(
                      child: Text(
                        '$_year оны ${_kMonths[_month - 1]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),

                // Weekday headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: _kWeekdays
                        .map(
                          (l) => Expanded(
                            child: Text(
                              l,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 6),

                // Day grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 42,
                  ),
                  itemCount: cells.length,
                  itemBuilder: (_, i) {
                    final day = cells[i];
                    if (day == null) return const SizedBox();

                    final isSel =
                        day.year == _selDate.year &&
                        day.month == _selDate.month &&
                        day.day == _selDate.day;
                    final isToday =
                        day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;
                    final isCurrent = day.month == _month;
                    final disabled = _isDisabled(day);

                    return GestureDetector(
                      onTap: disabled ? null : () => _selectDay(day),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel
                                ? context.colors.accent
                                : Colors.transparent,
                            border: isToday && !isSel
                                ? Border.all(color: Colors.white38, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: disabled
                                    ? Colors.white24
                                    : isSel
                                    ? CarCareTheme.of(context).onAccent
                                    : isCurrent
                                    ? Colors.white.withOpacity(0.88)
                                    : Colors.white30,
                                fontSize: 13,
                                fontWeight: isSel || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Time slots section ───────────────────────────────────────────
          if (widget.withTime) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Цаг сонгох',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${_selHour.toString().padLeft(2, '0')}:${_selMin.toString().padLeft(2, '0')}',
                      key: ValueKey('$_selHour:$_selMin'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                controller: _timeScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: slots.length,
                separatorBuilder: (_, i) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final (h, m) = slots[i];
                  final sel = h == _selHour && m == _selMin;
                  return GestureDetector(
                    onTap: () => _selectSlot(h, m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 66,
                      decoration: BoxDecoration(
                        color: sel
                            ? context.colors.accent
                            : context.colors.background,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                        border: Border.all(
                          color: sel
                              ? context.colors.accent
                              : context.colors.divider,
                          width: sel ? 1.5 : 1,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: context.colors.accent.withOpacity(
                                    0.25,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel
                                ? CarCareTheme.of(context).onAccent
                                : context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
          ],

          // ── Action buttons ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.colors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusMD,
                          ),
                        ),
                      ),
                      child: Text('Болих'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _inputError
                          ? null
                          : () => Navigator.pop(context, _result),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.accent,
                        disabledBackgroundColor: context.colors.divider,
                        foregroundColor: CarCareTheme.of(context).onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusMD,
                          ),
                        ),
                      ),
                      child: Text(
                        _inputError ? 'Буруу огноо' : _confirmLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import './widgets/calendar_background_widget.dart';
import './widgets/calendar_grid_widget.dart';
import './widgets/calendar_header_widget.dart';
import './widgets/calendar_legend_widget.dart';
import './widgets/day_detail_sheet_widget.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  // TODO: Replace with Riverpod/Bloc for production
  final _dataService = DataService(LocalStorageService());
  bool _initialized = false;

  late int _displayYear;
  late int _displayMonth;
  List<WorkDayModel> _monthWorkDays = [];
  List<int> _workSchedule = [1, 2, 3, 4, 5];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayYear = now.year;
    _displayMonth = now.month;
    _init();
  }

  Future<void> _init() async {
    await _dataService.init();
    _loadMonth();
  }

  void _loadMonth() {
    if (!mounted) return;
    setState(() {
      _initialized = true;
      _monthWorkDays = _dataService.getWorkDaysForMonth(
        _displayYear,
        _displayMonth,
      );
      _workSchedule = _dataService.workSchedule;
    });
  }

  void _prevMonth() {
    setState(() {
      if (_displayMonth == 1) {
        _displayMonth = 12;
        _displayYear--;
      } else {
        _displayMonth--;
      }
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      if (_displayMonth == 12) {
        _displayMonth = 1;
        _displayYear++;
      } else {
        _displayMonth++;
      }
    });
    _loadMonth();
  }

  WorkDayModel? _getWorkDayForDate(DateTime date) {
    try {
      return _monthWorkDays.firstWhere(
        (d) =>
            d.date.year == date.year &&
            d.date.month == date.month &&
            d.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isScheduledDay(DateTime date) => _workSchedule.contains(date.weekday);

  void _onDayTap(DateTime date) {
    final workDay = _getWorkDayForDate(date);
    final objects = _dataService.activeObjects;
    final wage = _dataService.getDailyWageForDate(date);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DayDetailSheetWidget(
        date: date,
        workDay: workDay,
        objects: objects,
        dailyWage: wage,
        onMarkWorked: (objectId, objectName, note) async {
          await _dataService.markWorked(
            date: date,
            objectId: objectId,
            objectName: objectName,
            note: note,
          );
          Navigator.of(context).pop();
          _loadMonth();
        },
        onMarkNotWorked: () async {
          await _dataService.markNotWorked(date);
          Navigator.of(context).pop();
          _loadMonth();
        },
        onUpdateNote: (note) async {
          if (workDay != null) {
            await _dataService.updateWorkDayNote(workDay.id, note);
            Navigator.of(context).pop();
            _loadMonth();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const CalendarBackgroundWidget(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                CalendarHeaderWidget(
                  year: _displayYear,
                  month: _displayMonth,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                ),
                const CalendarLegendWidget(),
                Expanded(
                  child: !_initialized
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 120),
                          child: CalendarGridWidget(
                            year: _displayYear,
                            month: _displayMonth,
                            workDays: _monthWorkDays,
                            workSchedule: _workSchedule,
                            onDayTap: _onDayTap,
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

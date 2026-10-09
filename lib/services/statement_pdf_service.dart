import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/expense.dart';
import '../data/models/income.dart';

class StatementPdfService {
  // ---------------------------------------------------------------------------
  // DESIGN TOKENS
  // ---------------------------------------------------------------------------

  static final PdfColor _green = PdfColor.fromInt(0xFF087F67);
  static final PdfColor _greenDark = PdfColor.fromInt(0xFF075D4E);
  static final PdfColor _greenSoft = PdfColor.fromInt(0xFFE4F4ED);
  static final PdfColor _mint = PdfColor.fromInt(0xFFF0F9F5);
  static final PdfColor _mintStrong = PdfColor.fromInt(0xFFE7F4EE);
  static final PdfColor _line = PdfColor.fromInt(0xFFD9EAE2);
  static final PdfColor _ink = PdfColor.fromInt(0xFF10212B);
  static final PdfColor _muted = PdfColor.fromInt(0xFF66757D);
  static final PdfColor _red = PdfColor.fromInt(0xFFE53935);
  static final PdfColor _redSoft = PdfColor.fromInt(0xFFFFE9E9);
  static final PdfColor _blue = PdfColor.fromInt(0xFF2F80ED);
  static final PdfColor _blueSoft = PdfColor.fromInt(0xFFE7F0FF);
  static final PdfColor _orange = PdfColor.fromInt(0xFFFF9F43);
  static final PdfColor _orangeSoft = PdfColor.fromInt(0xFFFFF0DC);
  static final PdfColor _pink = PdfColor.fromInt(0xFFEC4899);
  static final PdfColor _pinkSoft = PdfColor.fromInt(0xFFFFE8F2);
  static final PdfColor _purple = PdfColor.fromInt(0xFF8B5CF6);
  static final PdfColor _purpleSoft = PdfColor.fromInt(0xFFF0E9FF);
  static final PdfColor _health = PdfColor.fromInt(0xFFEF4444);
  static final PdfColor _healthSoft = PdfColor.fromInt(0xFFFFE8E8);
  static final PdfColor _grey = PdfColor.fromInt(0xFF9CA3AF);
  static final PdfColor _greySoft = PdfColor.fromInt(0xFFE9EEF2);

  static const double _pageLeft = 22;
  static const double _pageRight = 22;
  static const double _pageTop = 20;
  static const double _pageBottom = 16;

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// IMPORTANT:
  ///
  /// For the most accurate:
  /// - opening balance
  /// - previous-period comparison
  ///
  /// pass [allExpenses] and [allIncomes] containing the user's full local
  /// history.
  ///
  /// If you only pass [expenses] and [incomes], the PDF still works, but it
  /// cannot know transactions that happened before the selected period.
  static Future<Uint8List> build({
    required DateTimeRange period,
    required List<Expense> expenses,
    required List<Income> incomes,
    required String currency,
    List<Expense>? allExpenses,
    List<Income>? allIncomes,
    double? openingBalance,
    DateTime? generatedAt,
  }) async {
    final document = pw.Document();
    final theme = await _loadTheme();

    final historyExpenses = allExpenses ?? expenses;
    final historyIncomes = allIncomes ?? incomes;

    final periodExpenses = historyExpenses
        .where((item) => _isInsidePeriod(item.date, period))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final periodIncomes = historyIncomes
        .where((item) => _isInsidePeriod(item.date, period))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalIncome = periodIncomes.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final totalExpenses = periodExpenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final opening = openingBalance ??
        _openingBalanceFromHistory(
          period,
          historyExpenses,
          historyIncomes,
        );

    final closing = opening + totalIncome - totalExpenses;

    // Reference design uses all days in the selected period, not only days
    // where an expense exists.
    final periodDays = _periodDayCount(period);
    final dailyAverage =
        periodDays == 0 ? 0.0 : totalExpenses / periodDays;

    final categories = <String, double>{};
    for (final item in periodExpenses) {
      categories.update(
        item.category,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }

    final previousPeriod = _previousPeriod(period);
    final previousExpenses = historyExpenses
        .where((item) => _isInsidePeriod(item.date, previousPeriod))
        .toList();

    final previousExpenseTotal = previousExpenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final transactionRows = _transactionRows(
      opening,
      periodExpenses,
      periodIncomes,
    );

    final chunks = <List<_PdfRowWithBalance>>[];
    // Normal transaction pages can be dense, but the final page also contains
    // the statement summary and note. Reserve that space up front so its
    // content never pushes the footer outside the A4 page.
    const rowsPerTransactionPage = 22;
    const rowsOnSummaryPage = 15;
    final summaryRows = math.min(
      rowsOnSummaryPage,
      transactionRows.length,
    );
    final rowsBeforeSummary = transactionRows.length - summaryRows;

    for (
      var index = 0;
      index < rowsBeforeSummary;
      index += rowsPerTransactionPage
    ) {
      chunks.add(
        transactionRows
            .skip(index)
            .take(rowsPerTransactionPage)
            .toList(),
      );
    }

    chunks.add(
      transactionRows
          .skip(rowsBeforeSummary)
          .take(summaryRows)
          .toList(),
    );

    if (chunks.isEmpty) {
      chunks.add(const <_PdfRowWithBalance>[]);
    }

    final totalPages = chunks.length + 1;
    final createdAt = generatedAt ?? DateTime.now();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          _pageLeft,
          _pageTop,
          _pageRight,
          _pageBottom,
        ),
        theme: theme,
        build: (_) => _firstPage(
          period: period,
          generatedAt: createdAt,
          opening: opening,
          income: totalIncome,
          expenses: totalExpenses,
          closing: closing,
          average: dailyAverage,
          incomeCount: periodIncomes.length,
          expenseCount: periodExpenses.length,
          categories: categories,
          expenseItems: periodExpenses,
          incomeItems: periodIncomes,
          previousExpenseTotal: previousExpenseTotal,
          currency: currency,
          totalPages: totalPages,
        ),
      ),
    );

    var visibleRowStart = 1;

    for (var index = 0; index < chunks.length; index++) {
      final chunk = chunks[index];
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(
            _pageLeft,
            _pageTop,
            _pageRight,
            _pageBottom,
          ),
          theme: theme,
          build: (_) => _transactionPage(
            period: period,
            generatedAt: createdAt,
            opening: opening,
            income: totalIncome,
            expenses: totalExpenses,
            closing: closing,
            displayRows: chunk,
            currency: currency,
            page: index + 2,
            totalPages: totalPages,
            showSummary: index == chunks.length - 1,
            firstVisibleRow: visibleRowStart,
            totalRowCount: transactionRows.length,
          ),
        ),
      );

      visibleRowStart += chunk.length;
    }

    return document.save();
  }

  // ---------------------------------------------------------------------------
  // FONT / THEME
  // ---------------------------------------------------------------------------

  /// Put these files in:
  /// assets/fonts/NotoSansBengali-Regular.ttf
  /// assets/fonts/NotoSansBengali-Bold.ttf
  ///
  /// This keeps Taka symbol + Bangla text fully offline.
  static Future<pw.ThemeData> _loadTheme() async {
    try {
      final regularData = await rootBundle.load(
        'assets/fonts/NotoSansBengali-Regular.ttf',
      );
      final boldData = await rootBundle.load(
        'assets/fonts/NotoSansBengali-Bold.ttf',
      );

      return pw.ThemeData.withFont(
        base: pw.Font.ttf(regularData),
        bold: pw.Font.ttf(boldData),
      );
    } catch (_) {
      // PDF still generates if the asset font is not added yet.
      // However, for exact Bangla/Taka rendering, add the two font assets.
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PAGE 1
  // ---------------------------------------------------------------------------

  static pw.Widget _firstPage({
    required DateTimeRange period,
    required DateTime generatedAt,
    required double opening,
    required double income,
    required double expenses,
    required double closing,
    required double average,
    required int incomeCount,
    required int expenseCount,
    required Map<String, double> categories,
    required List<Expense> expenseItems,
    required List<Income> incomeItems,
    required double previousExpenseTotal,
    required String currency,
    required int totalPages,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(period, generatedAt),
        pw.SizedBox(height: 10),

        _periodHeading(period),
        pw.SizedBox(height: 9),

        _financialSummary(
          income: income,
          expenses: expenses,
          closing: closing,
          average: average,
          incomeCount: incomeCount,
          expenseCount: expenseCount,
          currency: currency,
        ),

        pw.SizedBox(height: 10),

        _barChartCard(
          period: period,
          expenses: expenseItems,
          incomes: incomeItems,
        ),

        pw.SizedBox(height: 10),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _categoryCard(
                categories: categories,
                total: expenses,
                currency: currency,
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(
              child: _insightsCard(
                period: period,
                categories: categories,
                expenses: expenseItems,
                currentExpenseTotal: expenses,
                previousExpenseTotal: previousExpenseTotal,
                currency: currency,
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        _trendChartCard(
          period: period,
          expenses: expenseItems,
          incomes: incomeItems,
        ),

        pw.Spacer(),
        _footer(1, totalPages),
      ],
    );
  }

  static pw.Widget _financialSummary({
    required double income,
    required double expenses,
    required double closing,
    required double average,
    required int incomeCount,
    required int expenseCount,
    required String currency,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionStrip(
          title: 'Financial Summary',
          icon: 'chart',
        ),
        pw.SizedBox(height: 7),
        pw.Row(
          children: [
            pw.Expanded(
              child: _summaryBox(
                label: 'Total Income',
                value: _money(income, currency),
                sub: '$incomeCount transactions',
                color: _green,
                icon: 'income',
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _summaryBox(
                label: 'Total Expenses',
                value: _money(expenses, currency),
                sub: '$expenseCount transactions',
                color: _red,
                icon: 'expense',
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _summaryBox(
                label: 'Net Balance',
                value: _money(closing, currency),
                sub: 'Income - Expenses',
                color: _greenDark,
                icon: 'wallet',
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _summaryBox(
                label: 'Daily Average',
                value: _money(average, currency),
                sub: '(Expense)',
                color: _blue,
                icon: 'chart',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summaryBox({
    required String label,
    required String value,
    required String sub,
    required PdfColor color,
    required String icon,
  }) {
    return pw.Container(
      height: 81,
      padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: _line,
          width: .55,
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _iconBadge(
            icon,
            _iconHex(color),
            background: _paleFor(color),
            size: 23,
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 7.2,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 12.7,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            sub,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 6.2,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _barChartCard({
    required DateTimeRange period,
    required List<Expense> expenses,
    required List<Income> incomes,
  }) {
    return _sectionCard(
      title: 'Income vs Expense',
      icon: 'chart',
      trailing: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          _legend(_green, 'Income'),
          pw.SizedBox(width: 11),
          _legend(PdfColor.fromInt(0xFFFF6B6B), 'Expense'),
        ],
      ),
      child: _barChart(
        period,
        expenses,
        incomes,
      ),
      contentHeight: 132,
    );
  }

  static pw.Widget _trendChartCard({
    required DateTimeRange period,
    required List<Expense> expenses,
    required List<Income> incomes,
  }) {
    return _sectionCard(
      title: 'Income & Expense Trend',
      icon: 'trend',
      trailing: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          _legend(_green, 'Income'),
          pw.SizedBox(width: 11),
          _legend(PdfColor.fromInt(0xFFFF6B6B), 'Expense'),
        ],
      ),
      child: _lineChart(
        period,
        expenses,
        incomes,
      ),
      contentHeight: 95,
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 2+
  // ---------------------------------------------------------------------------

  static pw.Widget _transactionPage({
    required DateTimeRange period,
    required DateTime generatedAt,
    required double opening,
    required double income,
    required double expenses,
    required double closing,
    required List<_PdfRowWithBalance> displayRows,
    required String currency,
    required int page,
    required int totalPages,
    required bool showSummary,
    required int firstVisibleRow,
    required int totalRowCount,
  }) {
    final lastVisibleRow = displayRows.isEmpty
        ? 0
        : math.min(
            firstVisibleRow + displayRows.length - 1,
            totalRowCount,
          );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(period, generatedAt),
        pw.SizedBox(height: 10),

        _periodHeading(period),
        pw.SizedBox(height: 9),

        _transactionCard(
          rows: displayRows,
          currency: currency,
          firstVisibleRow: firstVisibleRow,
          lastVisibleRow: lastVisibleRow,
          totalRowCount: totalRowCount,
        ),

        if (showSummary) ...[
          pw.SizedBox(height: 11),
          _statementSummary(
            period: period,
            opening: opening,
            income: income,
            expenses: expenses,
            closing: closing,
            currency: currency,
          ),
          pw.SizedBox(height: 10),
          _noteBox(),
        ] else ...[
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              color: _mint,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Transaction details continue on the next page.',
              style: pw.TextStyle(
                fontSize: 7,
                color: _muted,
              ),
            ),
          ),
        ],

        pw.Spacer(),
        _footer(page, totalPages),
      ],
    );
  }

  static pw.Widget _transactionCard({
    required List<_PdfRowWithBalance> rows,
    required String currency,
    required int firstVisibleRow,
    required int lastVisibleRow,
    required int totalRowCount,
  }) {
    final showingText = totalRowCount == 0
        ? 'No transactions'
        : 'Showing $firstVisibleRow-$lastVisibleRow of $totalRowCount';

    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: _line,
          width: .55,
        ),
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: pw.BoxDecoration(
              color: _mint,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              children: [
                _vectorIcon(
                  'list',
                  '#087F67',
                  14,
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Text(
                    'Transaction Details',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ),
                pw.Text(
                  showingText,
                  style: pw.TextStyle(
                    fontSize: 6.4,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 55,
              ),
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  _iconBadge(
                    'list',
                    '#087F67',
                    background: _greenSoft,
                    size: 30,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'No transactions in this period.',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            )
          else
            _transactionTable(
              rows,
              currency,
            ),
        ],
      ),
    );
  }

  static pw.Widget _statementSummary({
    required DateTimeRange period,
    required double opening,
    required double income,
    required double expenses,
    required double closing,
    required String currency,
  }) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: _line,
          width: .55,
        ),
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        children: [
          _sectionStrip(
            title: 'Statement Summary',
            icon: 'wallet',
            roundedTopOnly: true,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(
              13,
              11,
              13,
              11,
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(
                      right: 15,
                    ),
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        _summaryLine(
                          'Opening Balance\n(${_periodDate(period.start)})',
                          opening,
                          currency,
                          color: _greenDark,
                        ),
                        pw.SizedBox(height: 7),
                        _summaryLine(
                          'Total Income',
                          income,
                          currency,
                          color: _green,
                        ),
                        pw.SizedBox(height: 7),
                        _summaryLine(
                          'Total Expenses',
                          expenses,
                          currency,
                          color: _red,
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Container(
                  width: .7,
                  height: 74,
                  color: _line,
                ),
                pw.SizedBox(width: 15),
                pw.Container(
                  width: 142,
                  padding: const pw.EdgeInsets.fromLTRB(
                    12,
                    11,
                    12,
                    11,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(
                      color: _line,
                      width: .45,
                    ),
                    borderRadius: pw.BorderRadius.circular(9),
                  ),
                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          _iconBadge(
                            'wallet',
                            '#087F67',
                            background: _greenSoft,
                            size: 25,
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Text(
                              'Closing Balance',
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight:
                                    pw.FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '(${_periodDate(period.end)})',
                        style: pw.TextStyle(
                          fontSize: 6.3,
                          color: _muted,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _money(closing, currency),
                        style: pw.TextStyle(
                          fontSize: 16.5,
                          fontWeight:
                              pw.FontWeight.bold,
                          color: _greenDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _noteBox() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFFF1F1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _vectorIcon(
            'info',
            '#E53935',
            15,
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Note',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _red,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'This statement shows all recorded income and expenses for the selected period. '
                  'It was generated locally from your device using Spend Smart. No internet was used.',
                  style: pw.TextStyle(
                    fontSize: 6.8,
                    height: 1.35,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER / PERIOD / FOOTER
  // ---------------------------------------------------------------------------

  static pw.Widget _header(
    DateTimeRange period,
    DateTime generatedAt,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 42,
          height: 42,
          decoration: pw.BoxDecoration(
            color: _green,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          alignment: pw.Alignment.center,
          child: _vectorIcon(
            'wallet',
            '#FFFFFF',
            27,
          ),
        ),
        pw.SizedBox(width: 9),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Spend Smart',
                style: pw.TextStyle(
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'Personal Income & Expense Tracker',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 118,
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          decoration: pw.BoxDecoration(
            color: _mint,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Income & Expense',
                style: pw.TextStyle(
                  fontSize: 7.2,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.Text(
                'Statement',
                style: pw.TextStyle(
                  fontSize: 7.2,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'GENERATED ON',
                style: pw.TextStyle(
                  fontSize: 5.5,
                  color: _muted,
                ),
              ),
              pw.Text(
                _generatedDate(generatedAt),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 5.4,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _periodHeading(
    DateTimeRange period,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _periodTitle(period),
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '${_periodDate(period.start)} - ${_periodDate(period.end)}',
          style: pw.TextStyle(
            fontSize: 9.2,
            color: _muted,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          height: .75,
          color: _green,
        ),
      ],
    );
  }

  static pw.Widget _footer(
    int page,
    int totalPages,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          height: .7,
          color: _green,
        ),
        pw.SizedBox(height: 7),
        pw.Row(
          children: [
            pw.Container(
              width: 28,
              height: 28,
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                color: _green,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              alignment: pw.Alignment.center,
              child: _vectorIcon(
                'wallet',
                '#FFFFFF',
                18,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Spend Smart',
                    style: pw.TextStyle(
                      fontSize: 8.6,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.Text(
                    '100% Offline • Your data stays on your device',
                    style: pw.TextStyle(
                      fontSize: 6.2,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              'Page $page of $totalPages',
              style: pw.TextStyle(
                fontSize: 7.5,
                color: _muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REUSABLE CARDS
  // ---------------------------------------------------------------------------

  static pw.Widget _sectionStrip({
    required String title,
    required String icon,
    bool roundedTopOnly = false,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6.5,
      ),
      decoration: pw.BoxDecoration(
        color: _mint,
        borderRadius: roundedTopOnly
            ? const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              )
            : pw.BorderRadius.circular(7),
      ),
      child: pw.Row(
        children: [
          _vectorIcon(
            icon,
            '#087F67',
            14,
          ),
          pw.SizedBox(width: 7),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10.4,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionCard({
    required String title,
    required String icon,
    required pw.Widget child,
    pw.Widget? trailing,
    required double contentHeight,
  }) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: _line,
          width: .55,
        ),
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6.5,
            ),
            decoration: pw.BoxDecoration(
              color: _mint,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              children: [
                _vectorIcon(
                  icon,
                  '#087F67',
                  14,
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 10.4,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          pw.SizedBox(
            height: contentHeight,
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(
                9,
                7,
                9,
                7,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHARTS
  // ---------------------------------------------------------------------------

  static pw.Widget _barChart(
    DateTimeRange period,
    List<Expense> expenses,
    List<Income> incomes,
  ) {
    final totalDays = _periodDayCount(period);
    final bucketCount = _barBucketCount(totalDays);

    final expenseBuckets =
        List<double>.filled(bucketCount, 0);
    final incomeBuckets =
        List<double>.filled(bucketCount, 0);

    for (final item in expenses) {
      final index = _bucketIndex(
        item.date,
        period,
        bucketCount,
      );
      expenseBuckets[index] += item.amount;
    }

    for (final item in incomes) {
      final index = _bucketIndex(
        item.date,
        period,
        bucketCount,
      );
      incomeBuckets[index] += item.amount;
    }

    final maxValue = [
      ...incomeBuckets,
      ...expenseBuckets,
    ].fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    final chartMax = _niceChartMax(maxValue);

    final yValues = List.generate(
      5,
      (index) => chartMax * index / 4,
    );

    final xLabels = <String>[''];

    for (var index = 0; index < bucketCount; index++) {
      final dates = _bucketDateRange(
        period,
        bucketCount,
        index,
      );

      xLabels.add(
        'W${index + 1}\n'
        '(${DateFormat('d').format(dates.$1)}-'
        '${DateFormat('d MMM').format(dates.$2)})',
      );
    }

    final barWidth = bucketCount <= 5
        ? 13.0
        : bucketCount <= 8
            ? 9.0
            : 6.0;

    final barOffset = bucketCount <= 5
        ? 7.5
        : bucketCount <= 8
            ? 5.0
            : 3.5;

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          xLabels,
          marginStart: 7,
          marginEnd: 7,
          textStyle: pw.TextStyle(
            fontSize: 5.7,
            color: _muted,
          ),
          divisions: false,
          color: _line,
          width: .4,
        ),
        yAxis: pw.FixedAxis<double>(
          yValues,
          format: _compactChartNumber,
          textStyle: pw.TextStyle(
            fontSize: 6,
            color: _muted,
          ),
          divisions: true,
          divisionsColor: _line,
          divisionsWidth: .4,
          color: _line,
          width: .4,
        ),
      ),
      datasets: [
        pw.BarDataSet<pw.PointChartValue>(
          data: [
            for (
              var index = 0;
              index < incomeBuckets.length;
              index++
            )
              pw.PointChartValue(
                (index + 1).toDouble(),
                incomeBuckets[index],
              ),
          ],
          color: _green,
          width: barWidth,
          offset: -barOffset,
          drawBorder: false,
        ),
        pw.BarDataSet<pw.PointChartValue>(
          data: [
            for (
              var index = 0;
              index < expenseBuckets.length;
              index++
            )
              pw.PointChartValue(
                (index + 1).toDouble(),
                expenseBuckets[index],
              ),
          ],
          color: PdfColor.fromInt(0xFFFF6B6B),
          width: barWidth,
          offset: barOffset,
          drawBorder: false,
        ),
      ],
    );
  }

  static pw.Widget _lineChart(
    DateTimeRange period,
    List<Expense> expenses,
    List<Income> incomes,
  ) {
    final totalDays = _periodDayCount(period);
    final bucketCount = _lineBucketCount(totalDays);

    final expenseBuckets =
        List<double>.filled(bucketCount, 0);
    final incomeBuckets =
        List<double>.filled(bucketCount, 0);

    for (final item in expenses) {
      final index = _bucketIndex(
        item.date,
        period,
        bucketCount,
      );
      expenseBuckets[index] += item.amount;
    }

    for (final item in incomes) {
      final index = _bucketIndex(
        item.date,
        period,
        bucketCount,
      );
      incomeBuckets[index] += item.amount;
    }

    final maxValue = [
      ...incomeBuckets,
      ...expenseBuckets,
    ].fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    final chartMax = _niceChartMax(maxValue);

    final xLabels = List.generate(
      bucketCount,
      (index) {
        final day = period.start.add(
          Duration(
            days: totalDays <= 1
                ? 0
                : ((totalDays - 1) * index) ~/
                    math.max(bucketCount - 1, 1),
          ),
        );

        return DateFormat('d MMM').format(day);
      },
    );

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          xLabels,
          textStyle: pw.TextStyle(
            fontSize: 5.4,
            color: _muted,
          ),
          divisions: false,
          color: _line,
          width: .4,
        ),
        yAxis: pw.FixedAxis<double>(
          [
            0,
            chartMax / 2,
            chartMax,
          ],
          format: _compactChartNumber,
          textStyle: pw.TextStyle(
            fontSize: 5.4,
            color: _muted,
          ),
          divisions: true,
          divisionsColor: _line,
          divisionsWidth: .4,
          color: _line,
          width: .4,
        ),
      ),
      datasets: [
        pw.LineDataSet<pw.PointChartValue>(
          data: [
            for (
              var index = 0;
              index < incomeBuckets.length;
              index++
            )
              pw.PointChartValue(
                index.toDouble(),
                incomeBuckets[index],
              ),
          ],
          color: _green,
          lineColor: _green,
          lineWidth: 1.6,
          pointSize: 1.7,
          isCurved: true,
          drawSurface: true,
          surfaceColor: _green,
          surfaceOpacity: .10,
        ),
        pw.LineDataSet<pw.PointChartValue>(
          data: [
            for (
              var index = 0;
              index < expenseBuckets.length;
              index++
            )
              pw.PointChartValue(
                index.toDouble(),
                expenseBuckets[index],
              ),
          ],
          color: PdfColor.fromInt(0xFFFF6B6B),
          lineColor: PdfColor.fromInt(0xFFFF6B6B),
          lineWidth: 1.5,
          pointSize: 1.6,
          isCurved: true,
          drawSurface: true,
          surfaceColor: PdfColor.fromInt(0xFFFF6B6B),
          surfaceOpacity: .08,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORY CARD
  // ---------------------------------------------------------------------------

  static pw.Widget _categoryCard({
    required Map<String, double> categories,
    required double total,
    required String currency,
  }) {
    final entries = _categoryEntriesForReport(
      categories,
    );

    return pw.Container(
      height: 191,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: _line,
          width: .55,
        ),
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6.5,
            ),
            decoration: pw.BoxDecoration(
              color: _mint,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              children: [
                _vectorIcon(
                  'wallet',
                  '#087F67',
                  14,
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  'Spending by Category',
                  style: pw.TextStyle(
                    fontSize: 9.7,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(
                9,
                7,
                9,
                7,
              ),
              child: pw.Column(
                children: [
                  pw.SizedBox(
                    width: 83,
                    height: 83,
                    child: pw.Chart(
                      grid: pw.PieGrid(),
                      datasets: [
                        for (final entry in entries)
                          pw.PieDataSet(
                            value: entry.value <= 0
                                ? 1
                                : entry.value,
                            color: _categoryColor(
                              entry.key,
                            ),
                            innerRadius: 22,
                            legendPosition:
                                pw.PieLegendPosition.none,
                            borderColor: PdfColors.white,
                            borderWidth: 1.2,
                          ),
                      ],
                      overlay: pw.Center(
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              _money(total, currency),
                              textAlign:
                                  pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 8.6,
                                fontWeight:
                                    pw.FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                            pw.Text(
                              'Total',
                              style: pw.TextStyle(
                                fontSize: 5.5,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  ...entries.map(
                    (entry) {
                      final percent = total <= 0
                          ? 0
                          : (entry.value / total * 100)
                              .round();

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(
                          bottom: 2.4,
                        ),
                        child: pw.Row(
                          children: [
                            _iconBadge(
                              _categoryIconName(
                                entry.key,
                              ),
                              _iconHex(
                                _categoryColor(
                                  entry.key,
                                ),
                              ),
                              background:
                                  _categoryBackground(
                                entry.key,
                              ),
                              size: 13.5,
                            ),
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(
                                entry.key,
                                maxLines: 1,
                                style: pw.TextStyle(
                                  fontSize: 5.9,
                                  color: _ink,
                                ),
                              ),
                            ),
                            pw.Text(
                              '$percent%',
                              style: pw.TextStyle(
                                fontSize: 5.9,
                                fontWeight:
                                    pw.FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                            pw.SizedBox(width: 7),
                            pw.SizedBox(
                              width: 48,
                              child: pw.Text(
                                _money(
                                  entry.value,
                                  currency,
                                ),
                                textAlign:
                                    pw.TextAlign.right,
                                style: pw.TextStyle(
                                  fontSize: 5.9,
                                  fontWeight:
                                      pw.FontWeight.bold,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<MapEntry<String, double>>
      _categoryEntriesForReport(
    Map<String, double> categories,
  ) {
    final sorted = categories.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    if (sorted.isEmpty) {
      return const [
        MapEntry<String, double>(
          'Others',
          1,
        ),
      ];
    }

    if (sorted.length <= 5) {
      return sorted;
    }

    final topFour = sorted.take(4).toList();

    final others = sorted
        .skip(4)
        .fold<double>(
          0,
          (sum, entry) => sum + entry.value,
        );

    return [
      ...topFour,
      MapEntry<String, double>(
        'Others',
        others,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // INSIGHTS
  // ---------------------------------------------------------------------------

  static pw.Widget _insightsCard({
    required DateTimeRange period,
    required Map<String, double> categories,
    required List<Expense> expenses,
    required double currentExpenseTotal,
    required double previousExpenseTotal,
    required String currency,
  }) {
    final sortedCategories = categories.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    final topCategory =
        sortedCategories.isEmpty ? null : sortedCategories.first;

    final topCategoryPercent = topCategory == null ||
            currentExpenseTotal == 0
        ? 0
        : (topCategory.value /
                currentExpenseTotal *
                100)
            .round();

    final highestDay =
        _highestSpendingDay(expenses);

    final comparison = _comparisonText(
      currentExpenseTotal,
      previousExpenseTotal,
      currency,
    );

    final noSpendDays =
        _noSpendDays(period, expenses);

    return pw.Container(
      height: 191,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: _line,
          width: .55,
        ),
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6.5,
            ),
            decoration: pw.BoxDecoration(
              color: _mint,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              children: [
                _vectorIcon(
                  'bulb',
                  '#087F67',
                  14,
                ),
                pw.SizedBox(width: 6),
                pw.Text(
                  'Key Insights',
                  style: pw.TextStyle(
                    fontSize: 9.7,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  _insightRow(
                    icon: 'trophy',
                    iconColor: _orange,
                    title: 'Top Category',
                    value: topCategory == null
                        ? 'No data'
                        : topCategory.key,
                    detail: topCategory == null
                        ? '-'
                        : '${_money(topCategory.value, currency)} '
                            '($topCategoryPercent%)',
                  ),
                  _insightRow(
                    icon: 'calendar',
                    iconColor: _blue,
                    title: 'Highest Spending Day',
                    value: highestDay == null
                        ? 'No data'
                        : DateFormat(
                            'dd MMMM yyyy',
                          ).format(highestDay.date),
                    detail: highestDay == null
                        ? '-'
                        : _money(
                            highestDay.amount,
                            currency,
                          ),
                  ),
                  _insightRow(
                    icon: 'downtrend',
                    iconColor: _red,
                    title: 'Compared to Previous Period',
                    value: comparison.title,
                    detail: comparison.detail,
                  ),
                  _insightRow(
                    icon: 'calendar',
                    iconColor: _green,
                    title: 'No-Spend Days',
                    value: '$noSpendDays days',
                    detail:
                        'No expenses recorded on these days.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _insightRow({
    required String icon,
    required PdfColor iconColor,
    required String title,
    required String value,
    required String detail,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _iconBadge(
          icon,
          _iconHex(iconColor),
          background: _paleFor(iconColor),
          size: 24,
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 5.8,
                  color: _muted,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                value,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 7.3,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                detail,
                maxLines: 2,
                style: pw.TextStyle(
                  fontSize: 5.3,
                  height: 1.2,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TRANSACTION DATA + RUNNING BALANCE
  // ---------------------------------------------------------------------------

  static List<_PdfRowWithBalance>
      _transactionRows(
    double opening,
    List<Expense> expenses,
    List<Income> incomes,
  ) {
    final rows = <_PdfRow>[
      ...incomes
        .map(
          (item) => _PdfRow(
            id: item.id,
            date: item.date,
            title: item.title,
            category: item.source,
            amount: item.amount,
            income: true,
          ),
        ),
      ...expenses
        .map(
          (item) => _PdfRow(
            id: item.id,
            date: item.date,
            title: item.title,
            category: item.category,
            amount: item.amount,
            income: false,
          ),
        ),
    ];

    // Calculate each row's real balance in chronological order. The table is
    // rendered newest-first, but the balance attached to a row must remain
    // the balance immediately after that transaction happened.
    final chronologicalRows = <_PdfRow>[...rows]
      ..sort(_compareChronological);

    var balance = opening;
    final balanceAfterTransaction = <_PdfRow, double>{};

    for (final row in chronologicalRows) {
      balance +=
          row.income ? row.amount : -row.amount;
      balanceAfterTransaction[row] = balance;
    }

    final displayRows = <_PdfRow>[...rows]
      ..sort(_compareNewestFirst);

    return displayRows
        .map(
          (row) => _PdfRowWithBalance(
            row,
            balanceAfterTransaction[row] ?? opening,
          ),
        )
        .toList();
  }

  static int _compareChronological(
    _PdfRow a,
    _PdfRow b,
  ) {
    final dateCompare =
        a.date.compareTo(b.date);

    if (dateCompare != 0) {
      return dateCompare;
    }

    // If two records have exactly the same timestamp, put income before
    // expense so balance progression is more intuitive.
    if (a.income != b.income) {
      return a.income ? -1 : 1;
    }

    final idA = a.id ?? -1;
    final idB = b.id ?? -1;

    if (idA != idB) {
      return idA.compareTo(idB);
    }

    return a.title.compareTo(b.title);
  }

  static int _compareNewestFirst(
    _PdfRow a,
    _PdfRow b,
  ) {
    final dateCompare = b.date.compareTo(a.date);

    if (dateCompare != 0) {
      return dateCompare;
    }

    // Keep same-time income before expense for a readable daily ledger.
    if (a.income != b.income) {
      return a.income ? -1 : 1;
    }

    final idA = a.id ?? -1;
    final idB = b.id ?? -1;

    if (idA != idB) {
      return idA.compareTo(idB);
    }

    return a.title.compareTo(b.title);
  }

  static pw.Widget _transactionTable(
    List<_PdfRowWithBalance> rows,
    String currency,
  ) {
    final data = <pw.TableRow>[
      _tableHeaderRow(),
      ...rows.map(
        (row) => _transactionRow(
          row,
          currency,
        ),
      ),
    ];

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: _line,
          width: .35,
        ),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(62),
        1: const pw.FixedColumnWidth(66),
        2: const pw.FlexColumnWidth(1.12),
        3: const pw.FlexColumnWidth(1.35),
        4: const pw.FixedColumnWidth(72),
        5: const pw.FixedColumnWidth(72),
      },
      children: data,
    );
  }

  static pw.TableRow _tableHeaderRow() {
    final headers = [
      'Date',
      'Type',
      'Title',
      'Category',
      'Amount',
      'Balance',
    ];

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: _mintStrong,
      ),
      children: headers.map(
        (value) {
          final index = headers.indexOf(value);

          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            child: pw.Text(
              value,
              textAlign: index >= 4
                  ? pw.TextAlign.right
                  : pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: 6.7,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  static pw.TableRow _transactionRow(
    _PdfRowWithBalance row,
    String currency,
  ) {
    final amountColor =
        row.row.income ? _greenDark : _red;

    return pw.TableRow(
      children: [
        _tableCell(
          _transactionDate(row.row.date),
        ),
        _tableWidgetCell(
          pw.Row(
            children: [
              _iconBadge(
                row.row.income
                    ? 'income'
                    : 'expense',
                row.row.income
                    ? '#087F67'
                    : '#E53935',
                background: row.row.income
                    ? _greenSoft
                    : _redSoft,
                size: 15,
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  row.row.income
                      ? 'Income'
                      : 'Expense',
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 5.9,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        _tableCell(
          row.row.title,
          bold: true,
        ),
        _tableWidgetCell(
          pw.Row(
            children: [
              _iconBadge(
                row.row.income
                    ? 'wallet'
                    : _categoryIconName(
                        row.row.category,
                      ),
                row.row.income
                    ? '#087F67'
                    : _iconHex(
                        _categoryColor(
                          row.row.category,
                        ),
                      ),
                background: row.row.income
                    ? _greenSoft
                    : _categoryBackground(
                        row.row.category,
                      ),
                size: 15,
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  row.row.category,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 5.9,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        _tableCell(
          _money(
            row.row.amount,
            currency,
          ),
          color: amountColor,
          bold: true,
          alignRight: true,
        ),
        _tableCell(
          _money(
            row.balance,
            currency,
          ),
          bold: true,
          alignRight: true,
        ),
      ],
    );
  }

  static pw.Widget _tableCell(
    String value, {
    PdfColor? color,
    bool bold = false,
    bool alignRight = false,
  }) {
    return _tableWidgetCell(
      pw.Text(
        value,
        maxLines: 2,
        textAlign: alignRight
            ? pw.TextAlign.right
            : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 5.9,
          height: 1.15,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color ?? _ink,
        ),
      ),
    );
  }

  static pw.Widget _tableWidgetCell(
    pw.Widget child,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // CALCULATION HELPERS
  // ---------------------------------------------------------------------------

  static bool _isInsidePeriod(
    DateTime date,
    DateTimeRange period,
  ) {
    final start = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );

    final endExclusive = DateTime(
      period.end.year,
      period.end.month,
      period.end.day,
    ).add(
      const Duration(days: 1),
    );

    return !date.isBefore(start) &&
        date.isBefore(endExclusive);
  }

  static double _openingBalanceFromHistory(
    DateTimeRange period,
    List<Expense> expenses,
    List<Income> incomes,
  ) {
    final periodStart = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );

    var value = 0.0;

    for (final item in incomes) {
      if (item.date.isBefore(periodStart)) {
        value += item.amount;
      }
    }

    for (final item in expenses) {
      if (item.date.isBefore(periodStart)) {
        value -= item.amount;
      }
    }

    return value;
  }

  static DateTimeRange _previousPeriod(
    DateTimeRange period,
  ) {
    final days = _periodDayCount(period);

    final previousEnd = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    ).subtract(
      const Duration(days: 1),
    );

    final previousStart = previousEnd.subtract(
      Duration(days: days - 1),
    );

    return DateTimeRange(
      start: previousStart,
      end: previousEnd,
    );
  }

  static int _periodDayCount(
    DateTimeRange period,
  ) {
    final start = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );

    final end = DateTime(
      period.end.year,
      period.end.month,
      period.end.day,
    );

    return end.difference(start).inDays + 1;
  }

  static _HighestDay? _highestSpendingDay(
    List<Expense> expenses,
  ) {
    if (expenses.isEmpty) {
      return null;
    }

    final totals = <DateTime, double>{};

    for (final item in expenses) {
      final day = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
      );

      totals.update(
        day,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }

    final sorted = totals.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    return _HighestDay(
      sorted.first.key,
      sorted.first.value,
    );
  }

  static int _noSpendDays(
    DateTimeRange period,
    List<Expense> expenses,
  ) {
    final spendingDays = expenses
        .map(
          (item) => DateTime(
            item.date.year,
            item.date.month,
            item.date.day,
          ),
        )
        .toSet()
        .length;

    return math.max(
      0,
      _periodDayCount(period) -
          spendingDays,
    );
  }

  static _ComparisonInsight _comparisonText(
    double current,
    double previous,
    String currency,
  ) {
    if (previous <= 0) {
      if (current <= 0) {
        return const _ComparisonInsight(
          'No change',
          'No spending in either period.',
        );
      }

      return _ComparisonInsight(
        'No previous data',
        'Current spending: ${_money(current, currency)}',
      );
    }

    final difference = current - previous;

    final percentage =
        (difference.abs() / previous * 100);

    if (difference.abs() < .01) {
      return const _ComparisonInsight(
        'No change',
        'Spending is the same as the previous period.',
      );
    }

    if (difference < 0) {
      return _ComparisonInsight(
        '${percentage.round()}% less',
        'You spent ${_money(difference.abs(), currency)} less.',
      );
    }

    return _ComparisonInsight(
      '${percentage.round()}% more',
      'You spent ${_money(difference, currency)} more.',
    );
  }

  // ---------------------------------------------------------------------------
  // CHART HELPERS
  // ---------------------------------------------------------------------------

  static int _barBucketCount(
    int totalDays,
  ) {
    if (totalDays <= 7) return 1;
    if (totalDays <= 14) return 2;
    if (totalDays <= 35) return 5;
    if (totalDays <= 90) return 6;
    if (totalDays <= 180) return 8;
    return 12;
  }

  static int _lineBucketCount(
    int totalDays,
  ) {
    if (totalDays <= 7) return 4;
    if (totalDays <= 35) return 7;
    if (totalDays <= 90) return 8;
    if (totalDays <= 180) return 10;
    return 12;
  }

  static int _bucketIndex(
    DateTime date,
    DateTimeRange period,
    int bucketCount,
  ) {
    final totalDays = _periodDayCount(period);

    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final normalizedStart = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );

    final offset = normalizedDate
        .difference(normalizedStart)
        .inDays
        .clamp(0, totalDays - 1);

    return (offset * bucketCount ~/ totalDays)
        .clamp(0, bucketCount - 1)
        .toInt();
  }

  static (DateTime, DateTime)
      _bucketDateRange(
    DateTimeRange period,
    int bucketCount,
    int bucketIndex,
  ) {
    final totalDays = _periodDayCount(period);

    final startOffset =
        (totalDays * bucketIndex / bucketCount)
            .floor();

    final endOffset =
        ((totalDays * (bucketIndex + 1) /
                    bucketCount)
                .ceil() -
            1)
            .clamp(0, totalDays - 1);

    final start =
        period.start.add(
      Duration(days: startOffset),
    );

    final end =
        period.start.add(
      Duration(days: endOffset),
    );

    return (start, end);
  }

  static String _compactChartNumber(
    num value,
  ) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      final number = value / 1000;

      return number % 1 == 0
          ? '${number.toInt()}K'
          : '${number.toStringAsFixed(1)}K';
    }

    return value.round().toString();
  }

  static double _niceChartMax(
    double maxValue,
  ) {
    if (maxValue <= 0) {
      return 4;
    }

    final rawStep = maxValue / 4;

    final exponent = math.pow(
      10,
      (math.log(rawStep) / math.ln10)
          .floor(),
    ).toDouble();

    final fraction =
        rawStep / exponent;

    final niceFraction = fraction <= 1
        ? 1
        : fraction <= 2
            ? 2
            : fraction <= 2.5
                ? 2.5
                : fraction <= 5
                    ? 5
                    : 10;

    return niceFraction * exponent * 4;
  }

  // ---------------------------------------------------------------------------
  // CATEGORY HELPERS
  // ---------------------------------------------------------------------------

  static String _categoryIconName(
    String category,
  ) {
    if (category == 'Food & Dining') {
      return 'food';
    }

    if (category == 'Transport') {
      return 'transport';
    }

    if (category == 'Shopping') {
      return 'shopping';
    }

    if (category == 'Bills') {
      return 'bills';
    }

    if (category == 'Health') {
      return 'health';
    }

    if (category == 'Education') {
      return 'book';
    }

    if (category == 'Entertainment') {
      return 'entertainment';
    }

    return 'list';
  }

  static PdfColor _categoryColor(
    String category,
  ) {
    if (category == 'Food & Dining') {
      return _orange;
    }

    if (category == 'Transport') {
      return _blue;
    }

    if (category == 'Shopping') {
      return _pink;
    }

    if (category == 'Bills') {
      return _purple;
    }

    if (category == 'Health') {
      return _health;
    }

    if (category == 'Education') {
      return _green;
    }

    if (category == 'Entertainment') {
      return PdfColor.fromInt(
        0xFF7C3AED,
      );
    }

    return _grey;
  }

  static PdfColor _categoryBackground(
    String category,
  ) {
    if (category == 'Food & Dining') {
      return _orangeSoft;
    }

    if (category == 'Transport') {
      return _blueSoft;
    }

    if (category == 'Shopping') {
      return _pinkSoft;
    }

    if (category == 'Bills') {
      return _purpleSoft;
    }

    if (category == 'Health') {
      return _healthSoft;
    }

    if (category == 'Education') {
      return _greenSoft;
    }

    if (category == 'Entertainment') {
      return _purpleSoft;
    }

    return _greySoft;
  }

  // ---------------------------------------------------------------------------
  // ICONS
  // ---------------------------------------------------------------------------

  static pw.Widget _iconBadge(
    String name,
    String color, {
    PdfColor? background,
    double size = 16,
  }) {
    return pw.Container(
      width: size,
      height: size,
      padding: pw.EdgeInsets.all(
        math.max(2.0, size * .18),
      ),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: background ?? _mint,
        borderRadius: pw.BorderRadius.circular(
          math.max(4.0, size * .27),
        ),
      ),
      child: _vectorIcon(
        name,
        color,
        math.max(7, size * .62),
      ),
    );
  }

  static pw.Widget _vectorIcon(
    String name,
    String color,
    double size,
  ) {
    return pw.SvgImage(
      svg: _iconSvg(
        name,
        color,
      ),
      width: size,
      height: size,
      fit: pw.BoxFit.contain,
    );
  }

  static String _iconSvg(
    String name,
    String color,
  ) {
    String body;

    switch (name) {
      case 'wallet':
        body =
            '<path fill="$color" d="M3 6.5A2.5 2.5 0 0 1 5.5 4H19a2 2 0 0 1 2 2v1H7a4 4 0 0 0 0 8h14v3a2 2 0 0 1-2 2H5.5A2.5 2.5 0 0 1 3 17.5v-11Z"/>'
            '<path fill="$color" d="M7 8h14v6H7a3 3 0 1 1 0-6Zm9 2a1 1 0 1 0 0 2 1 1 0 0 0 0-2Z"/>';
        break;

      case 'income':
        body =
            '<path d="M12 19V5m0 0 6 6m-6-6-6 6" fill="none" stroke="$color" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>';
        break;

      case 'expense':
        body =
            '<path d="M12 5v14m0 0 6-6m-6 6-6-6" fill="none" stroke="$color" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>';
        break;

      case 'chart':
        body =
            '<path d="M4 20V10h4v10H4Zm6 0V4h4v16h-4Zm6 0v-7h4v7h-4Z" fill="$color"/>';
        break;

      case 'trend':
        body =
            '<path d="m4 17 5-5 3 3 7-8" fill="none" stroke="$color" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
            '<path d="M15 7h4v4" fill="none" stroke="$color" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>';
        break;

      case 'downtrend':
        body =
            '<path d="m4 7 5 5 3-3 7 8" fill="none" stroke="$color" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
            '<path d="M15 17h4v-4" fill="none" stroke="$color" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>';
        break;

      case 'list':
        body =
            '<rect x="4" y="4" width="16" height="16" rx="2" fill="none" stroke="$color" stroke-width="2"/>'
            '<path d="M8 8h8M8 12h8M8 16h5" fill="none" stroke="$color" stroke-width="2" stroke-linecap="round"/>';
        break;

      case 'calendar':
        body =
            '<rect x="4" y="5" width="16" height="15" rx="2" fill="none" stroke="$color" stroke-width="2"/>'
            '<path d="M8 3v4M16 3v4M4 9h16M8 13h2M12 13h2M16 13h1M8 16h2M12 16h2" fill="none" stroke="$color" stroke-width="1.6" stroke-linecap="round"/>';
        break;

      case 'trophy':
        body =
            '<path d="M8 4h8v4a4 4 0 0 1-8 0V4Zm4 8v4m-4 3h8M6 6H4a2 2 0 0 0 2 3m12-3h2a2 2 0 0 1-2 3" fill="none" stroke="$color" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>';
        break;

      case 'bulb':
        body =
            '<path d="M8 14a5 5 0 1 1 8 0c-.8.8-1.3 1.5-1.5 3h-5c-.2-1.5-.7-2.2-1.5-3Z" fill="none" stroke="$color" stroke-width="1.8" stroke-linejoin="round"/>'
            '<path d="M9.5 20h5M10 17h4M12 2v1M4.5 5.5l1 1M19.5 5.5l-1 1" fill="none" stroke="$color" stroke-width="1.8" stroke-linecap="round"/>';
        break;

      case 'food':
        body =
            '<path d="M7 3v7m-2-7v7m4-7v7M5 10h4m-2 0v11M16 3v18m0-18c3 2 3 7 0 9" fill="none" stroke="$color" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>';
        break;

      case 'transport':
        body =
            '<rect x="4" y="5" width="16" height="13" rx="2" fill="none" stroke="$color" stroke-width="1.8"/>'
            '<path d="M4 10h16M8 18v2m8-2v2M7 14h2m6 0h2" fill="none" stroke="$color" stroke-width="1.8" stroke-linecap="round"/>';
        break;

      case 'shopping':
        body =
            '<path d="M6 8h12l1 12H5L6 8Zm3 0a3 3 0 0 1 6 0" fill="none" stroke="$color" stroke-width="1.8" stroke-linejoin="round"/>';
        break;

      case 'bills':
        body =
            '<rect x="5" y="3" width="14" height="18" rx="2" fill="none" stroke="$color" stroke-width="1.8"/>'
            '<path d="M8 8h8M8 12h8M8 16h5" fill="none" stroke="$color" stroke-width="1.8" stroke-linecap="round"/>';
        break;

      case 'health':
        body =
            '<path d="M12 20S4 15.5 4 9a4 4 0 0 1 7-2 4 4 0 0 1 7 2c0 6.5-6 10-6 11Z" fill="none" stroke="$color" stroke-width="1.8" stroke-linejoin="round"/>'
            '<path d="M9 11h6m-3-3v6" fill="none" stroke="$color" stroke-width="1.8" stroke-linecap="round"/>';
        break;

      case 'book':
        body =
            '<path d="M4 5.5A3.5 3.5 0 0 1 7.5 2H12v17H7.5A3.5 3.5 0 0 0 4 22V5.5Zm16 0A3.5 3.5 0 0 0 16.5 2H12v17h4.5A3.5 3.5 0 0 1 20 22V5.5Z" fill="none" stroke="$color" stroke-width="1.7" stroke-linejoin="round"/>';
        break;

      case 'entertainment':
        body =
            '<rect x="3" y="6" width="18" height="12" rx="2" fill="none" stroke="$color" stroke-width="1.8"/>'
            '<path d="m10 9 5 3-5 3V9Z" fill="$color"/>';
        break;

      case 'info':
        body =
            '<circle cx="12" cy="12" r="8.5" fill="none" stroke="$color" stroke-width="2"/>'
            '<path d="M12 11v5m0-8v.2" fill="none" stroke="$color" stroke-width="2" stroke-linecap="round"/>';
        break;

      default:
        body =
            '<circle cx="12" cy="12" r="8" fill="none" stroke="$color" stroke-width="2"/>';
    }

    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">$body</svg>';
  }

  // ---------------------------------------------------------------------------
  // SMALL UI HELPERS
  // ---------------------------------------------------------------------------

  static pw.Widget _legend(
    PdfColor color,
    String label,
  ) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 6,
          height: 6,
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 3),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 6.3,
            color: _muted,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryLine(
    String label,
    double value,
    String currency, {
    required PdfColor color,
  }) {
    return pw.Row(
      crossAxisAlignment:
          pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              height: 1.15,
              color: _ink,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          _money(
            value,
            currency,
          ),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static PdfColor _paleFor(
    PdfColor color,
  ) {
    if (color == _red) {
      return _redSoft;
    }

    if (color == _blue) {
      return _blueSoft;
    }

    if (color == _orange) {
      return _orangeSoft;
    }

    if (color == _pink) {
      return _pinkSoft;
    }

    if (color == _purple) {
      return _purpleSoft;
    }

    if (color == _health) {
      return _healthSoft;
    }

    return _greenSoft;
  }

  static String _iconHex(
    PdfColor color,
  ) {
    if (color == _red) {
      return '#E53935';
    }

    if (color == _blue) {
      return '#2F80ED';
    }

    if (color == _orange) {
      return '#FF9F43';
    }

    if (color == _pink) {
      return '#EC4899';
    }

    if (color == _purple) {
      return '#8B5CF6';
    }

    if (color == _health) {
      return '#EF4444';
    }

    if (color == _grey) {
      return '#9CA3AF';
    }

    if (color == _greenDark) {
      return '#075D4E';
    }

    return '#087F67';
  }

  // ---------------------------------------------------------------------------
  // TEXT FORMATTERS
  // ---------------------------------------------------------------------------

  static String _money(
    double value,
    String currency,
  ) {
    final symbol = currency == 'BDT'
        ? '৳'
        : currency == 'USD'
            ? r'$'
            : currency == 'EUR'
                ? '€'
                : currency;

    final formatter =
        NumberFormat('#,##0');

    return '$symbol ${formatter.format(value)}';
  }

  static String _periodTitle(
    DateTimeRange period,
  ) {
    final sameMonth =
        period.start.year == period.end.year &&
            period.start.month ==
                period.end.month;

    if (sameMonth) {
      return DateFormat(
        'MMMM yyyy',
      ).format(
        period.start,
      );
    }

    return '${DateFormat('dd MMM yyyy').format(period.start)} - '
        '${DateFormat('dd MMM yyyy').format(period.end)}';
  }

  static String _periodDate(
    DateTime date,
  ) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(date);
  }

  static String _transactionDate(
    DateTime date,
  ) {
    return DateFormat(
      'dd MMM yyyy\nh:mm a',
    ).format(date);
  }

  static String _generatedDate(
    DateTime date,
  ) {
    return DateFormat(
      'dd MMM yyyy, h:mm a',
    ).format(date).toUpperCase();
  }
}

// -----------------------------------------------------------------------------
// INTERNAL MODELS
// -----------------------------------------------------------------------------

class _PdfRow {
  final int? id;
  final DateTime date;
  final String title;
  final String category;
  final double amount;
  final bool income;

  const _PdfRow({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    required this.amount,
    required this.income,
  });
}

class _PdfRowWithBalance {
  final _PdfRow row;
  final double balance;

  const _PdfRowWithBalance(
    this.row,
    this.balance,
  );
}

class _HighestDay {
  final DateTime date;
  final double amount;

  const _HighestDay(
    this.date,
    this.amount,
  );
}

class _ComparisonInsight {
  final String title;
  final String detail;

  const _ComparisonInsight(
    this.title,
    this.detail,
  );
}

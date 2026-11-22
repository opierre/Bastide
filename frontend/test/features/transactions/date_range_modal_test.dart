import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/transactions/presentation/date_range_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  DateTime? from,
  DateTime? to,
  Locale locale = const Locale('fr'),
}) {
  return MaterialApp(
    locale: locale,
    theme: AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DateRangeModal(from: from, to: to),
    ),
  );
}

Future<void> _type(WidgetTester tester, String field, String text) async {
  await tester.enterText(find.byKey(Key('transactionsDateRange$field')), text);
  await tester.pump();
}

/// Opens the modal the way the filter pill does, so the test sees the record it
/// hands back rather than only the dialog closing.
Future<(DateTime?, DateTime?)?> _openAndSubmit(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester) fill, {
  DateTime? from,
  DateTime? to,
  bool submitWithEnter = false,
}) async {
  (DateTime?, DateTime?)? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showTransactionDateRange(
                context,
                from: from,
                to: to,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await fill(tester);
  if (submitWithEnter) {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  } else {
    await tester.tap(find.byKey(const Key('transactionsDateRangeApply')));
  }
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('fills both fields from the range already applied', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31)),
    );
    await tester.pumpAndSettle();

    expect(find.text('01/03/2026'), findsOneWidget);
    expect(find.text('31/03/2026'), findsOneWidget);
  });

  testWidgets('applies the typed range', (tester) async {
    final result = await _openAndSubmit(tester, (t) async {
      await _type(t, 'From', '01/03/2026');
      await _type(t, 'To', '31/03/2026');
    });

    expect(result, (DateTime(2026, 3, 1), DateTime(2026, 3, 31)));
  });

  testWidgets('clearing both fields lifts the filter', (tester) async {
    final result = await _openAndSubmit(
      tester,
      (t) async {
        await _type(t, 'From', '');
        await _type(t, 'To', '');
      },
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 31),
    );

    expect(result, (null, null));
  });

  testWidgets('refuses a range that runs backwards', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await _type(tester, 'From', '31/03/2026');
    await _type(tester, 'To', '01/03/2026');
    await tester.tap(find.byKey(const Key('transactionsDateRangeApply')));
    await tester.pumpAndSettle();

    // The error sits under « Au » alone; « Du » keeps its place beside it.
    final error = find.text('La date de fin précède la date de début.');
    expect(error, findsOneWidget);
    final to = tester.getRect(find.byKey(const Key('transactionsDateRangeTo')));
    final from = tester.getRect(
      find.byKey(const Key('transactionsDateRangeFrom')),
    );
    expect(from.top, to.top);
    expect(tester.getTopLeft(error).dx, greaterThanOrEqualTo(to.left));
    expect(find.byType(DateRangeModal), findsOneWidget);
  });

  testWidgets('sits on the 420 px frame with « Annuler » · « Appliquer »', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('appModalFrame'))).width,
      AppModalSizes.w420,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Période'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('transactionsDateRangeCancel')),
        matching: find.text('Annuler'),
      ),
      findsOneWidget,
    );
    expect(find.text('Appliquer'), findsOneWidget);
  });

  testWidgets('« Du » takes the focus when the modal opens', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('transactionsDateRangeFrom')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('Enter in a field applies the range', (tester) async {
    final result = await _openAndSubmit(tester, (t) async {
      await _type(t, 'From', '01/03/2026');
      await _type(t, 'To', '31/03/2026');
    }, submitWithEnter: true);

    expect(result, (DateTime(2026, 3, 1), DateTime(2026, 3, 31)));
  });

  testWidgets('Escape on an edited range asks before dropping it', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await _type(tester, 'From', '01/03/2026');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalDiscard')), findsOneWidget);
  });

  testWidgets('refuses one date without the other', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await _type(tester, 'From', '01/03/2026');
    await tester.tap(find.byKey(const Key('transactionsDateRangeApply')));
    await tester.pumpAndSettle();

    expect(find.text('Renseignez les deux dates, ou aucune.'), findsOneWidget);
    expect(find.byType(DateRangeModal), findsOneWidget);
  });

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Date range'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });
}

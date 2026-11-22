import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/features/mortgages/application/mortgages_controller.dart';
import 'package:bastide/features/mortgages/data/mortgages_repository.dart';
import 'package:bastide/features/mortgages/domain/mortgage.dart';
import 'package:bastide/features/mortgages/presentation/mortgage_form_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/mortgages_fixtures.dart';

class MockMortgagesRepository extends Mock implements MortgagesRepository {}

Widget _wrap({
  required FakeMortgagesController controller,
  required MockMortgagesRepository repository,
  Mortgage? initial,
  List<LoanProperty> properties = const [],
}) {
  return ProviderScope(
    overrides: [
      mortgagesControllerProvider.overrideWith(() => controller),
      mortgagesRepositoryProvider.overrideWithValue(repository),
      loanPropertiesProvider.overrideWith((ref) => properties),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MortgageFormModal(initial: initial)),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

ComputedInstalment _computed(int monthly) => ComputedInstalment(
  monthlyPaymentMinor: monthly,
  totalInstalmentMinor: monthly,
  totalInterestMinor: 194280,
  currency: 'EUR',
);

void _stubCompute(MockMortgagesRepository repository, int monthly) {
  when(
    () => repository.compute(
      principalMinor: any(named: 'principalMinor'),
      annualRateBps: any(named: 'annualRateBps'),
      insuranceMonthlyMinor: any(named: 'insuranceMonthlyMinor'),
      termMonths: any(named: 'termMonths'),
      upfrontFeesMinor: any(named: 'upfrontFeesMinor'),
    ),
  ).thenAnswer((_) async => _computed(monthly));
}

/// The frame's worked example: the Prêt travaux, typed the way a French user
/// reads it.
Future<void> _fillWorksLoan(WidgetTester tester, {String rate = '4,90'}) async {
  await tester.enterText(
    find.byKey(const Key('mortgageFormLabel')),
    'Travaux cuisine',
  );
  await tester.enterText(
    find.byKey(const Key('mortgageFormLender')),
    'Crédit Agricole',
  );
  await tester.enterText(
    find.byKey(const Key('mortgageFormPrincipal')),
    '15000',
  );
  await tester.enterText(find.byKey(const Key('mortgageFormRate')), rate);
  await tester.enterText(find.byKey(const Key('mortgageFormTerm')), '60');
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('mortgageFormFirstPayment')),
      matching: find.byType(EditableText),
    ),
    '01/03/2025',
  );
}

String _eur(int minor) =>
    formatAmount(amountMinor: minor, currency: 'EUR', locale: 'fr');

String _plateDetail(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('mortgageFormPlateDetail'))).data!;

/// Picks « In fine » in the Remboursement select.
Future<void> _pickInterestOnly(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mortgageFormRepayment')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('In fine').last);
  await tester.pumpAndSettle();
}

/// Lets the plate's debounce elapse and its request resolve.
Future<void> _settlePreview(WidgetTester tester) async {
  await tester.pump(
    LoanInstalmentPreview.debounce + const Duration(milliseconds: 50),
  );
  await tester.pumpAndSettle();
}

void main() {
  late MockMortgagesRepository repository;

  setUp(() {
    repository = MockMortgagesRepository();
    _stubCompute(repository, 28238);
  });

  test('a typed percent converts to bps on its digits', () {
    expect(parseRateBps('3,45'), 345);
    expect(parseRateBps('3.45'), 345);
    expect(parseRateBps('4,9'), 490);
    expect(parseRateBps('5'), 500);
    expect(parseRateBps('3,456'), isNull);
    expect(parseRateBps('abc'), isNull);
    expect(formatRateInput(345, 'fr'), '3,45');
    expect(formatRateInput(490, 'en'), '4.90');
  });

  testWidgets(
    'a comma-typed rate is submitted as bps, and Type writes only the kind',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeMortgagesController();
      await tester.pumpWidget(
        _wrap(controller: controller, repository: repository),
      );
      await tester.pumpAndSettle();

      await _fillWorksLoan(tester, rate: '3,45');
      await tester.tap(find.byKey(const Key('mortgageFormKind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prêt travaux').last);
      await tester.pumpAndSettle();
      await _settlePreview(tester);

      await tester.tap(find.byKey(const Key('mortgageFormSubmit')));
      await tester.pumpAndSettle();

      final draft = controller.createCalls.single;
      expect(draft.annualRateBps, 345);
      expect(draft.principalMinor, 1500000);
      expect(draft.termMonths, 60);
      expect(draft.firstPaymentDate, DateTime(2025, 3, 1));
      expect(draft.insuranceMonthlyMinor, 0);
      expect(draft.upfrontFeesMinor, 0);
      expect(draft.kind, MortgageKind.works);
      expect(draft.repaymentType, RepaymentType.constantPayment);
    },
  );

  testWidgets(
    'the mensualité plate follows the compute endpoint as fields change',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(controller: FakeMortgagesController(), repository: repository),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mortgageFormPlatePending')), findsOneWidget);

      await _fillWorksLoan(tester);
      await _settlePreview(tester);

      expect(_plateDetail(tester), contains(_eur(28238)));
      verify(
        () => repository.compute(
          principalMinor: 1500000,
          annualRateBps: 490,
          insuranceMonthlyMinor: 0,
          termMonths: 60,
          upfrontFeesMinor: 0,
        ),
      ).called(greaterThanOrEqualTo(1));

      _stubCompute(repository, 28307);
      await tester.enterText(find.byKey(const Key('mortgageFormRate')), '5');
      await _settlePreview(tester);

      expect(_plateDetail(tester), contains(_eur(28307)));
    },
  );

  testWidgets('the property picker shows an address under its label', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeMortgagesController(),
        repository: repository,
        properties: const [
          LoanProperty(
            id: 'p1',
            label: 'Appartement Lyon 3e',
            address: '3 rue des Glycines, 69003 Lyon',
          ),
          LoanProperty(id: 'p2', label: 'Studio Villeurbanne'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Closed, the field states the label alone.
    expect(find.text('3 rue des Glycines, 69003 Lyon'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('mortgageFormProperty')));
    await tester.tap(find.byKey(const Key('mortgageFormProperty')));
    await tester.pumpAndSettle();

    expect(find.text('Appartement Lyon 3e'), findsOneWidget);
    expect(find.text('3 rue des Glycines, 69003 Lyon'), findsOneWidget);
    expect(find.text('Studio Villeurbanne'), findsOneWidget);
    // One address for two biens: the one without shows no secondary line.
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Studio Villeurbanne'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an in-fine loan never shows a constant-payment figure', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeMortgagesController(), repository: repository),
    );
    await tester.pumpAndSettle();

    await _pickInterestOnly(tester);
    await _fillWorksLoan(tester);
    await _settlePreview(tester);

    expect(
      find.byKey(const Key('mortgageFormPlateInterestOnly')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mortgageFormPlateDetail')), findsNothing);
    verifyNever(
      () => repository.compute(
        principalMinor: any(named: 'principalMinor'),
        annualRateBps: any(named: 'annualRateBps'),
        insuranceMonthlyMinor: any(named: 'insuranceMonthlyMinor'),
        termMonths: any(named: 'termMonths'),
        upfrontFeesMinor: any(named: 'upfrontFeesMinor'),
      ),
    );
  });

  testWidgets(
    'a degenerate loan is explained inline under the rate, not in a toast',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeMortgagesController()
        ..errorOnSave = const ApiFailure(
          code: 'MORTGAGE_NON_AMORTIZING',
          message: 'no',
        );
      await tester.pumpWidget(
        _wrap(controller: controller, repository: repository),
      );
      await tester.pumpAndSettle();

      await _fillWorksLoan(tester);
      await _settlePreview(tester);
      await tester.tap(find.byKey(const Key('mortgageFormSubmit')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Ce crédit ne se rembourse pas : l’échéance ne couvre pas les intérêts du premier '
          'mois. Modifiez le taux, le capital ou la durée.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mortgageFormError')), findsNothing);
      expect(find.byKey(const Key('mortgageFormSubmit')), findsOneWidget);
    },
  );

  testWidgets(
    'editing prefills the form, and deleting asks a destructive confirmation',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeMortgagesController(
        initialMortgages: [testMortgage()],
      );
      await tester.pumpWidget(
        _wrap(
          controller: controller,
          repository: repository,
          initial: testMortgage(),
        ),
      );
      await tester.pumpAndSettle();
      await _settlePreview(tester);

      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('mortgageFormRate')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '3,45',
      );

      // A ghost « Supprimer » set apart on the footer's left, before
      // « Annuler » and « Enregistrer ».
      final delete = tester.widget<AppButton>(
        find.byKey(const Key('mortgageFormDelete')),
      );
      expect(delete.variant, AppButtonVariant.ghost);
      expect(delete.label, 'Supprimer');
      expect(
        tester.getCenter(find.byKey(const Key('mortgageFormDelete'))).dx,
        lessThan(
          tester.getCenter(find.byKey(const Key('mortgageFormCancel'))).dx,
        ),
      );
      expect(find.text('Enregistrer'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mortgageFormDelete')));
      await tester.pumpAndSettle();
      // The title names the loan; the lead says what goes and what stays.
      expect(
        find.text('Supprimer le crédit « Appartement Lyon 3e » ?'),
        findsOneWidget,
      );
      final lead = tester
          .widget<Text>(find.byKey(const Key('mortgageDeleteBody')))
          .data!;
      expect(lead, contains('Synthèse'));
      expect(lead, contains('Vos comptes ne sont pas modifiés.'));
      // A solid destructive button, with focus on « Annuler » so Enter
      // deletes nothing by mistake.
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('mortgageDeleteConfirm')))
            .variant,
        AppButtonVariant.destructive,
      );
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.descendant(
          of: find.byKey(const Key('appModalCancel')).last,
          matching: find.byWidget(focused.widget),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mortgageDeleteConfirm')));
      await tester.pumpAndSettle();

      expect(controller.archiveCalls, ['m1']);
    },
  );

  testWidgets('lays the fields out on the two-column grid of proposal v6', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeMortgagesController(),
        repository: repository,
        properties: const [LoanProperty(id: 'p1', label: 'Studio')],
      ),
    );
    await tester.pumpAndSettle();

    double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
    double left(String key) => tester.getTopLeft(find.byKey(Key(key))).dx;

    // Libellé spans both columns; then pairs, left then right.
    for (final (first, second) in [
      ('mortgageFormLender', 'mortgageFormKind'),
      ('mortgageFormRepayment', 'mortgageFormPrincipal'),
      ('mortgageFormRate', 'mortgageFormTerm'),
      ('mortgageFormFirstPayment', 'mortgageFormInsurance'),
      ('mortgageFormFees', 'mortgageFormProperty'),
    ]) {
      expect(top(first), top(second), reason: '$first beside $second');
      expect(left(first), lessThan(left(second)));
    }
    expect(top('mortgageFormLabel'), lessThan(top('mortgageFormLender')));
    expect(
      tester.getSize(find.byKey(const Key('mortgageFormLabel'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('mortgageFormLender'))).width * 2,
      ),
    );
    expect(find.text('Bien financé (facultatif)'), findsOneWidget);
    // The new form has no « Supprimer ».
    expect(find.byKey(const Key('mortgageFormDelete')), findsNothing);
    expect(find.text('Nouveau crédit'), findsOneWidget);
  });

  testWidgets('a changed form asks before its input is dropped', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeMortgagesController(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mortgageFormLabel')),
      'Travaux cuisine',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mortgageFormCancel')));
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
  });
}

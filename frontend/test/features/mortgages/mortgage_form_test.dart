import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
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
}) {
  return ProviderScope(
    overrides: [
      mortgagesControllerProvider.overrideWith(() => controller),
      mortgagesRepositoryProvider.overrideWithValue(repository),
      loanPropertiesProvider.overrideWith((ref) => const <LoanProperty>[]),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: appDarkTheme,
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

      expect(
        tester
            .widget<AmountText>(
              find.byKey(const Key('mortgageFormPlateAmount')),
            )
            .amountMinor,
        28238,
      );
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

      expect(
        tester
            .widget<AmountText>(
              find.byKey(const Key('mortgageFormPlateAmount')),
            )
            .amountMinor,
        28307,
      );
    },
  );

  testWidgets('an in-fine loan never shows a constant-payment figure', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeMortgagesController(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('mortgageFormRepayment-interest_only')),
    );
    await tester.pumpAndSettle();
    await _fillWorksLoan(tester);
    await _settlePreview(tester);

    expect(
      find.byKey(const Key('mortgageFormPlateInterestOnly')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mortgageFormPlateAmount')), findsNothing);
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
          'Ce crédit ne se rembourse pas : l\'échéance ne couvre pas les intérêts du premier '
          'mois. Modifiez le taux, le capital ou la durée.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mortgageFormError')), findsNothing);
      expect(find.byKey(const Key('mortgageFormSubmit')), findsOneWidget);
    },
  );

  testWidgets(
    'editing prefills the form, and deleting names both consequences',
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

      await tester.tap(find.byKey(const Key('mortgageFormDelete')));
      await tester.pumpAndSettle();
      final body = tester
          .widget<Text>(find.byKey(const Key('mortgageDeleteBody')))
          .data!;
      expect(body, contains('Synthèse'));
      expect(body, contains('IFI'));

      await tester.tap(find.byKey(const Key('mortgageDeleteConfirm')));
      await tester.pumpAndSettle();

      expect(controller.archiveCalls, ['m1']);
    },
  );
}

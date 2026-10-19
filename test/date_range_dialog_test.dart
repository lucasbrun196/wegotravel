import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:we_go_travel/shared/widgets/inputs/date_range_dialog.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  // A curva com quique (easeOutBack) passa do alvo: ao tirar a sombra da
  // data selecionada, o desfoque ia abaixo de zero por um quadro e o
  // Flutter lançava. Este teste anda quadro a quadro para pegar isso.
  testWidgets('trocar a seleção não lança em nenhum quadro', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTripDatesDialog(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    Future<void> tapAndStep(String day) async {
      await tester.tap(find.text(day).last);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Ida, volta, nova ida (desfaz a seleção anterior), ida antes da ida.
    await tapAndStep('10');
    await tapAndStep('15');
    await tapAndStep('20');
    await tapAndStep('5');
    await tapAndStep('22');
    expect(tester.takeException(), isNull);
  });

  testWidgets('data única aceita o passado, mas não fora do limite', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Um intervalo fixo, no passado, para o teste não depender de hoje:
    // de 5 a 20 de março de 2024.
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showAppDatePicker(
              context,
              initialDate: DateTime(2024, 3, 10),
              firstDate: DateTime(2024, 3, 5),
              lastDate: DateTime(2024, 3, 20),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Abre no mês da data inicial e não deixa sair dele.
    expect(find.text('Março de 2024'), findsOneWidget);
    for (final icon in [Icons.chevron_left_rounded, Icons.chevron_right_rounded]) {
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon)).onPressed, isNull);
    }

    // Fora do limite: não muda a seleção.
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Domingo, 10 de março de 2024'), findsOneWidget);

    // Dentro do limite, mesmo no passado: escolhe.
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2024, 3, 15));
  });
}

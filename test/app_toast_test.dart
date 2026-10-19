import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/core/theme/app_colors.dart';
import 'package:we_go_travel/shared/widgets/feedback/app_toast.dart';

Widget app() => MaterialApp(
      builder: (context, child) => ToastHost(child: child!),
      home: const Scaffold(body: Text('conteúdo')),
    );

Color backgroundOf(WidgetTester tester, String message) => tester
    .widget<Material>(find.ancestor(of: find.text(message), matching: find.byType(Material)).first)
    .color!;

void main() {
  // A pilha é estática: cada teste espera os seus avisos saírem, para
  // nada vazar para o seguinte.
  testWidgets('cada tipo tem a sua cor', (tester) async {
    await tester.pumpWidget(app());
    AppToast.success('salvou');
    AppToast.error('falhou');
    AppToast.warning('atenção');
    await tester.pumpAndSettle();

    expect(backgroundOf(tester, 'salvou'), AppColors.toastSuccess);
    expect(backgroundOf(tester, 'falhou'), AppColors.toastError);
    expect(backgroundOf(tester, 'atenção'), AppColors.toastWarning);

    await tester.pump(AppToast.duration);
    await tester.pumpAndSettle();
  });

  testWidgets('empilha, com o mais novo embaixo', (tester) async {
    await tester.pumpWidget(app());
    AppToast.success('primeiro');
    await tester.pump(const Duration(seconds: 1));
    AppToast.error('segundo');
    await tester.pumpAndSettle();

    final first = tester.getCenter(find.text('primeiro'));
    final second = tester.getCenter(find.text('segundo'));
    expect(second.dy, greaterThan(first.dy));
    // No canto direito da tela.
    expect(second.dx, greaterThan(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2));

    await tester.pump(AppToast.duration);
    await tester.pumpAndSettle();
  });

  testWidgets('some sozinho depois de 7 segundos', (tester) async {
    await tester.pumpWidget(app());
    AppToast.success('some já');
    await tester.pumpAndSettle();

    await tester.pump(AppToast.duration - const Duration(milliseconds: 500));
    expect(find.text('some já'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('some já'), findsNothing);
  });

  testWidgets('o × fecha na hora, e só aquele', (tester) async {
    await tester.pumpWidget(app());
    AppToast.success('fica');
    AppToast.error('sai');
    await tester.pumpAndSettle();

    final close = find.descendant(
      of: find.ancestor(of: find.text('sai'), matching: find.byType(Row)).first,
      matching: find.byType(IconButton),
    );
    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(find.text('sai'), findsNothing);
    expect(find.text('fica'), findsOneWidget);

    await tester.pump(AppToast.duration);
    await tester.pumpAndSettle();
  });
}

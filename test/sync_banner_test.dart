import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/app/providers.dart';
import 'package:we_go_travel/data/services/sync_status_service.dart';
import 'package:we_go_travel/shared/widgets/feedback/sync_banner.dart';

/// Monta o aviso com um estado fixo, sem Firebase no caminho.
Widget app(Stream<SyncStatus> status) => ProviderScope(
      overrides: [syncStatusProvider.overrideWith((ref) => status)],
      child: const MaterialApp(
        home: SyncBanner(child: Scaffold(body: Text('conteúdo'))),
      ),
    );

void main() {
  testWidgets('sem valor ainda, nada aparece', (tester) async {
    await tester.pumpWidget(app(const Stream.empty()));
    await tester.pump();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(find.textContaining('Enviando'), findsNothing);
    expect(find.text('conteúdo'), findsOneWidget);
  });

  testWidgets('em dia com o servidor não mostra faixa', (tester) async {
    await tester.pumpWidget(app(Stream.value(SyncStatus.online)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(find.text('conteúdo'), findsOneWidget);
  });

  testWidgets('offline avisa e mantém o conteúdo na tela', (tester) async {
    await tester.pumpWidget(app(Stream.value(SyncStatus.offline)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsOneWidget);
    // O aviso soma ao conteúdo, não substitui: offline a pessoa segue
    // lendo o roteiro e lançando gasto.
    expect(find.text('conteúdo'), findsOneWidget);
  });

  testWidgets('escrita na fila avisa que está subindo', (tester) async {
    await tester.pumpWidget(app(Stream.value(SyncStatus.pending)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enviando'), findsOneWidget);
    expect(find.textContaining('Sem conexão'), findsNothing);
  });

  testWidgets('a faixa some quando a rede volta', (tester) async {
    final status = Stream<SyncStatus>.fromIterable(
      [SyncStatus.offline, SyncStatus.online],
    );
    await tester.pumpWidget(app(status));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(find.text('conteúdo'), findsOneWidget);
  });
}

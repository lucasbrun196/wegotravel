# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

App de viagem compartilhada em Flutter (Web primeiro, depois Android/iOS) com
Firebase. O `README.md` cobre o produto — permissões, modelo de contas, deploy.
Este arquivo cobre o que faz errar.

O código, os comentários e a documentação são em **português**. O histórico do
git é em **inglês** — ver `.claude/skills/commit/SKILL.md`.

## Comandos

```bash
flutter run -d web-server --web-port 5173 \
  --dart-define=MAPBOX_TOKEN=pk.xxx         # a porta usada por .claude/launch.json
flutter analyze                             # precisa ficar sem nenhum aviso
flutter test
flutter test test/bill_split_test.dart --plain-name 'cada pessoa paga'
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## Como um dado chega na tela

`FirestoreRefs` → repositório → provider → widget.

- **`lib/data/services/firestore_refs.dart`** guarda todos os caminhos do
  Firestore. Tudo mora sob `trips/{tripId}`, o que mantém as regras simples e
  permite apagar uma viagem inteira. Nenhum outro arquivo monta caminho na mão.
- **`lib/data/repositories/`** fala com o Firebase e devolve modelos. Widget
  nenhum toca em `DocumentSnapshot`.
- **`lib/app/providers.dart`** é o índice de tudo que as telas leem.

Regra de dependência: `features` usa `shared`, `data` e `core`; `shared` usa só
`core`; `core` não depende de ninguém.

## Armadilhas

Cada uma destas já custou uma sessão de depuração.

**`currentTripIdProvider` lança por padrão.** Ele é sobrescrito por um
`ProviderScope` dentro da casca da viagem. Todo provider que o consome — direta
ou indiretamente — precisa declarar `dependencies: [...]`, senão o Riverpod
recusa a leitura dentro do escopo com "Tried to read a provider from a place
where one of its dependencies were overridden".

**Formulários só abrem por `showAppSheet`** (`lib/shared/widgets/layout/app_sheet.dart`).
Diálogos e bottom sheets são montados no overlay do Navigator raiz, **fora** do
escopo da viagem; `showAppSheet` reembrulha o `ProviderContainer` de quem abriu.
Chamar `showDialog` direto dentro de uma viagem quebra na hora de salvar.

**Dinheiro é sempre `int` de centavos.** `double` não fecha 9000/6/4. Converter
para texto só na exibição, via `Money.format`. `Money.divide` distribui o resto
um centavo por vez, então a soma bate exatamente com o total.

**O valor da parcela é derivado, nunca guardado.** Sai de
`Bill.effectiveInstallmentCents`, a partir do total, do número de parcelas e do
número de pessoas. Guardar o valor arredondado e recalcular o total a partir
dele foi o que fez R$ 9.950,00 virar R$ 9.950,04. Não existe conceito de juros.

**Ids de cota são determinísticos**: `'{parcela}_{uid}'`. É o que preserva o
pagamento, o comprovante e a marcação de pago quando a conta é editada.

**Nas regras do Firestore, `delete` fica separado de `create, update`.** Em uma
exclusão o `request.resource` é nulo, então qualquer validação que olhe os
campos do documento nega a operação em silêncio — a UI parece funcionar e o
documento continua lá.

**`collectionGroup('shares')` precisa de três coisas:** uma regra própria
(`match /{path=**}/shares/{shareId}`, porque as regras aninhadas não a
autorizam), o filtro por `tripId`, sem o qual a consulta atravessa as viagens
de outras pessoas, e o índice de campo único de `tripId` com escopo
`COLLECTION_GROUP` (o `fieldOverrides` de `firestore.indexes.json`) — o
Firestore só cria sozinho os de escopo de coleção. Sem o índice a consulta
falha, `allSharesProvider` vira lista vazia e todo painel de "já quitado"
mostra zero, enquanto a tela da conta (que lê a subcoleção direto) mostra os
pagamentos. Ver `FirestoreRefs.sharesOfTrip`.

**O link do e-mail de "esqueci minha senha" chega antes do `#`.** O Firebase
acrescenta `?mode=resetPassword&oobCode=...` à URL de ação, que é a raiz do
app; com a estratégia de hash, o go_router não vê essa query. Quem a lê é
`AuthActionLink.fromLaunch()`, uma vez, e já a apaga da barra de endereço —
senão um F5 reabriria a tela com o código gasto. A rota `/redefinir-senha`
passa no `redirect` **antes** da espera pelo Auth: ir para a splash perderia
o código.

**Rotas usam `ShellRoute`, não `StatefulShellRoute`** — este último não aceita
raiz de branch parametrizada, e todas as rotas internas são
`/viagem/:tripId/...`.

**O seletor de mapa também só abre por `showAppSheet`.** Mesma razão dos
formulários — ele é um sheet aninhado, aberto de dentro de outro, e é o
`showAppSheet` que devolve o `PickedPlace` escolhido.

**Coordenada não aparece na tela.** `lat`/`lng` alimentam a API de previsão do
tempo. O que o usuário lê é sempre `placeName` (e `address`), inclusive no
card do roteiro. Um pin cheio no card sinaliza "está fixado no mapa".

**Uma atividade liga-se a várias contas, em `billIds`.** O campo antigo era
`billId`, com uma conta só; `ItineraryItem.fromDoc` ainda lê os dois formatos e
`toMap` apaga o velho com `FieldValue.delete()` — sem isso o `merge: true`
deixaria os dois no documento. Nas estatísticas cada conta soma **uma vez**,
mesmo ligada a várias atividades (`itinerarySpendByCategoryProvider`), senão o
gasto do roteiro infla. Apagar uma conta em Gastos desfaz só o vínculo dela:
`ItineraryRepository.unlinkBill` usa `arrayRemove` e consulta os dois formatos.

**Categoria e transporte são listas** (`categories`, `transports`), com o
mesmo esquema de migração do `billIds`: `fromDoc` lê também os campos antigos
de valor único (`category`, `transport`) e `toMap` os apaga. A **primeira**
categoria marcada é a principal — dá ícone e cor ao card e é onde o gasto
entra nas estatísticas, para não somar a mesma conta em várias categorias. Na
criação de conta o `set` é sem `merge` e recusa `FieldValue.delete()`, por isso
`createBill` tira a chave `category` antes de gravar.

**O service worker é o nosso, `web/sw.js` — o do Flutter não serve mais.**
Desde o Flutter 3.41 o `flutter_service_worker.js` gerado pelo build se
**desregistra** ao ativar: a estratégia `offline-first` foi depreciada e não
guarda recurso nenhum. Por isso o build web roda com `--pwa-strategy=none`
(ver `scripts/vercel_build.sh`) e o registro fica no `web/index.html`: dois
workers no mesmo escopo são um registro só, e o do Flutter apagaria o nosso.
O registro é pulado no `localhost`, senão cada edição em desenvolvimento
voltaria do cache. A rede sempre tem a primeira palavra, então deploy novo
nunca fica preso atrás de cache velho.

**O cache em disco do Firestore é ligado na mão, no `Bootstrap`.** Na web o
padrão do Firestore é guardar tudo **só em memória**: sem
`persistenceEnabled: true` o app abria sem rede e mostrava tela vazia, porque
a casca estava em cache e o dado não. Precisa vir antes da primeira consulta —
mudar `settings` depois disso lança. O `webPersistentTabManager` não é
enfeite: sem ele a segunda aba fica sem persistência.

**Offline não tem tela própria: tem uma faixa.** `SyncBanner` embrulha a
aplicação inteira no `builder` do `MaterialApp`, porque o estado é da sessão e
não da página. O Firestore não expõe "estou online?" — expõe, por snapshot, se
o dado veio do cache (`isFromCache`) e se há escrita na fila
(`hasPendingWrites`); `SyncStatusService` traduz isso. A carência de três
segundos antes de avisar "sem conexão" existe porque **o primeiro snapshot vem
do cache mesmo online**, e sem ela a faixa piscaria em toda abertura.

**A previsão do tempo some em silêncio, e isso é o comportamento certo.** O
`WeatherChip` do card não aparece quando a atividade não tem coordenada, quando
falta mais de uma semana para a viagem começar (ou ela já acabou —
`Weather.isWindowOpen`), quando o dia está além dos 16 dias que a Open-Meteo
cobre, ou quando a rede falhou. O chip é também o botão do painel do dia, que
— como todo formulário — abre por `showAppSheet`. Nenhum desses casos é erro: previsão é
conveniência, e `WeatherService` devolve mapa vazio em vez de lançar, como o
`GeocodingService`. A Open-Meteo é gratuita e **não pede chave** — não há nada
para configurar no build. O cache é por coordenada arredondada a duas casas
(~1 km), o que faz o roteiro inteiro de um destino virar um pedido só; é a
igualdade de `WeatherQuery` que dedupa a `FutureProvider.family`.

**A geocodificação é o Nominatim (OSM), não o Mapbox.** O plano gratuito do
Mapbox é o *temporary geocoding*, cujos termos não deixam guardar o resultado —
e o nome do lugar vai para o Firestore. Do Mapbox usamos só os tiles. O
Nominatim aceita no máximo uma requisição por segundo: o debounce de 600 ms em
`map_picker_sheet.dart` não é enfeite.

**`third_party/firebase_core_web` é uma cópia com patch de duas linhas**, ligada
por `dependency_overrides`, porque a versão publicada não compila no Dart 3.11.
Está excluída do analisador. Remover quando o FlutterFire publicar uma versão
compatível — instruções em `third_party/firebase_core_web/PATCH.md`.

## Convenções de UI

- Espaçamento e raio saem de `Gap` e `Radii` (`lib/core/theme/app_tokens.dart`),
  nunca números soltos. `Gap.vMd` é um `SizedBox` pronto.
- `lib/core/extensions/context_ext.dart` dá `context.text`, `context.colors`,
  `context.isMobile`, `context.reduceMotion` e as cores de papel abaixo.
- Cada cor tem um papel (`lib/core/theme/app_colors.dart`): `AppColors.night`
  é a tinta e o botão principal (`context.action`); o azul do céu
  (`colors.primary`) é o que se toca — link, foco, seleção, progresso;
  `context.sun` marca o agora (hoje, a próxima atividade, a aba aberta) e leva
  texto `night` por cima; `context.success` é pago; `context.debt` é o que se
  deve. Tudo chapado: degradê só como véu sobre imagem.
- Fira Sans em tudo. Número que se compara (dinheiro, hora, data curta) usa
  `AppTypography.money`/`numeric`, que ligam os algarismos tabulares. Nada de
  rótulo em caixa-alta.
- As quatro ilustrações de `assets/images/cover_*.jpg` aparecem **uma vez
  cada**, a pedido do dono do projeto: avião no login, mundo na lista de
  viagens, estrada no Resumo, praia na conta. Tela nova não reaproveita
  nenhuma — a de nova senha desenha o próprio horizonte.
- `AppDestination` (`lib/app/destinations.dart`) é a fonte única da navegação:
  alimenta a barra inferior, o rail e a sidebar de uma vez.
- O corte entre bottom sheet e diálogo é 700px (`Breakpoints.tablet`).
- Campo com borda contornada desenha o label flutuante **acima** da caixa: a
  área rolável de um formulário precisa de padding superior, ou o label é
  cortado.

## Credenciais

`lib/firebase_options.dart`, `android/app/google-services.json` e
`ios/Runner/GoogleService-Info.plist` estão no `.gitignore`. Gere os seus com
`flutterfire configure`, ou copie `lib/firebase_options.dart.example`.

O token do Mapbox entra por `--dart-define=MAPBOX_TOKEN=pk.xxx` e é lido em
`lib/core/config/map_config.dart`. Sem ele o app roda igual: o botão "Escolher
no mapa" fica desabilitado com a explicação. Ver o README.

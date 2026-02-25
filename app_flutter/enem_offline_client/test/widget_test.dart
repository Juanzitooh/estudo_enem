import 'package:enem_offline_client/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza tela inicial do cliente ENEM', (tester) async {
    await tester.pumpWidget(const EnemOfflineApp());
    await tester.pumpAndSettle();

    expect(find.text('ENEM Offline Client (MVP)'), findsOneWidget);
    expect(find.textContaining('Versão de conteúdo:'), findsOneWidget);
  });
}

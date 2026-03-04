import 'package:enem_offline_client/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza tela inicial do cliente ENEM', (tester) async {
    await tester.pumpWidget(const EnemOfflineApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Aulas'), findsOneWidget);
    expect(find.text('Questões'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });
}

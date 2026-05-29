import 'package:flutter_test/flutter_test.dart';
import 'package:vido_foody_kiosk/main.dart';

void main() {
  testWidgets('Vido Foody Kiosk app loads', (tester) async {
    await tester.pumpWidget(const VidoFoodyKioskApp());
    expect(find.text('Welcome to Vido Foody'), findsOneWidget);
  });
}

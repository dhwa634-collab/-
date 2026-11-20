import 'package:flutter_test/flutter_test.dart';
import 'package:third_intermediate_iraq/main.dart';
void main(){testWidgets('home screen loads', (tester) async {await tester.pumpWidget(const StudyApp());expect(find.text('دليلك للنجاح'),findsOneWidget);expect(find.text('الثالث متوسط • العراق'),findsOneWidget);});}

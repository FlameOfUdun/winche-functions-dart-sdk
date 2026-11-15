import 'package:winche_core/winche_core.dart';
import 'package:winche_functions/winche_functions.dart';

Future<void> main() async {
  Winche.initializeApp(options: WincheOptions.emulator());
  final result = await WincheFunctions.instance.call<Map<String, dynamic>>('hello', {'name': 'Ann'});
  print(result?['greeting']);
  await Winche.deinitializeAll();
}

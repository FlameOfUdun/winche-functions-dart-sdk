@Tags(['live'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:winche_core/winche_core.dart';
import 'package:winche_functions/winche_functions.dart';

/// Against `winche emulators start` with `winche functions init`'s example deployed:
/// `WINCHE_EMULATOR=localhost:9090 dart test --tags live`.
void main() {
  final target = Platform.environment['WINCHE_EMULATOR'];
  final skip = target == null ? 'set WINCHE_EMULATOR=host:port with `winche emulators start` running' : false;

  test('calls the example function on the emulator', () async {
    final hostPort = target!.split(':');
    final app = Winche.initializeApp(name: 'live', options: WincheOptions.emulator(host: hostPort[0], port: int.parse(hostPort[1])));
    final result = await WincheFunctions.instanceFor(app).call<Map<String, dynamic>>('hello', {'name': 'Ann'});
    expect(result!['greeting'], 'Hello Ann');
    await expectLater(WincheFunctions.instanceFor(app).call<Object>('hello', {}),
        throwsA(isA<WincheFunctionsException>().having((e) => e.code, 'code', WincheErrorCode.invalidArgument)));
    await Winche.deinitializeAll();
  }, skip: skip);
}

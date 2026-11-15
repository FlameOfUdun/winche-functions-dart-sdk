/// Call Winche functions from Dart and Flutter apps.
///
/// ```dart
/// final result = await WincheFunctions.instance.call<Map<String, dynamic>>('hello', {'name': 'Ann'});
/// print(result['greeting']);
///
/// // Or keep a handle:
/// final hello = WincheFunctions.instance.callable('hello');
/// await hello({'name': 'Ann'});
/// ```
///
/// Calls carry the signed-in user's token (from `winche_auth` or any other
/// `WincheAuthService`), so `ctx.auth` is set inside the function; signed out,
/// they go without one.
library;

export 'src/winche_functions.dart';

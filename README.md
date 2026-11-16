# winche_functions

Call [Winche](https://github.com/FlameOfUdun) functions from Dart and Flutter apps.

```dart
import 'package:winche_core/winche_core.dart';
import 'package:winche_functions/winche_functions.dart';

Winche.initializeApp(options: WincheOptions(baseUrl: Uri.parse('https://api.example.com')));

final result = await WincheFunctions.instance.call<Map<String, dynamic>>('hello', {'name': 'Ann'});
print(result?['greeting']);

try {
  await WincheFunctions.instance.callable('book').call<void>({'slot': '10:00'});
} on WincheFunctionsException catch (e) {
  // e.code: what the function threw with HttpsError (WincheErrorCode.notFound, .permissionDenied, …),
  // or .internal / .unavailable; e.details: what it sent with it
}
```

Calls go to `/functions/v1` under the server's address (or `WincheOptions.endpoints['functions']`), through the app's
shared `app.http`. They carry the signed-in user's token (from `winche_auth`, or any identity source), so the function's
`ctx.auth` is set; signed out, they go without one. A refused token is refreshed and the call tried once more; a call is
never retried otherwise, since a function may not be safe to run twice. `WincheFunctionsException` is a
`WincheException`: its `code` is from the list every Winche package shares, and `status` is the HTTP status when
there was an answer.

A call fails with `deadlineExceeded` after `WincheFunctions.instance.timeout`: 70 seconds by default, a little over a
function's own default timeout. Set it to change that.

Locally, `WincheOptions.emulator()` includes the emulator's functions (`winche emulators start` with a functions folder
from `winche functions init`).

## Installation

```bash
dart pub add winche_core winche_functions
```

Or add them to `pubspec.yaml`:

```yaml
dependencies:
  winche_core: ^1.0.0
  winche_functions: ^0.1.0
```

`winche_core` is not optional. It owns the app, the endpoints and the session every Winche package binds to, so an
app always imports it directly.

## Writing functions

On the server, with `@winche/functions`:

```ts
import { callable, HttpsError } from "@winche/functions";

export const hello = callable(async (data: { name?: string }, ctx) => {
  if (!data?.name) throw new HttpsError("invalid-argument", "Send a name.");
  return { greeting: `Hello ${data.name}`, by: ctx.auth?.uid ?? null };
});
```

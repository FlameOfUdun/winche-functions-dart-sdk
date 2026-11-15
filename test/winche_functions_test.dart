import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:winche_core/testing.dart';
import 'package:winche_core/winche_core.dart';
import 'package:winche_functions/winche_functions.dart';

void main() {
  late WincheApp app;
  final calls = <http.Request>[];
  var answers = <http.Response Function(http.Request)>[];

  WincheFunctions functions() {
    app.http.useClient(MockClient((r) async {
      calls.add(r);
      return answers.isEmpty ? http.Response('{"data":null}', 200) : answers.removeAt(0)(r);
    }));
    return WincheFunctions.instanceFor(app);
  }

  setUp(() {
    calls.clear();
    answers = [];
    app = Winche.initializeApp(name: 'functions-test', options: WincheOptions(baseUrl: Uri.parse('https://api.example.com')));
  });
  tearDown(() => Winche.deinitializeAll());

  test('calls a function and returns its data, signed out without a token', () async {
    answers = [(r) => http.Response(jsonEncode({'data': {'greeting': 'Hello Ann'}}), 200)];
    final f = functions();
    final result = await f.call<Map<String, dynamic>>('hello', {'name': 'Ann'});
    expect(result, {'greeting': 'Hello Ann'});
    expect(calls.single.url.toString(), 'https://api.example.com/functions/v1/call/hello');
    expect(jsonDecode(calls.single.body), {'data': {'name': 'Ann'}});
    expect(calls.single.headers['authorization'], isNull);
  });

  test("carries the signed-in user's token, refreshing it once when it's refused", () async {
    final auth = ScriptedAuthService(app);
    final f = functions();
    auth.announce(WincheIdentity('u1'));
    await Future<void>.delayed(Duration.zero);
    answers = [
      (r) => http.Response(jsonEncode({'error': {'code': 'unauthenticated', 'message': 'expired'}}), 401),
      (r) => http.Response(jsonEncode({'data': 42}), 200),
    ];
    expect(await f.callable('answer').call<int>(), 42);
    expect(calls.map((c) => c.headers['authorization']), ['Bearer token-u1-0', 'Bearer token-u1-0']);
  });

  test("errors carry the function's code and message", () async {
    answers = [(r) => http.Response(jsonEncode({'error': {'code': 'not-found', 'message': "There's no bob."}}), 404)];
    final f = functions();
    await expectLater(
      f.call<Object>('hello', {'name': 'bob'}),
      throwsA(isA<WincheFunctionsException>()
          .having((e) => e.code, 'code', WincheErrorCode.notFound)
          .having((e) => e.message, 'message', "There's no bob.")
          .having((e) => e.status, 'status', 404)),
    );
  });

  test('without a server address, says what to set', () async {
    final other = Winche.initializeApp(name: 'no-endpoint', options: const WincheOptions());
    expect(() => WincheFunctions.instanceFor(other).call<void>('x'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('baseUrl'))));
  });

  test('an override in endpoints wins over baseUrl', () async {
    final other = Winche.initializeApp(
        name: 'override',
        options: WincheOptions(baseUrl: Uri.parse('https://api.example.com'), endpoints: {'functions': Uri.parse('https://fn.example.com/v1')}));
    final seen = <Uri>[];
    other.http.useClient(MockClient((r) async {
      seen.add(r.url);
      return http.Response('{"data":1}', 200);
    }));
    await WincheFunctions.instanceFor(other).call<int>('x');
    expect(seen.single.toString(), 'https://fn.example.com/v1/call/x');
  });

  test('a call is never retried, even on a 503', () async {
    answers = [(r) => http.Response('', 503), (r) => http.Response('{"data":1}', 200)];
    await expectLater(functions().call<int>('x'),
        throwsA(isA<WincheFunctionsException>().having((e) => e.code, 'code', WincheErrorCode.unavailable).having((e) => e.status, 'status', 503)));
    expect(calls, hasLength(1));
  });

  test('a call that takes too long is deadline-exceeded', () async {
    app.http.useClient(MockClient((_) => Completer<http.Response>().future));
    final f = WincheFunctions.instanceFor(app)..timeout = const Duration(milliseconds: 20);
    await expectLater(f.call<int>('slow'), throwsA(isA<WincheFunctionsException>().having((e) => e.code, 'code', WincheErrorCode.deadlineExceeded)));
  });

  test("an HttpsError's code, message and details reach the caller", () async {
    answers = [
      (r) => http.Response('{"error":{"code":"failed-precondition","message":"Not yet.","details":{"retryAfter":3}}}', 400),
      (r) => http.Response('{"error":{"code":"invalid-argument","message":"No.","details":{"value":[1,2]}}}', 400),
    ];
    final f = functions();
    await expectLater(
        f.call<int>('x'),
        throwsA(isA<WincheFunctionsException>()
            .having((e) => e.code, 'code', WincheErrorCode.failedPrecondition)
            .having((e) => e.details, 'details', {'retryAfter': 3})
            .having((e) => e.isTransient, 'isTransient', false)));
    await expectLater(f.call<int>('x'), throwsA(isA<WincheException>().having((e) => (e as WincheFunctionsException).details, 'details', [1, 2])));
  });
}

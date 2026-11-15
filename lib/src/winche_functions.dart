import 'dart:async';

import 'package:winche_core/winche_core.dart';

/// A function failed. [code] is what the function threw with `HttpsError`
/// (`notFound`, `invalidArgument`, `permissionDenied`, …), or `internal` when it
/// failed otherwise; `unavailable` or `deadlineExceeded` when the server
/// couldn't be reached or didn't answer in time.
final class WincheFunctionsException extends WincheException {
  /// Creates an exception.
  const WincheFunctionsException(super.code, super.message, {this.details, this.status});

  /// What the function sent with its `HttpsError` (anything JSON can carry), or null.
  final Object? details;

  /// The HTTP status, when there was an answer.
  final int? status;

  factory WincheFunctionsException._from(WincheHttpException error) => WincheFunctionsException(
        error.code,
        error.message,
        // The server wraps a details value that isn't an object as {value: …}.
        details: error.details.isEmpty
            ? null
            : error.details.length == 1 && error.details.containsKey('value')
                ? error.details['value']
                : error.details,
        status: error.status,
      );
}

/// A handle on one callable function; calling it is the same as [WincheFunctions.call].
final class WincheCallable {
  final WincheFunctions _functions;

  /// The function's name (its export name).
  final String name;

  WincheCallable._(this._functions, this.name);

  /// Calls the function with [data] and returns what it returned.
  Future<T?> call<T>([Object? data]) => _functions.call<T>(name, data);
}

/// Calls the callable functions of a Winche server (`POST /functions/v1/call/{name}`).
///
/// Calls go through `app.http`, so they carry the signed-in user's token and a
/// refused token is refreshed once. They are never retried otherwise: a function
/// may not be safe to run twice.
final class WincheFunctions extends WincheService {
  /// Registers with [app]; use [instance] or [instanceFor] instead.
  WincheFunctions(super.app);

  /// The functions client of the default app.
  static WincheFunctions get instance => instanceFor(Winche.app);

  /// The functions client of [app].
  static WincheFunctions instanceFor(WincheApp app) => WincheService.instanceFor(app, () => WincheFunctions(app));

  /// The service's id in `WincheOptions.endpoints`.
  static const serviceId = 'functions';

  /// How long a call may take before it fails with `deadline-exceeded` (default
  /// 70 seconds: a little over a function's own default timeout).
  Duration timeout = const Duration(seconds: 70);

  /// A handle on the function [name].
  WincheCallable callable(String name) => WincheCallable._(this, name);

  /// Calls the function [name] with [data] (anything JSON can carry) and returns
  /// what it returned, decoded from JSON. Throws [WincheFunctionsException].
  Future<T?> call<T>(String name, [Object? data]) async {
    if (isDisposed) throw StateError('This WincheFunctions has been disposed.');
    final endpoint = (app.options ?? const WincheOptions()).endpointFor(serviceId, path: '/functions/v1');
    final url = endpoint.replace(path: '${endpoint.path.replaceAll(RegExp(r'/+$'), '')}/call/${Uri.encodeComponent(name)}');
    try {
      final response = await app.http.send(WincheRequest.post(url, json: {'data': data}, timeout: timeout, service: serviceId));
      final body = response.json;
      if (body is Map<String, dynamic>) return body['data'] as T?;
      throw WincheFunctionsException(WincheErrorCode.internal, 'The server answered without data.', status: response.status);
    } on WincheFunctionsException {
      rethrow;
    } on WincheHttpException catch (e) {
      throw WincheFunctionsException._from(e);
    } on FormatException {
      throw const WincheFunctionsException(WincheErrorCode.internal, "The server's answer wasn't JSON.");
    }
  }
}

# CHANGELOG

## 0.1.0

* **`WincheFunctions.call(name, data)`** and **`callable(name)`**: call a Winche server's callable functions as the
  signed-in user, with the token refreshed once if it's refused.
* **`WincheFunctionsException`**: a `WincheException` with the function's code (the shared `WincheErrorCode`), message,
  `details` (what its `HttpsError` sent) and the HTTP status.
* On `winche_core` 1.0: the endpoint is `/functions/v1` under `WincheOptions.baseUrl` (or `endpoints['functions']`), and
  calls go through `app.http`. Calls are never retried apart from the one refresh of a refused token.

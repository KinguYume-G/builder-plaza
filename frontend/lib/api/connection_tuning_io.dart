import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Keeps Dio from reusing a keep-alive socket the server has already closed.
///
/// `HttpClient` pools idle connections for [HttpClient.idleTimeout], which
/// defaults to 15s. Uvicorn drops an idle keep-alive connection after 5s. In
/// that 10-second window the pool still holds a socket the server is done with,
/// so the next request is written into a dead connection, gets no reply, and
/// fails with a `receiveTimeout` — with nothing at all in the server log.
///
/// This is not theoretical: it cost us a silent 10s hang on the first screenshot
/// upload after the photo picker had been open for a minute. Dropping our idle
/// timeout below the server's closes the window.
void tuneConnectionReuse(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()..idleTimeout = const Duration(seconds: 3),
  );
}

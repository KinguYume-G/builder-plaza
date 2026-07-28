import 'package:dio/dio.dart';

/// Web build: the browser owns the connection pool, so there is nothing for us
/// to tune. See `connection_tuning_io.dart` for the mobile/desktop version and
/// why it exists.
void tuneConnectionReuse(Dio dio) {}

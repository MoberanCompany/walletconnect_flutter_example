
import 'package:logger/logger.dart';

Logger? _logger;
Logger get logger{
  _logger ??= Logger(
      printer: PrettyPrinter(
        methodCount: 5,
        errorMethodCount: 10,
      )
  );
  return _logger!;
}

get debugLog => logger.d;
get infoLog => logger.i;
get errorLog => logger.e;
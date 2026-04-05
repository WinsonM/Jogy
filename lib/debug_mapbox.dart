import 'dart:io';

void logDebug(String msg) {
  File('debug_mapbox.log').writeAsStringSync('${DateTime.now()}: $msg\n', mode: FileMode.append);
}

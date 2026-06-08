import 'dart:io';

import 'release_manager/cli.dart';

void main(List<String> args) {
  exitCode = ReleaseCli.run(args);
}

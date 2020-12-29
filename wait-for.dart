import 'dart:io';
import 'dart:async';

import 'package:args/args.dart';

ProcessResult shell(String command) {
  return Process.runSync('bash', ['-c', command]);
}

void main(List<String> args) async {
  var parser = new ArgParser();
  parser.addOption('command',
      abbr: "c", help: 'read the content from the command.');
  parser.addMultiOption('ok',
      abbr: "o", help: 'ok if the patter appear.', valueHelp: '<pattern>');
  parser.addMultiOption('fail',
      abbr: "f", help: 'faield if the pattern appear.', valueHelp: '<pattern>');
  parser.addMultiOption('ok-no',
      help: 'ok if the pattern is gone.', valueHelp: '<pattern>');
  parser.addMultiOption('ok-script',
      help: 'ok if the script run without error.', valueHelp: 'script');
  parser.addMultiOption('fail-no',
      help: 'failed if the script run without error.', valueHelp: 'script');
  parser.addMultiOption('fail-script',
      help: 'failed if the pattern is gone', valueHelp: 'script');
  parser.addOption('timeout', abbr: 't', help: '', defaultsTo: "0");
  parser.addOption('interval', abbr: 'i', help: '', defaultsTo: "5");
  parser.addFlag('not', abbr: "n", defaultsTo: false);

  parser.addFlag('help', abbr: "h");
  var results = parser.parse(args);
  if (results['help']) {
    print(parser.usage);
    return;
  }

  final command = results['command'];
  final okString = results['ok'];
  final failString = results['fail'];
  final okScriptString = results['ok-script'];
  final failScriptString = results['fail-script'];
  final okNoString = results['ok-no'];
  final failNoString = results['fail-no'];
  final interval = int.tryParse(results['interval']) ?? 5;
  final timeout = int.tryParse(results['timeout']) ?? 0;
  final dir = Directory.systemTemp.createTempSync();
  final tempFile = File("${dir.path}/wait-for");
  tempFile.createSync();

  var ok = false;
  var loop = true;

  if (timeout > 0) {
    Timer(Duration(seconds: timeout), () {
      dir.deleteSync(recursive: true);
      if (results['not']) {
        exit(0);
      }
      exit(2);
    });
  }

  while (loop) {
    var processResult = shell(command);
    if (processResult.exitCode != 0) {
      ok |= false;
      break;
    }
    var stdout = processResult.stdout as String;
    print(stdout);
    for (var i in okString) {
      if (stdout.contains(i)) {
        ok |= true;
        loop = false;
        break;
      }
    }
    for (var i in failString) {
      if (stdout.contains(i)) {
        loop = false;
        ok |= false;
      }
    }
    for (var i in okNoString) {
      if (!stdout.contains(i)) {
        loop = false;
        ok |= true;
      }
    }
    for (var i in failNoString) {
      if (!stdout.contains(i)) {
        loop = false;
        ok |= false;
      }
    }
    tempFile.writeAsStringSync(stdout);
    for (var i in okScriptString) {
      if (runScript(i, tempFile.absolute.path) == 0) {
        loop = false;
        ok |= true;
      }
    }
    for (var i in failScriptString) {
      if (runScript(i, tempFile.absolute.path) == 0) {
        loop = false;
        ok |= false;
      }
    }
    if (loop) {
      await Future.delayed(Duration(seconds: interval));
    }
  }
  dir.deleteSync(recursive: true);

  if (results['not']) {
    ok = !ok;
  }
  if (ok) {
    exit(0);
  }
  exit(1);
}

int runScript(String command, String filePath) {
  final v = {'stdout': filePath};
  var result = Process.runSync('bash', ['-c', command], environment: v);
  return result.exitCode;
}

import 'dart:io';

import 'package:i18n_cleaner/i18n_cleaner.dart';
import 'package:yaml/yaml.dart';

void validate(bool condition, String message) {
  if (!condition) {
    throw message;
  }
}

String getI18nPath() {
  final pubspecFile = File('pubspec.yaml');

  validate(pubspecFile.existsSync(), 'could not find pubspec file');

  final YamlMap pubspec = loadYaml(pubspecFile.readAsStringSync());
  String cleanerPath = pubspec['i18-cleaner-path'];

  cleanerPath ??= 'resources/i18n';

  validate(Directory(cleanerPath).existsSync(),
      'Directory $cleanerPath does not exist.');

  return cleanerPath;
}

void mainThrowing() {
  final i18nPath = getI18nPath();

  cleanLocalizations(i18nPath);
}

void main(List<String> arguments) {
  try {
    mainThrowing();
  } catch (e) {
    print('ERROR: $e');
    exit(-1);
  }
}

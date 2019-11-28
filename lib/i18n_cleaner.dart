import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as paths;

const writeCsv = false;
const translatePrefix = '[TRANSLATE]';

class Localizations {
  final Directory directory;
  final List<OneLanguageLocalizations> content;
  final Set<String> allKeys;

  Localizations(this.content, this.allKeys, this.directory);

  static Future<Localizations> load(String path) async {
    final directory = Directory(path);
    final files = await directory.list().toList();
    final all = <String, OneLanguageLocalizations>{};

    final keys = Set<String>();

    for (var file in files) {
      if (paths.extension(file.path) != '.json') {
        continue;
      }

      final obj = await OneLanguageLocalizations.load(file.path);
      all[obj.language] = obj;
      keys.addAll(obj.content.keys);
    }

    return Localizations(all.values.toList(), keys, directory);
  }

  OneLanguageLocalizations getValues(String language) {
    return content.firstWhere((x) => x.language == language);
  }

  void insertNulls() {
    final english = getValues('en');
    final german = getValues('de');

    for (var lang in content) {
      final values = lang.content;
      for (var key in allKeys) {
        if (!isValidValue(values[key])) {
          final value =
              english.getTranslatedValue(key) ?? german.getTranslatedValue(key);

          if (value != null) {
            values[key] = '$translatePrefix $value';
          } else {
            final fallback = english.content[key] ?? german.content[key];
            assert(fallback != null);
            values[key] = fallback;
          }
        }
      }
    }
  }

  bool isValidValue(String value) {
    return value != null && !value.contains(translatePrefix);
  }

  void printAllMissing() {
    final keys = allKeys.toList()..sort();

    for (var lang in content) {
      final flat = lang.content;
      for (var key in keys) {
        if (!isValidValue(flat[key])) {
          print('Missing ${lang.language}/$key');
        }
      }
      print('');
    }
  }

  void saveSpreadsheet() {
    List<List<String>> rows = [];
    final languages = content.toList();

    void bringToFront(String code) {
      final englishIndex = languages.indexWhere((x) => x.language == code);
      final english = languages.removeAt(englishIndex);
      languages.insert(0, english);
    }

    bringToFront('de');
    bringToFront('en');

    {
      final row = <String>[];
      row.add('Key');
      for (var language in languages) {
        row.add(language.language);
      }
      rows.add(row);
    }

    for (var key in allKeys.toList()..sort()) {
      final row = <String>[];
      row.add(key);

      for (var language in languages) {
        row.add(language.content[key]);
      }

      rows.add(row);
    }

    final string = ListToCsvConverter(fieldDelimiter: '\t').convert(rows);
    final file = File(directory.path + '/content.csv');
    file.writeAsStringSync(string);
  }
}

class OneLanguageLocalizations {
  final File file;
  final String language;
  final Map<String, String> content;

  static Future<OneLanguageLocalizations> load(String path) async {
    final fileObject = File(path);

    final language = paths.basenameWithoutExtension(path);

    final jsonString = fileObject.readAsStringSync();
    final jsonObject = json.decode(jsonString);

    return OneLanguageLocalizations(_flatten(jsonObject), language, fileObject);
  }

  String getTranslatedValue(String key) {
    String r = content[key];
    if (r?.startsWith(translatePrefix) == true) {
      return null;
    } else {
      return r;
    }
  }

  void saveFlat() {
    final encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(SplayTreeMap.from(content));
    file.writeAsStringSync(jsonString);
  }

  static Map<String, String> _flatten(Map data) {
    final sentences = <String, String>{};

    void setValues(dynamic json, [String parentKey = '']) {
      json.forEach((String key, dynamic value) {
        if (parentKey.isNotEmpty) {
          key = '$parentKey.$key';
        }

        if (value is String) {
          sentences[key] = value.toString();
        }

        // recursive
        if (value is Map) {
          setValues(value, key);
        }
      });
    }

    setValues(data);

    return sentences;
  }

  OneLanguageLocalizations(this.content, this.language, this.file);
}

Future<void> cleanLocalizations(String path) async {
  final localizations = await Localizations.load(path);

  localizations.insertNulls();
  localizations.printAllMissing();

  for (var x in localizations.content) {
    x.saveFlat();
  }

  if (writeCsv) {
    localizations.saveSpreadsheet();
  }
}

class LocalizationsTable {
  final String name;
  final Map<String, Map<String, dynamic>> languageToKeys;

  Iterable<String> get languages => languageToKeys.keys;

  LocalizationsTable(this.name, this.languageToKeys)
      : keys = _getKeys(languageToKeys);

  static List<String> _getKeys(Map<String, Map<String, String>> map) {
    final english = map['en'];
    if (english == null) {
      return [];
    }

    final result = english.keys.toList()..sort(compareAsciiLowerCase);
    return result;
  }

  final List<String> keys;
}

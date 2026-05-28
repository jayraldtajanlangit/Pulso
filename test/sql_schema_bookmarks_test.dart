import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema includes bookmarks table and RLS policies', () {
    final schema = File('lib/database/sql_schema.dart').readAsStringSync();

    expect(schema, contains('CREATE TABLE IF NOT EXISTS bookmarks'));
    expect(schema, contains('ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY'));
    expect(schema, contains('bookmarks_select_own'));
    expect(schema, contains('bookmarks_insert_own'));
    expect(schema, contains('bookmarks_delete_own'));
  });
}

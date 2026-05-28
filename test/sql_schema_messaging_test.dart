import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('messaging RLS lets participants read conversation members safely', () {
    final schema = File('lib/database/sql_schema.dart').readAsStringSync();

    expect(schema, contains('CREATE SCHEMA IF NOT EXISTS private'));
    expect(schema, contains('private.is_conversation_participant'));
    expect(schema, contains('participants_select_conversation_members'));
    expect(schema, isNot(contains('CREATE POLICY "participants_select_own"')));
  });
}

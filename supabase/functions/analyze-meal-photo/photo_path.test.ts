import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { PHOTO_PATH_PATTERN } from './index.ts';

Deno.test('PHOTO_PATH_PATTERN matches a well-formed {uuid}/{uuid}.jpg path', () => {
  const path = '550e8400-e29b-41d4-a716-446655440000/660e8400-e29b-41d4-a716-446655440111.jpg';
  assertEquals(PHOTO_PATH_PATTERN.test(path), true);
});

Deno.test('PHOTO_PATH_PATTERN rejects a path-traversal dot-segment attack', () => {
  const path =
    '550e8400-e29b-41d4-a716-446655440000/../660e8400-e29b-41d4-a716-446655440111/770e8400-e29b-41d4-a716-446655440222.jpg';
  assertEquals(PHOTO_PATH_PATTERN.test(path), false);
});

Deno.test('PHOTO_PATH_PATTERN rejects a path with extra segments', () => {
  const path =
    '550e8400-e29b-41d4-a716-446655440000/660e8400-e29b-41d4-a716-446655440111/extra.jpg';
  assertEquals(PHOTO_PATH_PATTERN.test(path), false);
});

Deno.test('PHOTO_PATH_PATTERN rejects a non-UUID first segment', () => {
  const path = 'not-a-uuid/660e8400-e29b-41d4-a716-446655440111.jpg';
  assertEquals(PHOTO_PATH_PATTERN.test(path), false);
});

Deno.test('PHOTO_PATH_PATTERN rejects a well-formed path with a non-.jpg extension', () => {
  const path = '550e8400-e29b-41d4-a716-446655440000/660e8400-e29b-41d4-a716-446655440111.png';
  assertEquals(PHOTO_PATH_PATTERN.test(path), false);
});

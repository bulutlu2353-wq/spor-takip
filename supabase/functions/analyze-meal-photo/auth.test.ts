import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { getUserIdFromAuthHeader } from './index.ts';

function fakeJwt(payload: Record<string, unknown>): string {
  const base64url = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${base64url({ alg: 'HS256', typ: 'JWT' })}.${base64url(payload)}.fake-signature`;
}

Deno.test('getUserIdFromAuthHeader extracts sub from a valid-shaped bearer token', () => {
  const req = new Request('http://localhost', {
    headers: { Authorization: `Bearer ${fakeJwt({ sub: 'user-123' })}` },
  });
  assertEquals(getUserIdFromAuthHeader(req), 'user-123');
});

Deno.test('getUserIdFromAuthHeader returns null when the Authorization header is missing', () => {
  const req = new Request('http://localhost');
  assertEquals(getUserIdFromAuthHeader(req), null);
});

Deno.test('getUserIdFromAuthHeader returns null for a malformed token', () => {
  const req = new Request('http://localhost', {
    headers: { Authorization: 'Bearer not-a-jwt' },
  });
  assertEquals(getUserIdFromAuthHeader(req), null);
});

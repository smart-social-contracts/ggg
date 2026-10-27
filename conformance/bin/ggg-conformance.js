#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { Ed25519KeyIdentity } from '@icp-sdk/core/identity';
import { Secp256k1KeyIdentity } from '@icp-sdk/core/identity/secp256k1';
import { runSuite } from '../src/suite.js';

const USAGE = `Usage: ggg-conformance --canister <id> [options]

  --network <ic|local|url>   where the canister runs (default: ic)
  --writes                   also run update checks; with --member-pem this files a proposal and votes
  --member-pem <file>        a member's Ed25519 or secp256k1 PEM key, for the member checks
  --json                     print the results as JSON
`;

function identityFromPem(path) {
  const pem = readFileSync(path, 'utf8');
  if (pem.includes('EC PRIVATE KEY')) return Secp256k1KeyIdentity.fromPem(pem);
  const der = Buffer.from(pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, ''), 'base64');
  // PKCS#8 Ed25519 (OID 1.3.101.112 at bytes 9-11): the 32-byte seed starts at byte 16.
  const ed25519 = der.length >= 48 && der[9] === 0x2b && der[10] === 0x65 && der[11] === 0x70;
  if (!ed25519) throw new Error(`${path} is not an Ed25519 or secp256k1 PEM key`);
  return Ed25519KeyIdentity.fromSecretKey(der.subarray(16, 48));
}

const { values } = parseArgs({
  options: {
    canister: { type: 'string' },
    network: { type: 'string', default: 'ic' },
    writes: { type: 'boolean', default: false },
    'member-pem': { type: 'string' },
    json: { type: 'boolean', default: false },
    help: { type: 'boolean', default: false },
  },
});

if (values.help || !values.canister) {
  process.stdout.write(USAGE);
  process.exit(values.help ? 0 : 2);
}

const host = { ic: 'https://icp-api.io', local: 'http://127.0.0.1:4943' }[values.network] ?? values.network;
const mainnet = /^https:\/\/([a-z0-9-]+\.)*(icp-api\.io|icp0\.io|ic0\.app)\/?$/.test(host);
const member = values['member-pem'] ? identityFromPem(values['member-pem']) : null;

const MARK = { pass: 'PASS', fail: 'FAIL', warn: 'WARN', skip: 'SKIP' };
const results = await runSuite({
  host,
  canisterId: values.canister,
  fetchRootKey: !mainnet,
  member,
  writes: values.writes,
  onResult: values.json
    ? undefined
    : (r) => console.log(`${MARK[r.outcome]} ${r.standard} ${r.id} ${r.title}${r.detail ? `: ${r.detail}` : ''}`),
});

const count = (o) => results.filter((r) => r.outcome === o).length;
if (values.json) {
  console.log(JSON.stringify({ canister: values.canister, host, results }, null, 2));
} else {
  console.log(`\n${count('pass')} passed, ${count('fail')} failed, ${count('warn')} warnings, ${count('skip')} skipped`);
}
process.exit(count('fail') ? 1 : 0);

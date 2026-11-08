// Generates facts.json, the fact schema, from ggg.did: for every operation, the facts a codex's rules
// see (its arguments, as the model defines them), with the kind, range and allowed values of each
// (docs/layered-codex.md §3.3). Run with no arguments to rewrite ../facts.json; test/facts.test.js
// checks that the committed file is what this script generates.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DID = new URL('../../ggg.did', import.meta.url);
const OUT = new URL('../../facts.json', import.meta.url);

// Every ratio is in hundred-millionths: 100 % is 100 000 000.
const WHOLE = 100_000_000;

// The kinds the fact schema adds to Candid's types, each declared by named aliases of ggg.did, with the
// range of each alias. A fact's unit comes from here, never from a suffix in its name.
export const KINDS = {
  ratio: {
    aliases: { Ratio: { min: 0, max: WHOLE } },
    unit: 'hundred-millionths',
    rule: 'One scale for every ratio: 100 % is 100 000 000, 1 % is 1 000 000 and 0.123456 % is 123 456. People read and write decimals; the value is the integer.',
  },
  money: {
    aliases: { Money: { min: 0 }, SignedMoney: {} },
    unit: "the token's smallest unit (Token.decimals)",
    rule: 'Money computed from a ratio is rounded to the nearest cent, an exact half away from zero. For a token with more than two decimals the result is a multiple of 10^(decimals - 2) smallest units. Money is never negative; SignedMoney may be, for a discount or bonus line.',
  },
  timestamp: { aliases: { Timestamp: { min: 0 } }, unit: 'nanoseconds since 1970-01-01 UTC' },
  duration: { aliases: { Duration: { min: 0 } }, unit: 'nanoseconds' },
  period: {
    aliases: { Period: {} },
    unit: 'a count of one calendar unit: Day, WorkingDay, Month or Year',
    rule: 'Periods compare only within one unit; comparing two units fails closed, with no conversion through the calendar.',
  },
};
const ALIAS_KIND = Object.fromEntries(
  Object.entries(KINDS).flatMap(([kind, { aliases }]) => Object.keys(aliases).map((alias) => [alias, kind])),
);

// Facts that are not arguments. A GOS computes each from its own records when the operation is called,
// deterministically, and legislation reads it like an argument (docs/layered-codex.md §1).
const DERIVED = {
  tender_award: {
    published_in: { type: { vec: { name: 'text' } }, derived: "the journals of the tender's notices" },
  },
  budget_propose: {
    revenue: { type: { name: 'Money' }, derived: "the sum of the period's revenue lines" },
    expense: { type: { name: 'Money' }, derived: "the sum of the period's expense lines" },
  },
};

// Lists an operation's rules may range over although the operation's argument is only an id: the list
// of the saved record that the id names. Every list of records among the arguments gets a per-list
// action as well, without being named here.
const SAVED_LISTS = {
  tax_policy_propose: { taxes: { record: 'TaxEntry', of: 'the saved policy the id names' } },
};

// The name of the one fact of an operation whose argument is a scalar, where it is not an id.
const SCALAR_NAMES = {
  user_get: 'user',
  private_data_update: 'data',
  crypto_derive_key: 'transport_key',
  crypto_envelope: 'scope',
};

const PRIMITIVE_RANGES = {
  nat: { min: 0 },
  nat8: { min: 0, max: 255 },
  nat32: { min: 0, max: 4_294_967_295 },
  nat64: { min: 0, max: '18446744073709551615' },
};

// ---- A small parser for the Candid of ggg.did: type definitions and the service.

function tokenize(source) {
  const tokens = [];
  const pattern = /\/\/[^\n]*|"[^"]*"|->|[A-Za-z_][A-Za-z0-9_]*|[{}();:=,]/g;
  for (const match of source.matchAll(pattern)) {
    const token = match[0];
    if (!token.startsWith('//')) tokens.push(token);
  }
  return tokens;
}

class Parser {
  constructor(tokens) {
    this.tokens = tokens;
    this.at = 0;
  }
  peek() {
    return this.tokens[this.at];
  }
  next() {
    return this.tokens[this.at++];
  }
  expect(token) {
    const found = this.next();
    if (found !== token) throw new Error(`expected "${token}" but found "${found}" at token ${this.at - 1}`);
  }
  /** A type expression. */
  type() {
    const token = this.next();
    if (token === 'opt') return { opt: this.type() };
    if (token === 'vec') return { vec: this.type() };
    if (token === 'record') return { record: this.fields(false) };
    if (token === 'variant') return { variant: this.fields(true) };
    return { name: token.replace(/^"|"$/g, '') };
  }
  /** `{ name : type; ... }`. Variant tags may have no type, record fields may have no name (a tuple). */
  fields(variant) {
    this.expect('{');
    const fields = [];
    let position = 0;
    while (this.peek() !== '}') {
      const first = this.next();
      if (this.peek() === ':') {
        this.next();
        fields.push({ name: first.replace(/^"|"$/g, ''), type: this.type() });
      } else {
        this.at -= 1;
        fields.push(variant ? { name: first, type: null } : { name: `_${position}`, type: this.type() });
        if (variant) this.next();
      }
      position += 1;
      if (this.peek() === ';') this.next();
    }
    this.expect('}');
    return fields;
  }
  /** `( type, type )`. */
  args() {
    this.expect('(');
    const types = [];
    while (this.peek() !== ')') {
      types.push(this.type());
      if (this.peek() === ',') this.next();
    }
    this.expect(')');
    return types;
  }
  /** The whole file: `type X = ...;` definitions, then `service : { ... };`. */
  file() {
    const types = new Map();
    const methods = [];
    while (this.at < this.tokens.length) {
      const token = this.next();
      if (token === 'type') {
        const name = this.next();
        this.expect('=');
        types.set(name, this.type());
        this.expect(';');
      } else if (token === 'service') {
        this.expect(':');
        this.expect('{');
        while (this.peek() !== '}') {
          const name = this.next();
          this.expect(':');
          const args = this.args();
          this.expect('->');
          this.args();
          const query = this.peek() === 'query';
          if (query) this.next();
          this.expect(';');
          methods.push({ name, args, query });
        }
        this.expect('}');
        this.expect(';');
      } else {
        throw new Error(`unexpected "${token}" at token ${this.at - 1}`);
      }
    }
    return { types, methods };
  }
}

export function parseDid(source) {
  return new Parser(tokenize(source)).file();
}

// ---- From Candid types to fact descriptions.

function describer(types) {
  /** Describes one type: its Candid form, and the kind, range and allowed values the schema adds. */
  function describe(type) {
    if (type.opt) return { ...describe(type.opt), optional: true };
    if (type.vec) return { type: 'vec', element: describe(type.vec) };
    if (type.record) return { type: 'record', fields: fieldsOf(type.record) };
    if (type.variant) return variantOf(type.variant);
    const { name } = type;
    if (name === 'Value') return { type: 'Value' };
    if (ALIAS_KIND[name]) {
      const kind = ALIAS_KIND[name];
      const { min, max } = KINDS[kind].aliases[name];
      const base = types.get(name);
      const described = base.record ? { type: name, kind, fields: fieldsOf(base.record) } : { type: base.name, kind };
      if (min !== undefined) described.min = min;
      if (max !== undefined) described.max = max;
      return described;
    }
    if (PRIMITIVE_RANGES[name]) return { type: name, ...PRIMITIVE_RANGES[name] };
    const defined = types.get(name);
    if (!defined) return { type: name };
    if (defined.record) return { type: name, fields: fieldsOf(defined.record) };
    if (defined.variant) return { ...variantOf(defined.variant), type: name };
    return { ...describe(defined), type: name };
  }
  function fieldsOf(fields) {
    return Object.fromEntries(fields.map(({ name, type }) => [name, describe(type)]));
  }
  function variantOf(fields) {
    const described = { type: 'variant', values: fields.map((f) => f.name) };
    const cases = fields.filter((f) => f.type);
    if (cases.length) described.cases = Object.fromEntries(cases.map(({ name, type }) => [name, describe(type)]));
    return described;
  }
  return describe;
}

/** The named-record lists among an operation's facts: each gets a per-list action. */
function recordLists(types, fields) {
  const lists = {};
  for (const { name, type } of fields) {
    const inner = type.opt ? type.opt : type;
    const element = inner.vec && types.get(inner.vec.name);
    if (element?.record && element.record.every((f) => !f.name.startsWith('_'))) {
      lists[name] = { record: inner.vec.name, of: 'the argument' };
    }
  }
  return lists;
}

export function generate(source = readFileSync(DID, 'utf8')) {
  const { types, methods } = parseDid(source);
  const describe = describer(types);
  const kinds = Object.fromEntries(
    Object.entries(KINDS).map(([kind, { aliases, ...rest }]) => [
      kind,
      { aliases: Object.keys(aliases), candid: Object.keys(aliases).map((alias) => candidOf(types.get(alias))), ...rest },
    ]),
  );
  const actions = {};
  for (const { name, args, query } of methods) {
    if (!name.startsWith('ggg_')) continue;
    const operation = name.slice('ggg_'.length);
    const action = { operation: name, facts: {} };
    if (query) action.read = true;
    let argFields = [];
    if (args.length === 1) {
      const arg = args[0];
      const defined = arg.name && types.get(arg.name);
      if (defined?.record) {
        argFields = defined.record;
        action.facts = describe(arg).fields;
      } else {
        action.facts = { [SCALAR_NAMES[operation] ?? 'id']: describe(arg) };
      }
    } else if (args.length > 1) {
      throw new Error(`${name} takes ${args.length} arguments; the schema expects one record`);
    }
    for (const [fact, { type, derived }] of Object.entries(DERIVED[operation] ?? {})) {
      action.facts[fact] = { ...describe(type), derived };
    }
    const lists = { ...recordLists(types, argFields), ...(SAVED_LISTS[operation] ?? {}) };
    if (Object.keys(lists).length) action.lists = Object.fromEntries(Object.keys(lists).map((list) => [list, `${operation}.${list}`]));
    actions[operation] = action;
    for (const [list, { record, of }] of Object.entries(lists)) {
      if (!types.get(record)?.record) throw new Error(`${operation}.${list}: ggg.did has no record ${record}`);
      actions[`${operation}.${list}`] = {
        operation: name,
        list: { field: list, of, element: record },
        facts: describe({ name: record }).fields,
      };
    }
  }
  return { kinds, actions };
}

function candidOf(type) {
  if (type.name) return type.name;
  if (type.record) return `record { ${type.record.map((f) => `${f.name} : ${candidOf(f.type)}`).join('; ')} }`;
  throw new Error('a kind alias is a primitive or a record');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  writeFileSync(OUT, `${JSON.stringify(generate(), null, 2)}\n`);
  console.log(`wrote ${fileURLToPath(OUT)}`);
}

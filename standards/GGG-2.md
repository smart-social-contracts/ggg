# GGG-2: Operations by name

| | |
|---|---|
| Status | Draft |
| Interface | [GGG-2.did](GGG-2.did) |
| Model | [§1 Operations](../model/README.md#operations), and every operation table in the model |
| Requires | [GGG-1](GGG-1.md) |

## Summary

The model defines about two hundred operations. The typed standards bind them domain by domain,
and most domains don't have one yet. Some operations will never have one: those a codex or an
extension brings, and those an implementation adds for itself.

GGG-2 is one typed entry point for all of them:

- a GOS lists the operations it offers, with the model's permission and flags;
- callers run an operation by its model name, passing its arguments as an ICRC-3 `Value`.

GGG-2 is optional, but a GOS that implements any model operation outside the typed standards
SHOULD implement it, so callers can reach that operation.

GGG-2 does not replace the typed standards. When a standard the GOS declares binds an operation,
the GOS MUST offer the typed method too, and callers SHOULD use it.

## Operations

```candid
type Operation = record {
  name : text;
  description : text;
  permission : opt text;
  read : bool;
  delegable : bool;
  governed : bool;
  signing : bool;
  provided_by : text;
  args_schema : opt text;
  result_schema : opt text;
};
```

- `name` is the model's name for a model operation, such as `transfer_create`. Other operations use
  lower-case letters, digits, `_` and `.`, at most 64 bytes, and SHOULD be prefixed with their
  source and a dot (`land_registry.parcel_get`) so that they can't clash with the model.
- `description` is one or two sentences for people.
- `permission` is the model's permission key, or the implementation's own key for its own operations.
  It is informational: the GOS checks on every call.
- `read`, `delegable`, `governed` and `signing` are the model's [flags](../model/README.md#operations).
  For a model operation they MUST match the model.
- `provided_by` is `ggg` for a model operation, `codex:<id>` or `extension:<id>` for one a codex or
  extension brings, and the implementation's name (`realms-gos`) for its own.
- `args_schema` and `result_schema` are [JSON Schema](https://json-schema.org/) documents for the
  arguments and the result, in the JSON form of `Value` below. They are null when the GOS doesn't
  describe them.

### The JSON form of `Value`

| `Value` | JSON |
|---|---|
| `Nat`, `Int` | integer |
| `Text` | string |
| `Blob` | string, base64, with `"contentEncoding": "base64"` |
| `Array` | array |
| `Map` | object. Keys are unique. |

A boolean is `Nat` 0 or 1, written in a schema as `{"type": "integer", "enum": [0, 1]}`. An absent
value is a missing key. A time is a `Nat` of nanoseconds, a principal is `Text`, and a status is the
model's lower-case name as `Text`.

## Methods

### `ggg2_operation`, `ggg2_operations`

```candid
ggg2_operation : (text) -> (OperationResult) query;
ggg2_operations : (ListArgs) -> (OperationsResult) query;
```

`ggg2_operation` describes one operation by name, or returns `Ok(null)` if there is none.
`ggg2_operations` lists every operation the GOS offers, in pages, whether or not the caller may run
it. Names are unique. The list changes only when the realm's code changes, for example when an
extension is installed.

### `ggg2_query`, `ggg2_call`

```candid
ggg2_query : (OperationArgs) -> (RunResult) query;
ggg2_call : (OperationArgs) -> (RunResult);
```

Runs operation `op` with `args` and returns its result. Arguments are a `Map`, empty for an
operation without any.

- An unknown `op` returns `Unsupported`.
- `ggg2_query` runs only `read` operations; any other returns `InvalidArgument`.
- `on_behalf_of` runs a `delegable` operation for a grantor; on any other it returns
  `InvalidArgument`.
- Arguments that don't fit `args_schema` return `InvalidArgument`. The GOS MUST validate them
  however the call arrives: a schema describes, it does not protect.
- A `governed` operation whose policy isn't direct files a proposal instead of running, as the model
  says, and returns the proposal's id in the result.
- The operation's checks and refusals are the model's, expressed as `GggError`s.

## How Realms GOS maps to GGG-2

This section is informative.

Realms GOS today has two methods, `read(name, args)` and `run(name, args)`, which take and return
JSON text. They map directly:

| GGG-2 | Realms GOS |
|---|---|
| `ggg2_operations` | `ops_list`, which lists every operation with its permission and flags |
| `ggg2_query` | `read(name, json)` |
| `ggg2_call` | `run(name, json)`, with `on_behalf_of` in the arguments |
| errors | `{"ok": false, "error": …}`, which becomes a `GggError` |

The change for Realms GOS is to decode `Value` instead of parsing JSON, to convert times and
statuses at the boundary, and to return typed errors. The dispatcher and its Cedar checks stay the
same.

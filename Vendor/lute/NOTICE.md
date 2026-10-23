# lute (vendored)

- Upstream: https://github.com/luau-lang/lute
- Commit: `b39453fde4fea7464fe08293b88d31f620ff3b16` (head of the default branch `primary`, committed 2026-10-21), fetched 2026-10-22 from raw.githubusercontent.com
- License: MIT, Copyright (c) 2024-2025 Roblox Corporation; `LICENSE` is upstream's, unchanged

| File here | Upstream path |
| --- | --- |
| `json.luau` | `lute/std/libs/json.luau` |
| `LICENSE` | `LICENSE` |

The plugin requires it as `Vendor.lute.json`. The file requires no other module, so no helper was inlined.

## Removed: `toml.luau`

`batteries/toml.luau` was vendored here on 2026-10-22 and removed on 2026-10-23, when `decodeToml` moved to eryx's TOML decoder (`vendor/eryx/toml`, measured closer to Rojo 7.7.1; see `vendor/eryx/NOTICE.md`). Its one change had been rewriting four `if local <name> = <expr> then` conditions, which Studio's Luau does not parse, as a `local` followed by `if <name> then`.

## Changes to `json.luau`

Each addition is marked `Wally-Plugin addition` in the file.

- `json.deserialize(src, options?)` takes `DeserializeOptions`, `{ jsonc: boolean?, ordered: boolean? }`. With no options, or both off, the strict parser runs as upstream wrote it: its only edits are branches taken when `state.ordered` is set.
- `ordered = true` returns `OrderedValue` shapes: an object is `{ kind = "map", entries = { { key = ..., value = ... } } }` with entries sorted by key bytes and a repeated key keeping its last value (serde_json's `BTreeMap`, which is how Rojo reads JSON); an array is `{ kind = "array", items = { ... } }`; `null` is `{ kind = "null" }`. Added for it: the `OrderedValue` and `DeserializeOptions` types, the `orderedNull` and `orderedMap` helpers, an `ordered` field on `DeserializerState`, first-seen key tracking in `deserializeObject`, and the shape branches in `deserialize`.
- `jsonc = true` parses Rojo 7.7.1's dialect through a new section, "JSONC deserialization", ported from jsonc-parser 0.27.1 with its default options (`src/scanner.rs`, `src/string.rs`, `src/parse_to_ast.rs`, and the serde conversion in `src/ast.rs`):
  - `//` and `/* */` comments between any two tokens;
  - the comma after an object property or array element is optional, so trailing and missing commas both pass; a doubled or leading comma fails;
  - object keys may be strings, words (alphanumerics, `-` and `_`, ended by whitespace or `:`) or number literals, kept as written (`0x10` stays `"0x10"`); `true`, `false` and `null` are refused as keys;
  - strings may be single-quoted; `\'` is valid only inside single quotes and `\"` only inside double quotes; raw control characters are allowed; a `\u` surrogate must be paired;
  - numbers may take a leading `+` and may be hexadecimal (`0x` or `0X`, after an optional sign), converted to an integer; a hexadecimal literal above i64's maximum, or a decimal literal that is not finite, becomes the literal's text, as jsonc-parser does when serde_json cannot hold it;
  - whitespace is Rust's `char::is_whitespace`: ASCII space, tab, LF, VT, FF and CR, plus U+0085, U+00A0, U+1680, U+2000 to U+200A, U+2028, U+2029, U+202F, U+205F and U+3000; a byte order mark is not whitespace, so it fails;
  - text that is empty or holds only comments fails with "File contains no JSON value", and a second top-level value with "Text cannot contain more than one JSON value".
- `jsonc` and `ordered` combine. Without `ordered`, the JSONC path returns upstream's shapes (`json.null`, objects that `json.asObject` recognises).

Each rule above was checked against `rojo build` 7.7.1 on the same input on 2026-10-22, and the port agrees with it except where listed below. `Tests/Vendor.spec.luau` holds the cases.

### Known approximations

- Rust's `char::is_alphanumeric` is Unicode-aware. Here every non-ASCII character that is not whitespace counts as alphanumeric inside a word, so a key such as `a→b` passes where Rojo refuses it (measured).
- Error messages use jsonc-parser's wording but give a byte offset (`around N`) rather than a line and column.
- A hexadecimal literal between 2^53 and i64's maximum converts through `tonumber(hex, 16)`, which may round differently from Rust's `i64 as f64` in the last place.
- The JSONC path does not validate UTF-8; the caller does, as Rojo does before parsing.

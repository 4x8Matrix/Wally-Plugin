# eryx (vendored)

- Upstream: https://github.com/Bottersnike/eryx
- Commit: `253f0aea259bb8cc6cff096d4188f5d353ca76d7` (head of `master`, committed 2026-07-12), fetched 2026-10-23 from raw.githubusercontent.com
- License: eryx by Bottersnike, MIT, confirmed by its author to the owner on 2026-10-23 (the repository has no LICENSE file). `LICENSE` here holds the MIT text and records that confirmation.

| File here | Upstream path |
| --- | --- |
| `toml/init.luau` | `src/modules/data/toml/init.luau` |
| `toml/decoder.luau` | `src/modules/data/toml/decoder.luau` |
| `toml/shared.luau` | `src/modules/data/toml/shared.luau` |
| `toml/cst.luau` | `src/modules/data/toml/cst.luau` |
| `toml/encoder.luau` | `src/modules/data/toml/encoder.luau` |
| `yaml.luau` | `src/modules/data/yaml.luau` |
| `csv.luau` | `src/modules/data/csv.luau` |

The plugin requires `Vendor.eryx.toml` (its `decode`) and `Vendor.eryx.toml.shared` (its `tableIsArray`, which tells a decoded array from a table). `init.luau` requires the encoder and the CST module when it loads, so both are here; the plugin calls neither, and the encoder is not adapted to the decoder changes below.

`yaml.luau` and `csv.luau` (fetched 2026-10-23, same commit) require no other module and load in Studio as upstream wrote them (measured 2026-10-23). The plugin requires `Vendor.eryx.yaml` (its `decodeDocuments`) and `Vendor.eryx.csv` (its `parse`).

## TOML changes

Every change is marked `Wally-Plugin change` in the file it touches. `cst.luau` is unchanged.

Loading in Roblox:

1. `init.luau`, `decoder.luau`, `encoder.luau`: each `require("@self/<name>")` is an instance require (`script.<name>` from `init.luau`, `script.Parent.<name>` from the others).
2. `shared.luau`: Roblox has no regex library, so `require("@eryx/regex")` and the `shared.regex` field are gone, and each of the fourteen `*_RE` constants is an object with the same `isMatch`, built from Luau string patterns or from the token checks the file already has (`classifyIntegerToken`, `isUnsignedDecimalIntegerRange`, `isDigitSequenceRange`). Upstream's expression is written above each. Checked against the upstream expressions (run through Lune 0.10.4's `@lune/regex`) on 26,349 tokens, with no difference.

Reading TOML as Rojo 7.7.1 does. Rojo reads `.toml` files with the toml 0.5.11 crate, which reads TOML 1.0 with quirks of its own; eryx reads TOML 1.1. Each change was measured with `rojo build` 7.7.1 on the same text:

3. `shared.luau`, binary integers: converted in one step with `tonumber(digits, 2)`, as toml 0.5.11 converts its `i64` to `f64`. Upstream doubled bit by bit, which rounds differently above 2^53 (`0b1100001001001101110101010111001001001010100110001111011` is `27345862311365756` in Rojo, `27345862311365750` upstream).
4. `decoder.luau`: the `OFFSET_DT_MINUTE_RE`, `LOCAL_DT_MINUTE_RE` and `LOCAL_TIME_MINUTE_RE` locals are gone, since change 11 stops reading them.
5. `decoder.luau`: the parser has an `implicitTables` set, the tables a header path created without defining them (change 14).
6. A leading UTF-8 byte order mark is skipped (parsing starts at byte 4), as toml 0.5.11's tokenizer skips it. Upstream refused it.
7. DEL (U+007F) is allowed in a comment, in all four comment loops, as toml 0.5.11 allows U+0020 to U+10FFFF there. Upstream refused it.
8. The TOML 1.1 escapes `\e` and `\xHH` are refused.
9. Multi-line strings: CRLF in the raw text reads as LF (the new `rawText` helper), as toml 0.5.11's tokenizer folds CRLF, while an escaped `\r` before a newline stays; a CR right after the opening quotes is skipped only as part of CRLF, so a bare CR there is refused. Upstream kept CRLF and skipped a lone CR.
10. Inline tables are one line, as in TOML 1.0: only spaces and tabs between their parts (no newline, no comment), the value on the same line as its `=`, and no trailing comma (`{ a = 1, }` and `{ , }` fail; `{}` and `{ }` pass).
11. Datetimes: seconds are required (`07:32` and `1979-05-27T07:32Z` fail), and the text is written as toml 0.5.11's `Datetime` prints it: `T` between date and time, `Z` for `z`, fraction digits cut to nine with trailing zeros dropped (`.120` prints `.12`, `.000` prints nothing, `.1234567891` prints `.123456789`), and an offset of `-00:MM` as `+00:MM`.
12. Datetime fields take toml 0.5.11's ranges: day 1 to 31 whatever the month (`1979-02-30` passes), hour 0 to 24, second 0 to 59 (upstream allowed 60), and an offset's hour and minute unchecked (`+99:99` passes).
13. Values: a `+` before a prefixed or a negative number is dropped, as toml 0.5.11 reads `+` and then any number it reads alone (`+0x10` is 16, `+-1` is -1, `+-0x10` and `++1` fail); integers must fit in an `i64` in every base (new `fitsInt64` and `INT64_LIMITS`); an integer zero is `0`, never `-0`; a float literal too large to be finite fails (`1e400`).
14. Tables: a header path may not pass through a table that dotted keys created (`[a]`, `b.c = 1`, `[a.b.d]` fails), and dotted keys may not pass through a table that a header path created (`[a.b.d]`, `[a]`, `b.c = 1` fails). toml 0.5.11 refuses both as a key defined twice; upstream accepted both.

## TOML measurement

745 cases, each built by `rojo build` 7.7.1 as a one-file project and read back with Lune: 558 from toml-test 1.5.0 (every file its `files-toml-1.0.0` and `files-toml-1.1.0` lists name, valid and invalid) and 187 written for the rules above. Through `decodeToml` and `encodeLuauValue`, the changed decoder gives Rojo's module source, or refuses where Rojo refuses, on 742. Upstream eryx matched 664 and upstream Lute's `batteries/toml.luau` 663.

The three left are one known divergence: toml 0.5.11 reads a table whose first key is `$__toml_private_datetime` as the datetime its string value spells (its private datetime marker), and refuses one whose value is not a string; here that key is an ordinary key. `decodeToml` carries the seam.

Error messages are eryx's wording with a byte offset, where Rojo gives toml 0.5.11's wording with a line and a column.

## YAML changes

Rojo 7.7.1 reads `.yaml` and `.yml` files with yaml-rust2 0.10.4 (`YamlLoader::load_from_str`) and converts them with `yaml_to_luau` (`src/snapshot_middleware/yaml.rs`). Upstream's decoder reads a subset of YAML into plain tables, which lose mapping order, nulls and the array and map split. Its half of `yaml.luau` (from the `Decode` banner to the end) is rewritten in place on eryx's own structure, so that it reads YAML as yaml-rust2 reads it: the text is split into lines once, block collections are read line by line by `parseNode`, `parseBlockMapping` and `parseBlockSequence`, and flow collections and scalars are read character by character by `parseFlow`, `parseFlowSequence`, `parseFlowMapping`, `tryQuoted`, `parseBlockScalar` and the new `readPlain`. Upstream's `stripComment` and `parseSingleQuoted` are gone (comments and `''` are read in place). Each function is marked `Wally-Plugin change` or `Wally-Plugin addition`. The encoder half is unchanged, and the plugin does not call it.

1. Results are DataValues: a mapping is `{ kind = "map", entries = { { key = ..., value = ... } } }` in written order with keys of any type (scalars and collections), a sequence `{ kind = "array", items = { ... } }`, a null `{ kind = "null" }`; scalars are strings, numbers and booleans.
2. `yaml.decodeDocuments(text)` (addition) returns every document of the stream, and the message for the first value Rojo's conversion refuses: an integer above 2^53 (Rojo's message, `the integer '...' cannot be losslessly converted into a Luau number`; negative integers are not checked), or a value yaml-rust2 reads as `BadValue` (`Rojo cannot convert YAML to Luau because of a parsing error`). They are found after the document is built, in Rojo's order (keys before values). `yaml.decode` returns the first document. Text yaml-rust2 refuses throws yaml-rust2's message, without its position.
3. Documents are counted as yaml-rust2's parser counts them: `---` starts one (its content may follow on the marker line, but a key or a sequence entry may not), `...` ends one (only a comment may follow it), and content with neither starts one at the stream's start or after `...`. Empty and comment-only streams hold none. `%YAML` and `%TAG` directives come before `---`; a second `%YAML` is refused, and each directive replaces the handles declared before it, as yaml-rust2 0.10.4 does. Anchors are forgotten at each document. Upstream read only the first document and skipped every `---` and `...` line inside a mapping.
4. A NUL character ends the stream, as yaml-rust2 reads it.
5. Plain scalars resolve as yaml-rust2's `Yaml::from_str` and `parse_f64` do: null is empty, `~` or `null`; booleans are `true`, `True`, `TRUE`, `false`, `False`, `FALSE`; integers are Rust's `i64` parsing, decimal with an optional sign, `0x` and `0o` prefixes (lowercase, whose digits may carry a sign), and a `+` before any of them, read exactly in three 24-bit limbs and rounded once to a double; floats are `.inf`, `.Inf`, `.INF` with an optional sign, `.nan`, `.NaN`, `.NAN`, and Rust's float grammar on text holding an ASCII digit. Everything else is a string. Upstream also took `yes`, `no`, `on`, `off`, `Null` and `NULL`, and read numbers with `tonumber`.
6. Tags are read as yaml-rust2 reads them: on a plain scalar, the core schema's `!!bool`, `!!int`, `!!float` and `!!null` resolve the text or make a `BadValue`, any other tag makes a string, a quoted or block scalar is always a string, and tags on collections are ignored. `%TAG` handles, `!` local tags, `!<...>` verbatim tags and `%XX` escapes are read, and an undeclared `!name!` handle is refused. Upstream kept a tag as part of the scalar's text.
7. Anchors and aliases follow yaml-rust2's parser and loader: every anchor gets a new id when it is read, and an alias is a copy of the value the latest anchor of its name was set on, once that node is complete; an alias inside its own anchor's node is a `BadValue`, and an alias to an unknown anchor is refused. Anchors are read on keys, on values, on nodes that start on the next line and inside flow collections; an anchor name ends at a blank, a flow indicator or a byte order mark. Upstream stored values by name, returned the same table for every alias, and read anchors only on mapping values and lone scalars.
8. Mappings: an implicit key is allowed only at the start of a line or after `-` or `?`, so `a: b: c` is refused; a key may be a quoted scalar, an alias, a flow collection or a plain scalar, with properties, and is forgotten 1024 characters after it starts; `?` explicit keys and an empty key (`: v`) are read; a `:` followed by a tab and then a word or a `-` is refused; a key the mapping already holds is refused with yaml-rust2's message (`String("a"): duplicated key in mapping`); and the mapping is filled as yaml-rust2's loader fills it, so a `BadValue` key leaves its slot empty and the value after it becomes a key. Content indented past a complete entry is refused. Upstream overwrote a repeated key and read `a: b: c` as `"b: c"`.
9. Sequences: an entry is any node, so a compact mapping (at the column of its first key), a nested `- -`, a block scalar and a quoted key (`- "k": v`) follow the dash; a sequence at its mapping's own indentation is the mapping's value; a tab between two dashes is refused; content indented past a complete entry is refused. Upstream assumed a compact mapping two columns past the dash and read `- "k": v` as `"k"`.
10. Plain scalars span lines and fold as yaml-rust2 folds them: a continuation line must reach one column past the enclosing block, a blank line becomes a line break, a comment after a blank ends the scalar, a `: ` in a continuation line is refused, and a tab in the indentation of a continuation line is refused. In a flow they stop at `,[]{}`, and a lone `-` is refused. Upstream read one line.
11. Quoted scalars span lines and fold as yaml-rust2 folds them, with an escaped line break joining lines and continuation lines checked against the block's indentation; every yaml-rust2 escape is read (`\0 \a \b \t \n \v \f \r \e \ \" \/ \\ \N \_ \L \P \xHH \uHHHH \UHHHHHHHH`), and an unknown escape, a bad hexadecimal number and a surrogate or out-of-range code are refused; trailing content after the closing quote is refused, and a comment must follow a blank. Upstream read one line, only the `\x` escape among the hexadecimal ones, and kept an unknown escape's character.
12. Block scalars follow yaml-rust2's `scan_block_scalar`: chomping and indentation indicators in either order (0 refused), the indentation indicator counted from the enclosing block, a header comment that must follow a blank and no other header content; the indentation found from the first content line and the blank lines before it, a wrongly indented line refused, content starting with a tab refused; blank lines, lines holding only spaces past the indentation and comment-looking lines kept; folding that keeps more-indented lines; and the end of the stream read as yaml-rust2 reads it (`a: |` at the end of the stream is `"\n"`, before another key `""`).
13. Flow collections span lines, hold comments and may end with a comma; an empty entry is refused; `[a: 1]` is a mapping of one pair, `{a, b}` maps its keys to null, `?` explicit keys are read, and a quoted or flow key takes an adjacent `:` (`{"a":1}`). A flow token left of its block's indentation is refused; inside a mapping value or a sequence entry that indentation is one column past the block's until the first plain scalar in the flow, as yaml-rust2 0.10.4 tracks it. Upstream read one line and turned keys into strings.
14. Comments: `#` starts a comment only after a blank, and a comment line may be indented. Upstream did not skip an indented comment line.
15. A byte order mark is ordinary content, as in yaml-rust2 (`\u{FEFF}a: 1` has the key `"\u{FEFF}a"`); CRLF and lone CR are line breaks, as upstream already read them. A tab may come before the root node.

Known difference, kept on purpose (`decodeYaml` carries the seam): a block scalar at a document's root whose content starts in column 0 ends at a `---` line here, because documents are split before they are read; yaml-rust2 reads the rest of the stream up to `...` into it (`--- |`, `foo`, `---`, `bar` is `"foo\n---\nbar\n"` in Rojo and two documents here).

## CSV changes

Rojo 7.7.1 reads `.csv` files with the csv 1.4.0 crate's defaults. Upstream's parser reads them the same way (a leading byte order mark stripped, CRLF, LF and CR ending records, `"` quoting with doubled quotes, quoted newlines, text after a closing quote appended) except for one rule:

1. `parse`'s `skipblanklines` option drops only a line holding no byte at all, as the crate skips empty lines. Upstream also dropped a line holding `""`, which the crate reads as a record of one empty field (and refuses in a file with more columns). Marked `Wally-Plugin change`.

`decodeCsv` does the rest of Rojo's work: the header row, the record length check, the localization entries and their JSON.

## YAML and CSV measurement

421 YAML cases, each built by `rojo build` 7.7.1 as a one-file project and its `Source` read with Lune 0.10.4: the 55 distinct `.yaml` and `.yml` files in the conformance corpus (every one in its 798 zips), 116 cases measured for lua-tinyyaml in Task 1b (including its 13 recorded divergences), and 250 written for the rules above. Through `decodeYaml` and `encodeLuauValue`, the changed decoder gives Rojo's module source, or refuses where Rojo refuses, on 420; the one left is the known difference above. Upstream eryx matched 155 even with key order and nulls ignored (13 of the 55 corpus files).

51 CSV cases, built the same way and their `LocalizationTable.Contents` read (Rojo's `csv_bug_145`, `csv_bug_147` and `csv_in_folder` build tests among them): through `decodeCsv`, the changed parser matches all 51, upstream 50.

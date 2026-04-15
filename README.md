Lua filter for making Pandoc tables with CSV.

## Usage

```sh
pandoc doc.md --lua-filter csv-table.lua -o doc.html
```

Write CSV directly inside a `table` div:

```markdown
::: table
Name , Age , City
Alice, 30  , New York
Bob  , 25  , Los Angeles
:::
```

## Attributes

| Attribute | Default | Description |
|---|---|---|
| `delimiter` / `delim` / `sep` | `,` | Field delimiter character |
| `quote` | `"` | Quote character; `"none"` to disable quoting |
| `escape` | *(none)* | Escape character inside quoted fields; default uses doubled-quote (`""` → `"`) |
| `keep-space` / `keepspace` | `false` | `"true"` to preserve whitespace after the delimiter |
| `header` | `true` | `"false"` to treat all rows as data (no header row) |
| `caption` / `title` | *(none)* | Table caption; supports inline Markdown |
| `align` / `aligns` | `d` | Comma-separated per-column alignment: `l` `r` `c` `d` |

> [!TIP]
> Try wrapping table in `` ``` `` fences for parsing errors:

~~~markdown
::: table
```
Name , Link                              , Notes
Alice, [GitHub](https://github.com/alice), **maintainer**
Bob  , [GitHub](https://github.com/bob)  , `on leave`
```
:::
~~~

> [!CAUTION]
> Pandoc's Markdown reader expands tab characters to spaces before the filter
> runs, so `delimiter="\t"` only works when pandoc is given a pre-parsed AST or
> a non-Markdown input format. For visually-aligned columns in Markdown source,
> use `|` as the delimiter instead.

> [!CAUTION]
> In Markdown attribute syntax a literal backslash must be doubled:
> `escape="\\"` gives `\` as the escape character.

## Examples

With attributes:

```markdown
::: {.table caption="Results" align="l,r,c"}
Name , Score , Status
Alice, 95    , active
Bob  , 82    , active
:::
```

Quoted fields with commas and line breaks:

~~~markdown
::: table
```
Name , Bio
Alice, "Singer, songwriter, and actress"
Bob  , Programmer
```
:::
~~~

Custom quote character:

~~~markdown
::: {.table quote="'"}
```
Name , Note
Alice, 'She said ''hello'''
Bob  , 'plain, field'
```
:::
~~~

Backslash escaping, no header, aligned columns:

~~~markdown
::: {.table escape="\\" header="false" align="l,r,r"}
```
Widget A, "$1,234", active
Widget B, "$567"  , "on hold"
```
:::
~~~

## CSV parsing

The LPeg grammar mirrors [`Text.Pandoc.CSV`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/CSV.hs):

- Quoted cells may span multiple lines.
- Inside a quoted cell, the escape character (if set) prefixes a literal character; otherwise consecutive quote chars collapse to one (`""` → `"`).
- Blank lines terminate the row sequence, matching Parsec's `sepEndBy` behaviour for `pCSVRow`.
- Trailing whitespace/newlines after the last row are consumed silently.

Cell text is parsed as Markdown, so cells can contain **bold**, `code`, [links](url), etc.

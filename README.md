Pandoc Lua filter for creating tables with CSV code blocks.

Requires Pandoc 3.2 or later.

## Usage

```
pandoc input.md --lua-filter csv-table.lua -o output.html
```

## Syntax

Write CSV in a fenced code block with class `csv`:

````markdown
```csv
Name,Age,City
Alice,30,__NYC__
Bob,25,*LA*
```
````

Or include data from a file:

````markdown
```{.csv file=data.csv}
```
````

Specify options as code fence attributes:

````markdown
```{.csv caption="**My Table**" header=false align=lcr widths=3,1,2 table-width=80% markdown=false}
Casa,9,Seattle
Kira,7,Hawaii
```
````

CSV content must conform to [RFC4180](https://www.ietf.org/rfc/rfc4180.txt),
 otherwise use tools like [DuckDB](https://duckdb.org/2023/10/27/csv-sniffer) to clean data before using.

## Options

| Option | Values | Description |
|--------|--------|-------------|
| `file` | path | Load CSV from a file instead of inline content |
| `caption` | string | Table caption (supports markdown) |
| `header` | `true` / `false` | Treat first row as header (default: `true`) |
| `align` | string of `l` `c` `r` `d` | Column alignments, one per column |
| `widths` | comma-separated numbers | Relative column widths, normalized to fractions |
| `table-width` | CSS value | Overall table width (e.g. `80%`, `500px`) |
| `markdown` | `true` / `false` | Parse cell content as markdown (default: `true`) |

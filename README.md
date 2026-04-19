# Pansv

Pandoc filter for creating tables with CSV.
Format must conform to [CSV standard](#csv-format),
 otherwise clean data with tools like [DuckDB](https://duckdb.org/2023/10/27/csv-sniffer).
Requires Pandoc 3.2 or later.

```
pandoc input.md --lua-filter csv-table.lua -o output.html
```

Write CSV in a fenced code block:

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
```{.csv caption="**My Table**" header=false align=lcr widths=3,1,2 tablewidth=80% markdown=false}
Casa,9,Seattle
Kira,7,Hawaii
```
````

| Option              | Description                        | Example          |
|---------------------|------------------------------------|------------------|
| `file`/`f`          | Load CSV from a file               | `data.csv`       |
| `caption`/`cap`     | Table caption (supports markdown)  | `*Experiment*`   |
| `header`/`h`        | Treat first row as header?         | `true` (default) |
| `align`/`a`         | Column alignments, `d` for default | `lcrd`           |
| `widths`/`w`        | Relative column widths             | `4,4,2`          |
| `tablewidth`/`tw`   | Overall table width                | `80%`, `500px`   |
| `markdown`/`md`     | Parse table cells as markdown?     | `true` (default) |

## CSV Format

CSV content follows [RFC 4180](https://www.ietf.org/rfc/rfc4180.txt):

- Delimiter must be `,`
- Fields containing a comma, double quote, or newline must be wrapped in double quotes `"`
- Double quotes inside a quoted field are escaped by doubling: `"say ""hello"""`
- No trailing spaces after a quoted field
- Every row must have the same number of fields

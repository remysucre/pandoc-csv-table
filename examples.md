# Basic

::: table
Name , Age , City
Alice, 30  , New York
Bob  , 25  , Los Angeles
:::

# With attributes

::: {.table caption="Results" align="l,r,c"}
Name , Score , Status
Alice, 95    , active
Bob  , 82    , active
:::

# Quoted fields with commas and line breaks

::: table
```
Name , Bio
Alice, "Singer, songwriter, and actress"
Bob  , Programmer
```
:::

# Custom quote character

::: {.table quote="'"}
```
Name , Note
Alice, 'She said ''hello'''
Bob  , 'plain, field'
```
:::

# No header, aligned columns

::: {.table header="false" align="l,r,r"}
```
Widget A, "$1,234", active
Widget B, "$567"  , "on hold"
```
:::

# Backslash escape character

::: {.table escape="\\"}
```
Name , Note
Alice, "She said \"hi\" to Bob"
Bob  , plain
```
:::

# Markdown in cells (code fence to avoid ambiguity)

::: table
```
Name , Link                              , Notes
Alice, [GitHub](https://github.com/alice), **maintainer**
Bob  , [GitHub](https://github.com/bob)  , `on leave`
```
:::

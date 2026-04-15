local lpeg = require("lpeg")
local P, S, C, Cs, Ct = lpeg.P, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct

-- ============================================================
-- CSV PARSER  (mirrors Text.Pandoc.CSV)
-- ============================================================

--[[
  build_csv_pattern(opts) → LPeg pattern

  opts fields (all optional):
    delim      string  one char, default ","
    quote      string|nil  one char, nil = no quoting
    escape     string|nil  one char, nil = doubled-quote escaping
    keep_space bool    default false

  The returned pattern, when matched against the full CSV text, returns
  a Lua table (list of rows, each row a list of cell strings).
--]]
local function build_csv_pattern(opts)
  local delim_char  = opts.delim      or ","
  local quote_char  = opts.quote               -- nil  → no quoting
  local escape_char = opts.escape              -- nil  → doubled-quote
  local keep_space  = opts.keep_space or false

  local delim   = P(delim_char)
  local endline = P("\r")^-1 * P("\n")

  -- escaped opts  — mirrors the Haskell function of the same name.
  -- Produces a capture of the single unescaped character.
  local escaped_pat
  if escape_char then
    -- custom escape: escape_char followed by any non-newline char
    -- → capture the char after the escape (stripping the escape itself)
    escaped_pat = P(escape_char) * C(1 - S("\r\n"))
  elseif quote_char then
    -- doubled-quote: "" → "
    -- substitution capture: match two quote chars, yield one
    escaped_pat = P(quote_char) * P(quote_char) / quote_char
  else
    escaped_pat = P(false)  -- always fails (no escaping possible)
  end

  -- pCSVQuotedCell
  -- Quoted cells may contain any character (including newlines) except the
  -- closing quote (or the escape character when one is configured).
  local quoted_cell_pat
  if quote_char then
    -- Characters that are taken literally inside a quoted field:
    --   • not the closing quote char
    --   • not the escape char (when configured)
    local literal_char
    if escape_char then
      literal_char = 1 - (P(quote_char) + P(escape_char))
    else
      literal_char = 1 - P(quote_char)
    end

    -- Cs accumulates: runs of literal chars  +  escaped sequences
    -- C(pat^1) captures multiple literal chars as one string segment,
    -- escaped_pat contributes a single substituted/captured char.
    local cell_content = Cs((C(literal_char^1) + escaped_pat)^0)

    quoted_cell_pat = P(quote_char) * cell_content * P(quote_char)
  else
    quoted_cell_pat = P(false)
  end

  -- pCSVUnquotedCell — any chars except delimiter and line-endings
  local unquoted_cell_pat = C((1 - (delim + S("\r\n")))^0)

  -- pCSVCell
  local cell_pat = quoted_cell_pat + unquoted_cell_pat

  -- pCSVDelim — optional pre-whitespace + delimiter + optional post-whitespace.
  -- Pre-delimiter spaces are always stripped (handles column-aligned CSV where
  -- fields are padded to line up commas).  Post-delimiter whitespace is stripped
  -- unless keep_space is set (mirrors Haskell's csvKeepSpace behaviour).
  local pre  = S(" \t")^0
  local post
  if keep_space then
    post = P(true)
  elseif delim_char == "\t" then
    post = P(" ")^0
  else
    post = S(" \t")^0
  end
  local delim_pat = pre * delim * post

  -- pCSVRow — one cell, followed by zero or more (delimiter + cell) pairs.
  -- Note: the Haskell version requires many1 extra cells when the first cell
  -- is empty, so that blank lines fail pCSVRow (causing sepEndBy to stop).
  -- We replicate the *observable result* by filtering blank rows in Lua
  -- after the full parse (see parse_csv below).
  local row_pat = Ct(cell_pat * (delim_pat * cell_pat)^0)

  -- pCSV — rows separated (and optionally terminated) by newlines,
  -- followed by optional trailing whitespace and end-of-input.
  -- This mirrors:  (pCSVRow `sepEndBy` endline) <* (spaces *> eof)
  local spaces = S(" \t\r\n")^0
  local csv_pat =
    Ct(row_pat * (endline * row_pat)^0 * endline^-1)
    * spaces * P(-1)

  return csv_pat
end

--[[
  parse_csv(text, opts) → rows, nil  |  nil, errmsg

  rows is a list of rows; each row is a list of cell strings.
  Blank rows (single empty cell = blank input line) are removed, matching
  the effect of Haskell's pCSVRow failing on blank lines.
--]]
local function parse_csv(text, opts)
  local ok, result = pcall(function()
    return build_csv_pattern(opts):match(text)
  end)

  if not ok then
    return nil, "Failed to build/run CSV grammar: " .. tostring(result)
  end
  if result == nil then
    return nil, "CSV parse error: input does not conform to the grammar"
  end

  -- Filter out blank rows (mirrors sepEndBy stopping on blank lines)
  local rows = {}
  for _, row in ipairs(result) do
    if not (#row == 1 and row[1] == "") then
      table.insert(rows, row)
    end
  end

  return rows
end

-- ============================================================
-- ATTRIBUTE PARSING
-- ============================================================

local ALIGN_MAP = {
  l       = pandoc.AlignLeft,    left    = pandoc.AlignLeft,
  r       = pandoc.AlignRight,   right   = pandoc.AlignRight,
  c       = pandoc.AlignCenter,  center  = pandoc.AlignCenter,
  d       = pandoc.AlignDefault, default = pandoc.AlignDefault,
}

local function parse_bool(s, default)
  if s == nil then return default end
  local l = s:lower()
  if l == "true"  or l == "yes" or l == "1" then return true  end
  if l == "false" or l == "no"  or l == "0" then return false end
  return default
end

-- Interpret a one-character (or escape-sequence) attribute value.
-- Returns a single Lua string character, or nil when the raw value is nil.
local function parse_char(s, default)
  if s == nil then return default end
  if s == "\\t" or s == "tab"  then return "\t" end
  if s == "\\n" or s == "nl"   then return "\n" end
  if s == "\\|"                 then return "|"  end
  if s:sub(1,1) == "\\" and #s == 2 then return s:sub(2) end
  return s:sub(1, 1)  -- take the first character
end

local function parse_options(attr)
  local a = attr.attributes

  -- Delimiter
  local delim = parse_char(a.delimiter or a.delim or a.sep, ",")

  -- Quote character (nil = quoting disabled)
  local quote_raw = a.quote
  local quote
  if quote_raw == nil then
    quote = '"'  -- default: double-quote
  elseif quote_raw == "none" or quote_raw == "false" or quote_raw == "" then
    quote = nil
  else
    quote = parse_char(quote_raw, '"')
  end

  -- Escape character (nil = doubled-quote escaping)
  local escape_raw = a.escape
  local escape
  if escape_raw == nil or escape_raw == "none" or escape_raw == "" then
    escape = nil
  else
    escape = parse_char(escape_raw, nil)
  end

  local keep_space = parse_bool(a["keep-space"] or a.keepspace, false)
  local has_header = parse_bool(a.header, true)
  local caption_str = a.caption or a.title or ""

  -- Per-column alignments (comma-separated flags, e.g. "l,r,c,d")
  local aligns = {}
  local aligns_raw = a.align or a.aligns or ""
  for part in (aligns_raw .. ","):gmatch("([^,]*),") do
    local key = part:match("^%s*(.-)%s*$"):lower()
    if key ~= "" then
      table.insert(aligns, ALIGN_MAP[key] or pandoc.AlignDefault)
    end
  end

  return {
    delim       = delim,
    quote       = quote,
    escape      = escape,
    keep_space  = keep_space,
    has_header  = has_header,
    caption_str = caption_str,
    aligns      = aligns,
  }
end

-- ============================================================
-- TEXT EXTRACTION FROM DIV CONTENT
-- ============================================================

--[[
  Extract the raw CSV text from the Blocks inside the div.

  Priority:
    1. CodeBlock  — the canonical form (``` inside the div)
    2. RawBlock   — pass raw content straight through
    3. Para/Plain — reconstruct text from inlines (for simple inline CSVs)
--]]
local function extract_csv_text(blocks)
  for _, block in ipairs(blocks) do
    if block.t == "CodeBlock" then
      return block.text
    end
    if block.t == "RawBlock" then
      return block.text
    end
  end

  -- Fallback: stitch together paragraph inlines.
  -- Only handles plain text; use a ``` code fence inside the div for CSV
  -- containing quoted fields, as pandoc transforms quotes into Quoted inlines.
  local lines = {}
  for _, block in ipairs(blocks) do
    if block.t == "Para" or block.t == "Plain" then
      local parts = {}
      for _, inline in ipairs(block.content) do
        local t = inline.t
        if     t == "Str"      then table.insert(parts, inline.text)
        elseif t == "Space"    then table.insert(parts, " ")
        elseif t == "SoftBreak" or t == "LineBreak" then table.insert(parts, "\n")
        end
      end
      table.insert(lines, table.concat(parts))
    end
  end
  return table.concat(lines, "\n")
end

-- ============================================================
-- PANDOC TABLE CONSTRUCTION
-- ============================================================

-- Build a pandoc.Cell whose contents are the Markdown-parsed cell text.
local function make_cell(text, align)
  local trimmed = (text or ""):match("^%s*(.-)%s*$")
  local content
  if trimmed == "" then
    content = { pandoc.Plain({}) }
  else
    local doc = pandoc.read(trimmed, "markdown-smart")
    content = doc.blocks
    if #content == 0 then
      content = { pandoc.Plain({}) }
    end
  end
  return pandoc.Cell(content, align or pandoc.AlignDefault, 1, 1)
end

-- Build a pandoc.Row from a list of cell strings, padding if needed.
local function make_row(cell_strings, aligns, ncols)
  local cells = {}
  for i = 1, ncols do
    local text  = cell_strings[i] or ""
    local align = aligns[i] or pandoc.AlignDefault
    cells[i] = make_cell(text, align)
  end
  return pandoc.Row(cells)
end

--[[
  csv_to_table(rows, opts) → pandoc.Table | nil, errmsg

  Converts the parsed CSV rows into a pandoc.Table element, using the
  native Pandoc Lua constructors (pandoc.Table, pandoc.TableHead,
  pandoc.TableFoot, pandoc.Row, pandoc.Cell, pandoc.Caption).
--]]
local function csv_to_table(rows, opts)
  if #rows == 0 then
    return nil, "no data rows found in CSV"
  end

  -- Column count = width of the widest row
  local ncols = 0
  for _, row in ipairs(rows) do
    if #row > ncols then ncols = #row end
  end
  if ncols == 0 then
    return nil, "all CSV rows are empty"
  end

  -- Fill alignment list to ncols (AlignDefault for unspecified columns)
  local aligns = {}
  for i = 1, ncols do
    aligns[i] = opts.aligns[i] or pandoc.AlignDefault
  end

  -- ColSpec: omit width (second element) → ColWidthDefault / auto
  local colspecs = {}
  for i = 1, ncols do
    colspecs[i] = { aligns[i] }
  end

  -- Split header vs. body rows
  local head_rows = {}
  local body_rows = {}
  if opts.has_header and #rows >= 1 then
    head_rows = { make_row(rows[1], aligns, ncols) }
    for i = 2, #rows do
      body_rows[#body_rows + 1] = make_row(rows[i], aligns, ncols)
    end
  else
    for _, row in ipairs(rows) do
      body_rows[#body_rows + 1] = make_row(row, aligns, ncols)
    end
  end

  -- Caption (supports inline Markdown in the caption attribute)
  local caption
  if opts.caption_str ~= "" then
    local cap_blocks = pandoc.read(opts.caption_str, "markdown").blocks
    local cap_inlines
    if #cap_blocks > 0 and cap_blocks[1].t == "Para" then
      cap_inlines = cap_blocks[1].content  -- unwrap the paragraph
    else
      cap_inlines = { pandoc.Str(opts.caption_str) }
    end
    caption = pandoc.Caption(
      { pandoc.Para(cap_inlines) },  -- long caption (list of Blocks)
      cap_inlines                    -- short caption (list of Inlines)
    )
  else
    caption = pandoc.Caption()
  end

  -- TableBody is a plain Lua table (no pandoc.TableBody constructor)
  local body = {
    attr            = pandoc.Attr(),
    body            = body_rows,
    head            = {},       -- no intermediate head rows
    row_head_columns = 0,
  }

  return pandoc.Table(
    caption,
    colspecs,
    pandoc.TableHead(head_rows),
    { body },
    pandoc.TableFoot({})
  )
end

-- ============================================================
-- FILTER ENTRY POINT
-- ============================================================

local function has_class(attr, cls)
  for _, c in ipairs(attr.classes) do
    if c == cls then return true end
  end
  return false
end

function Div(el)
  if not has_class(el.attr, "table") then
    return nil  -- not our div; leave unchanged
  end

  local opts     = parse_options(el.attr)
  local csv_text = extract_csv_text(el.content)

  if csv_text == "" then
    io.stderr:write("[csv-table] Warning: div has no CSV content — leaving as-is\n")
    return nil
  end

  local rows, parse_err = parse_csv(csv_text, opts)
  if rows == nil then
    io.stderr:write("[csv-table] Error parsing CSV: " .. parse_err .. "\n")
    return nil
  end

  local tbl, build_err = csv_to_table(rows, opts)
  if tbl == nil then
    io.stderr:write("[csv-table] Error building table: " .. build_err .. "\n")
    return nil
  end

  return tbl
end

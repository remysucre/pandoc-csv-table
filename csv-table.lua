function CodeBlock(block)
  if block.classes:includes('csv') then
    local attrs = block.attr.attributes
    local csv = block.text
    if attrs.file then
      local f = assert(io.open(attrs.file, 'r'))
      csv = f:read('*a')
      f:close()
    end
    local tbl = pandoc.read(csv, 'csv').blocks[1]

    if attrs['table-width'] then
      tbl.attr.attributes['style'] = 'width: ' .. attrs['table-width']
    end

    if attrs.widths then
      local widths = {}
      local total = 0
      for w in attrs.widths:gmatch('[^,]+') do
        local n = tonumber(w)
        widths[#widths + 1] = n
        total = total + n
      end
      for i, w in ipairs(widths) do
        if tbl.colspecs[i] then
          local cs = tbl.colspecs[i]
          cs[2] = w / total
          tbl.colspecs[i] = cs
        end
      end
    end

    if attrs.align then
      local aligns = { l = 'AlignLeft', r = 'AlignRight', c = 'AlignCenter', d = 'AlignDefault' }
      for i = 1, #attrs.align do
        local cs = tbl.colspecs[i]
        if cs then
          cs[1] = aligns[attrs.align:sub(i, i)] or 'AlignDefault'
          tbl.colspecs[i] = cs
        end
      end
    end

    if attrs.header == 'false' then
      tbl.bodies[1].body = tbl.head.rows .. tbl.bodies[1].body
      tbl.head = pandoc.TableHead()
    end

    if attrs.caption then
      tbl.caption = pandoc.Caption(pandoc.read(attrs.caption, 'markdown').blocks[1].content)
    end

    if attrs.markdown ~= 'false' then
      tbl = tbl:walk({
        Plain = function(plain)
          local text = pandoc.utils.stringify(plain.content)
          return pandoc.Plain(pandoc.read(text, 'markdown').blocks[1].content)
        end
      })
    end

    return tbl
  end
end

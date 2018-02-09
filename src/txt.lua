--------------------------------------------------------------------------------
-- txt.lua                                                                    --
--                                                                            --
-- Lua file for use with pandoc. Transforms documents into a plain text file, --
-- with a maximum width of 80 characters. Does not support all constructs     --
-- pandoc supports, as some of them are really hard to do in plain text.      --
--                                                                            --
-- To use, do:                                                                --
--     pandoc <input file> -t txt.lua                                         --
--------------------------------------------------------------------------------


-- Configuration
--------------------------------------------------------------------------------

-- Maximum number of characters on a line
local maxWidth = 80


-- Helper functions
--------------------------------------------------------------------------------

-- Wraps the text to fit the given width, returning a table that contains all
-- the resulting lines. Throws away any extranuous whitespace (line breaks,
-- indentation, double spacing etc.).
local function getWrappedLines(text, width)
    if not width then
        width = maxWidth
    end

    local lines = {}
    local currentLine = {}
    local currentLineLength = -1

    for word in string.gmatch(text, '%S+') do
        local wordLength = string.len(word)

        if currentLineLength + 1 + wordLength > width then
            table.insert(lines, table.concat(currentLine, ' '))
            currentLine = { word }
            currentLineLength = wordLength
        else
            table.insert(currentLine, word)
            currentLineLength = currentLineLength + 1 + wordLength
        end
    end

    table.insert(lines, table.concat(currentLine, ' '))
    return lines
end

-- Wraps the text to fit the given width, returning a new string. Throws away 
-- any extranuous whitespace (line breaks, indentation, double spacing etc.).
local function wrap(text, width)
    local lines = getWrappedLines(text, width)
    return table.concat(lines, '\n')
end

-- Wraps the text to fit the given width, returning a new string. This keeps any
-- line breaks and indentation, but will throw away any other extranuous
-- whitespace.
local function wrapCode(text, width)
    if not width then
        width = maxWidth
    end

    local lines = {}

    for line in string.gmatch(text, '[^\r\n]*') do
        local indent = string.match(line, '%s*')
        local indentSize = string.len(indent)
        local wrappedLines = getWrappedLines(line, width - indentSize)

        for _, wrappedLine in pairs(wrappedLines) do
            table.insert(lines, indent .. wrappedLine)
        end
    end

    return table.concat(lines, '\n')
end

-- Pads the text with the given character on the left and right side to center
-- it within the given width. Will snap left if perfect centering is not
-- possible.
local function center(text, width, character)
    local space = width - string.len(text)
    local left = math.floor(space / 2)
    local right = space - left
    return string.rep(character, left) .. text .. string.rep(character, right)
end

-- Pads the text with spaces to fit the given width, according to the alignment
-- given. Will align left if no valid alignment is given.
local function align(text, width, align)
    if align == 'AlignRight' then
        return string.rep(' ', width - string.len(text)) .. text
    elseif align == 'AlignCenter' then
        return center(text, width, ' ')
    else -- AlignLeft or invalid alignment
        return text .. string.rep(' ', width - string.len(text))
    end
end

-- Table containing all the headers, used for numbering and table of contents
local headers = {}

-- Returns a formatted header with the given text
local function renderHeader(text)
    return
        '\n' ..
        '| ' .. text .. '\n' ..
        '\\' .. string.rep('=', maxWidth - 1)
end

-- Creates the table of contents
local function toc()
    local lines = {}

    table.insert(lines, renderHeader('Table of Contents'))
    table.insert(lines, '')

    function handleHeader(indent, numbers, header)
        local line =
            string.rep(' ', indent * 4) ..
            numbers .. ' - ' .. header.title

        table.insert(lines, line)

        for i = 1, #header do
            handleHeader(indent + 1, numbers .. '.' .. i, header[i])
        end
    end

    for i = 1, #headers do
        handleHeader(0, i, headers[i])
    end

    return table.concat(lines, '\n') .. '\n'
end

-- Table containing all references. Used for notes, links and images, as none of
-- these can be displayed in-line in a plain text file.
local references = {}

-- Returns a list of all references
local function getReferences()
    local lines = {}
    local width = string.len(#references)

    for i = 1, #references do
        local ref = references[i]
        local line

        local hasTitle = ref.title and string.len(ref.title) > 0
        local hasSource = ref.source and string.len(ref.source) > 0
        local num = '[' .. align(i, width, 'AlignRight') .. ']'

        if hasTitle and hasSource then
            line = num .. ' ' .. ref.title .. ' - ' .. ref.source
        elseif hasTitle then
            line = num .. ' ' .. ref.title
        else
            line = num .. ' ' .. ref.source
        end

        table.insert(lines, line)
    end

    return table.concat(lines, '\n')
end

-- Marks a reference for inclusion in the reference list and returns the string
-- that should be inserted into the text.
local function makeReference(text, title, source)
    local reference = {
        ['title'] = title,
        ['source'] = source
    }

    table.insert(references, reference)
    return text .. ' [' .. #references .. ']'
end

-- Returns the string that should be displayed at the top of the document,
-- containing all the metadata (title, author, date, ...), or an empty string if
-- there is no metadata.
local function getMetadata(metadata)
    if not metadata or #metadata == 0 then
        return ''
    end

    local lines = {}

    function add(line)
        table.insert(lines, line)
    end

    if metadata.title then
        add(metadata.title)
    end

    if metadata.author then
        if #lines > 0 then
            add('')
        end

        if #metadata.author == 1 then
            add('by ' .. metadata.author[1])
        else
            add('by')

            for _, author in pairs(metadata.author) do
                add(author)
            end
        end
    end

    if metadata.date then
        if #lines > 0 then
            add('')
        end

        add(metadata.date)
    end

    for i, line in pairs(lines) do
        lines[i] = '|' .. center(line, maxWidth - 2, ' ') .. '|'
    end

    return
        '/' .. string.rep('=', maxWidth - 2) .. '\\\n' ..
        table.concat(lines, '\n') .. '\n' ..
        '\\' .. string.rep('=', maxWidth - 2) .. '/\n'
end


-- Document element handlers
--------------------------------------------------------------------------------

function Blocksep()
    return '\n\n'
end

function Str(text)
    return text
end

function Space()
    return ' '
end

function SoftBreak()
    return ' '
end

function LineBreak()
    return '\n\n'
end

function Emph(text)
    return '_' .. text .. '_'
end

function Strong(text)
    return '*' .. text .. '*'
end

function Subscript(text)
    return text
end

function Superscript(text)
    return text
end

function SmallCaps(text)
    return string.upper(text)
end

function Strikeout(text)
    return '-' .. text .. '-'
end

function Link(text, source, title, attributes)
    return makeReference(text, title, source)
end

function Image(text, source, title, attributes)
    return makeReference(text, title, source)
end

function Code(text, attributes)
    return '`' .. text .. '`'
end

function InlineMath(text)
    error('Inline math: not implemented')
end

function DisplayMath(text)
    error('Display math: not implemented')
end

function Note(text)
    return makeReference('', text, nil)
end

function Span(text, attributes)
    return text
end

function RawInline(format, str)
    return str
end

function Cite(text, citationSource)
    return makeReference(text, citationSource, nil)
end

function Plain(text)
    return text
end

function Para(text)
    return wrap(text)
end

function Header(level, text, attributes)
    local currentHeaders = headers
    local currentLevel = 0
    local targetLevel = level - 1
    local numbers = {}

    while currentLevel <= targetLevel do
        if currentLevel == targetLevel then
            table.insert(currentHeaders, { ['title'] = text })
        end

        -- This should only happen if the top-level headers are missing
        if #currentHeaders == 0  then
            table.insert(currentHeaders, { ['title'] = '' })
        end

        local number = #currentHeaders
        table.insert(numbers, number)

        currentHeaders = currentHeaders[number]
        currentLevel = currentLevel + 1
    end

    return renderHeader(table.concat(numbers, '.') .. ' - ' .. text)
end

function BlockQuote(text)
    local lines = getWrappedLines(text, maxWidth - 2)

    for i, line in pairs(lines) do
        lines[i] = '> ' .. line
    end

    return table.concat(lines, '\n')
end

function HorizontalRule()
    return string.rep('-', maxWidth)
end

function LineBlock(ls)
    error("Line block: not implemented")
end

function CodeBlock(text, attributes)
    local startText, endText

    if attributes.class then
        startText = 'START ' .. string.upper(attributes.class)
        endText = 'END ' .. string.upper(attributes.class)
    else
        startText = 'START CODE'
        endText = 'END CODE'
    end

    return
        center(' ' .. startText .. ' ', maxWidth, '-') .. '\n' ..
        '\n' ..
        wrapCode(text) .. '\n' ..
        '\n' ..
        center(' ' .. endText .. ' ', maxWidth, '-')
end

function BulletList(items)
    local buffer = {}

    for _, item in pairs(items) do
        local itemLines = getWrappedLines(item, maxWidth - 3)

        for i, line in pairs(itemLines) do
            if i == 1 then
                table.insert(buffer, '-  ' .. line)
            else
                table.insert(buffer, '   ' .. line)
            end
        end

        table.insert(buffer, '')
    end

    return table.concat(buffer, "\n")
end

function OrderedList(items)
    local buffer = {}
    local itemNumber = 1

    for _, item in pairs(items) do
        local itemLines = getWrappedLines(item, maxWidth - 3)

        for i, line in pairs(itemLines) do
            if i == 1 then
                table.insert(buffer, itemNumber .. '. ' .. line)
            else
                table.insert(buffer, '   ' .. line)
            end
        end

        table.insert(buffer, '')

        itemNumber = itemNumber + 1
    end

    return table.concat(buffer, '\n')
end

function DefinitionList(items)
    local buffer = {}

    for i, item in pairs(items) do
        local key, value = next(item)
        table.insert(buffer, key)

        local lines = getWrappedLines(table.concat(value, '\n'), maxWidth - 4)

        for _, line in pairs(lines) do
            table.insert(buffer, '    ' .. line)
        end

        if i < #items then
            table.insert(buffer, '')
        end
    end

    return table.concat(buffer, '\n')
end

function CaptionedImage(source, title, caption, attributes)
    error('Captioned image: not implemented')
end

function Table(caption, aligns, widths, headers, rows)
    local buffer = {}

    local function add(text)
        table.insert(buffer, text)
    end

    local maxWidths = {}

    function updateMaxWidths(row)
        for i, text in pairs(row) do
            local width = string.len(text)
            if not maxWidths[i] or width > maxWidths[i] then
                maxWidths[i] = width
            end
        end
    end

    updateMaxWidths(headers)

    for _, row in pairs(rows) do
        updateMaxWidths(row)
    end

    function addRow(row)
        local line = {}

        for i, text in pairs(row) do
            table.insert(line, align(text, maxWidths[i], aligns[i]))
        end

        add('| ' .. table.concat(line, ' | ') .. ' |')
    end

    addRow(headers)

    local separator = {}

    for _, width in pairs(maxWidths) do
        table.insert(separator, string.rep('-', width + 2))
    end

    add('|' .. table.concat(separator, '|') .. '|')

    for _, row in pairs(rows) do
        addRow(row)
    end

    return table.concat(buffer,'\n')
end

function RawBlock(format, str)
    if format == "html" then
        return str
    else
        return ''
    end
end

function Div(text, attributes)
    return text
end

function Doc(body, metadata, variables)
    local buffer = {}

    local function add(text)
        table.insert(buffer, text)
    end

    if #references > 0 then
        local refHeader = Header(1, 'References')
        add(getMetadata(metadata))
        add(toc())
        add(body)
        add('')
        add(refHeader)
        add('')
        add(getReferences())
    else
        add(getMetadata(metadata))
        add(toc())
        add(body)
    end

    return table.concat(buffer, '\n')
end

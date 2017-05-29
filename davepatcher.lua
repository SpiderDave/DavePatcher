-- 
--
--                      WARNING: SLOPPY CODE
--                 ABANDON HOPE ALL YE WHO ENTER HERE
--
-----------------------------------------------------------------------------

-- ToDo:
--   * Clean up variable and function names
--   * Clean up scope of variables
--   * Add more asm set formats
--   * Create example scripts
--   * Better control over writing to rom
--   * Create ips patches and other possible patch formats
--   * Better control when importing and exporting graphics:
--     + Export to image without overwriting image
--     + Set palette for each tilemap
--   * Allow comments and indentation everywhere
--   * Rework repeat so the repeated lines are evaluated for each iteration, not once
--   * Improve "find text" to include unknown characters
--   * Improve "find" to include unknown bytes
--   * Tilemap setting for precise placement or grid
--   * Allow textmap to be flexible for characters with multiple codes
--   * search for locations of tiles using images
--   * create gg codes
--   * comment code better
--   * test/handle writes and reads outside length of file
--   * allow patch addresses like 02:1200
--   * allow variable assignment to use strings with spaces in them

-- Notes:
--   * Keywords starting with _ are experimental or unfinished

local executionTime = os.clock()

table.unpack = table.unpack or unpack
local gd

-- let gd fail gracefully.
if not pcall(function()
    gd = require("gd")
end) then
    gd = false
end

require "os"
math.randomseed(os.time ()) math.random() math.random() math.random()

--local winapi = require("winapi")

version = version or {stage="",date="?",time="?"}

local patcher = {
    info = {
        name = "DavePatcher",
        version = string.format("v%s%s", version.date, version.stage),
        author = "SpiderDave",
        url = "https://github.com/SpiderDave/DavePatcher"
    },
    help={},
    startAddress=0,
    offset = 0,
    diffMax = 1000,
    gotoCount = 0,
    gotoLimit = 100,
    verbose = false,
    showAnnotations = true,
    interactive = false,
    prompt = "> ",
    tileMap={},
    results={
        index = 0
    },
    base = 16,
    smartSearch={},
    variables = {},
    autoRefresh = false,
    outputFileName = "output.nes",
    strict=false,
}

function patcher.getHeader(str)
    local str = str or patcher.fileData:sub(1,16)
    local header = {
        id=str:sub(1,1+4),
        prg_rom_size=string.byte(str:sub(1+4,1+4)),
        chr_rom_size=string.byte(str:sub(1+5,1+5)),
        flags6=string.byte(str:sub(6,6)),
        flags7=string.byte(str:sub(7,7)),
        prg_ram_size=string.byte(str:sub(8,8)),
        flags9=string.byte(str:sub(9,9)),
        flags10=string.byte(str:sub(10,10)),
        byte11=string.byte(str:sub(11,11)),
        byte12=string.byte(str:sub(12,12)),
        byte13=string.byte(str:sub(13,13)),
        byte14=string.byte(str:sub(14,14)),
        byte15=string.byte(str:sub(15,15)),
        str=str,
        valid = true,
    }
    
    if header.id~="NES"..string.byte(0x10) then header.valid=false end
    
    patcher.variables["CHRSTART"]=header.prg_rom_size*0x4000
    patcher.variables["CHRSIZE"]=header.chr_rom_size*0x2000
    return header
end

patcher.results.clear = function()
    for i=1,#patcher.results do
        patcher.results[i]=nil
    end
end

patcher.findHex = function(data)
    local address = 0
    local results = {}
    for i = 1,100 do
        address = patcher.fileData:find(hex2bin(data),address+1+patcher.offset, true)
        if address then
            if address>patcher.startAddress+patcher.offset then
                results[i]={address=address-1-patcher.offset}
            end
        else
            break
        end
    end
    if #results == 0 then return nil end
    return results
end

patcher.getHex = function(address, len)
    if type(address)=="string" then
        address = tonumber(address,16)
    end
    if type(len)=="string" then
        len = tonumber(len,16)
    end
    return bin2hex(patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len))
end


local util={}

function startsWith(haystack, needle)
  return string.sub(haystack, 1, string.len(needle)) == needle
end

--local condition = load_code("return " .. args.condition, context)

util.printf = function(s,...)
    --return io.write(s:format(...))
    return print(s:format(...))
end

util.stripSpaces = function(s)
    return string.gsub(s, "%s", "")
end

function util.trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function util.ltrim(s)
  return (s:gsub("^%s*", ""))
end
function util.rtrim(s)
  local n = #s
  while n > 0 and s:find("^%s", n) do n = n - 1 end
  return s:sub(1, n)
end

util.startsWith = startsWith

-- hint is a hint on how to format it
util.toNumber = function(s, hint)
    local n
    s=util.trim(s)
    if s=="_" then
        n=patcher.results[patcher.results.index].address
        patcher.results.index=patcher.results.index+1
    else
        n=tonumber(s,patcher.base)
    end
    return n
end

printf = util.printf

util.random = math.random

local asm={}

--      +---------------------+--------------------------+
--      |      mode           |     assembler format     |
--      +=====================+==========================+
--      | Immediate           |          #aa             |
--      | Absolute            |          aaaa            |
--      | Zero Page           |          aa              |   Note:
--      | Implied             |                          |
--      | Indirect Absolute   |          (aaaa)          |     aa = 2 hex digits
--      | Absolute Indexed,X  |          aaaa,X          |          as $FF
--      | Absolute Indexed,Y  |          aaaa,Y          |
--      | Zero Page Indexed,X |          aa,X            |     aaaa = 4 hex
--      | Zero Page Indexed,Y |          aa,Y            |          digits as
--      | Indexed Indirect    |          (aa,X)          |          $FFFF
--      | Indirect Indexed    |          (aa),Y          |
--      | Relative            |          aaaa            |     Can also be
--      | Accumulator         |          A               |     assembler labels
--      +---------------------+--------------------------+
      

--immediate: 2 bytes
--zeroPage: 2 bytes
--zeroPageX: 2 bytes
--absolute: 3 bytes
--absoluteX: 3 bytes
--absoluteY: 3 bytes
--indirect: 3 bytes (only used by jmp)
--indirectx: 2 bytes
--indirecty: 2 bytes
--accumulator: 1 byte

--http://e-tradition.net/bytes/6502/6502_instruction_set.html

-- #       immediate
-- a       absolute
-- r       relative
-- zp      zero page
-- ()      indirect
-- i       implied
-- A       accumulator
-- x       x register
-- y       y register

asm.key={
    ["#"]="immediate",
    ["a"]="absolute",
    ["r"]="relative",
    ["zp"]="zero page",
    ["()"]="indirect",
    ["i"]="implied",
    ["A"]="accumulator",
    ["x"]="x register",
    ["y"]="y register",

    ["ADC"]="add with carry",
    ["AND"]="and (with accumulator)",
    ["ASL"]="arithmetic shift left",
    ["BCC"]="branch on carry clear",
    ["BCS"]="branch on carry set",
    ["BEQ"]="branch on equal (zero set)",
    ["BIT"]="bit test",
    ["BMI"]="branch on minus (negative set)",
    ["BNE"]="branch on not equal (zero clear)",
    ["BPL"]="branch on plus (negative clear)",
    ["BRK"]="interrupt",
    ["BVC"]="branch on overflow clear",
    ["BVS"]="branch on overflow set",
    ["CLC"]="clear carry",
    ["CLD"]="clear decimal",
    ["CLI"]="clear interrupt disable",
    ["CLV"]="clear overflow",
    ["CMP"]="compare (with accumulator)",
    ["CPX"]="compare with X",
    ["CPY"]="compare with Y",
    ["DEC"]="decrement",
    ["DEX"]="decrement X",
    ["DEY"]="decrement Y",
    ["EOR"]="exclusive or (with accumulator)",
    ["INC"]="increment",
    ["INX"]="increment X",
    ["INY"]="increment Y",
    ["JMP"]="jump",
    ["JSR"]="jump subroutine",
    ["LDA"]="load accumulator",
    ["LDY"]="load X",
    ["LDY"]="load Y",
    ["LSR"]="logical shift right",
    ["NOP"]="no operation",
    ["ORA"]="or with accumulator",
    ["PHA"]="push accumulator",
    ["PHP"]="push processor status (SR)",
    ["PLA"]="pull accumulator",
    ["PLP"]="pull processor status (SR)",
    ["ROL"]="rotate left",
    ["ROR"]="rotate right",
    ["RTI"]="return from interrupt",
    ["RTS"]="return from subroutine",
    ["SBC"]="subtract with carry",
    ["SEC"]="set carry",
    ["SED"]="set decimal",
    ["SEI"]="set interrupt disable",
    ["STA"]="store accumulator",
    ["STX"]="store X",
    ["STY"]="store Y",
    ["TAX"]="transfer accumulator to X",
    ["TAY"]="transfer accumulator to Y",
    ["TSX"]="transfer stack pointer to X",
    ["TXA"]="transfer X to accumulator",
    ["TXS"]="transfer X to stack pointer",
    ["TYA"]="transfer Y to accumulator",
}

asm.set={
    [0x00]={opcode="brk", mode="i", length=1, format="BRK"},
    [0x01]={opcode="ora", mode="(zp,x)", length=2},
    [0x05]={opcode="ora", mode="zp", length=2},
    [0x06]={opcode="asl", mode="zp", length=2},
    [0x08]={opcode="php", mode="i", length=1, format="PHP"},
    [0x09]={opcode="ora", mode="#", length=2},
    [0x0a]={opcode="asl", mode="A", length=1},
    [0x0d]={opcode="ora", mode="a", length=3},
    [0x0e]={opcode="asl", mode="a", length=3},
    [0x10]={opcode="bpl", mode="r", length=2},
    [0x11]={opcode="ora", mode="(zp),y", length=2},
    
    [0x14]={opcode="jsr", mode="a", length=3},
    
    [0x15]={opcode="ora", mode="zp,x", length=2},
    [0x16]={opcode="asl", mode="zp,x", length=2},
    [0x18]={opcode="clc", mode="i", length=1},
    [0x19]={opcode="ora", mode="a,y", length=3},
    [0x1d]={opcode="ora", mode="a,x", length=3},
    [0x1e]={opcode="asl", mode="a,x", length=3},
    
    [0x20]={opcode="jsr", mode="a", length=3, format = "JSR $<2><1>"},
    
    [0x21]={opcode="and", mode="(zp,x)", length=2},
    [0x24]={opcode="bit", mode="zp", length=2},
    [0x25]={opcode="and", mode="zp", length=2},
    [0x26]={opcode="rol", mode="zp", length=2},
    [0x28]={opcode="rti", mode="i", length=1},
    [0x29]={opcode="and", mode="#", length=2},
    [0x2a]={opcode="rol", mode="A", length=1},
    [0x2c]={opcode="bit", mode="a", length=3},
    [0x2d]={opcode="and", mode="a", length=3},
    [0x2e]={opcode="rol", mode="a", length=3},
    [0x30]={opcode="bmi", mode="r", length=2, format = "BMI $+<1>"},
    [0x31]={opcode="and", mode="(zp),y", length=2},
    [0x35]={opcode="and", mode="zp,x", length=2},
    [0x36]={opcode="rol", mode="zp,x", length=2},
    [0x38]={opcode="sec", mode="i", length=1, format = "SEC"},
    [0x39]={opcode="and", mode="a,y", length=3},
    [0x3c]={opcode="rts", mode="i", length=1},
    [0x3d]={opcode="and", mode="a,x", length=3},
    [0x3e]={opcode="rol", mode="a,x", length=3},
    [0x41]={opcode="eor", mode="(zp,x)", length=2},
    [0x45]={opcode="eor", mode="zp", length=2},
    [0x46]={opcode="lsr", mode="zp", length=2},
    [0x48]={opcode="pha", mode="i", length=1},
    [0x49]={opcode="eor", mode="#", length=2},
    [0x4a]={opcode="lsr", mode="A", length=1, format = "LSR"},
    [0x4c]={opcode="jmp", mode="a", length=3},
    [0x4d]={opcode="eor", mode="a", length=3},
    [0x4e]={opcode="lsr", mode="a", length=3},
    [0x50]={opcode="bvc", mode="r", length=2},
    [0x51]={opcode="eor", mode="(zp),y", length=2},
    [0x55]={opcode="eor", mode="zp,x", length=2},
    [0x56]={opcode="lsr", mode="zp,x", length=2},
    [0x58]={opcode="cli", mode="i", length=1},
    [0x59]={opcode="eor", mode="a,y", length=3},
    [0x5d]={opcode="eor", mode="a,x", length=3},
    [0x5e]={opcode="lsr", mode="a,x", length=3},
    
    [0x60]={opcode="rts", mode="i", length=1, format="RTS ----"},
    
    [0x61]={opcode="adc", mode="(zp,x)", length=2},
    [0x65]={opcode="adc", mode="zp", length=2},
    [0x66]={opcode="ror", mode="zp", length=2},
    [0x68]={opcode="pla", mode="i", length=1},
    [0x69]={opcode="adc", mode="#", length=2},
    [0x6a]={opcode="ror", mode="A", length=1},
    [0x6c]={opcode="jmp", mode="(a)", length=3},
    [0x6d]={opcode="adc", mode="a", length=3},
    [0x6e]={opcode="ror", mode="a", length=3},
    [0x70]={opcode="bvs", mode="r", length=2},
    [0x71]={opcode="adc", mode="(zp),y", length=2},
    [0x75]={opcode="adc", mode="zp,x", length=2},
    [0x76]={opcode="ror", mode="zp,x", length=2},
    [0x78]={opcode="sei", mode="i", length=1},
    [0x79]={opcode="adc", mode="a,y", length=3},
    [0x7d]={opcode="adc", mode="a,x", length=3},
    [0x7e]={opcode="ror", mode="a,x", length=3},
    [0x81]={opcode="sta", mode="(zp,x)", length=2},
    [0x84]={opcode="sty", mode="zp", length=2},
    [0x85]={opcode="sta", mode="zp", length=2, format="sta $00<1>"},
    [0x86]={opcode="stx", mode="zp", length=2},
    [0x88]={opcode="dey", mode="i", length=1},
    [0x8a]={opcode="txa", mode="i", length=1},
    [0x8c]={opcode="sty", mode="a", length=3},
    [0x8d]={opcode="sta", mode="a", length=3},
    [0x8e]={opcode="stx", mode="a", length=3},
    [0x90]={opcode="bcc", mode="r", length=2},
    [0x91]={opcode="sta", mode="(zp),y", length=2},
    [0x94]={opcode="sty", mode="zp,x", length=2},
    [0x95]={opcode="sta", mode="zp,x", length=2},
    [0x96]={opcode="stx", mode="zp,y", length=2},
    [0x98]={opcode="tya", mode="i", length=1},
    [0x99]={opcode="sta", mode="a,y", length=3},
    [0x9a]={opcode="txs", mode="i", length=1},
    [0x9d]={opcode="sta", mode="a,x", length=3},
    [0xa0]={opcode="ldy", mode="#", length=2, format="ldy #$<1>"},
    [0xa1]={opcode="lda", mode="(zp,x)", length=2},
    [0xa2]={opcode="ldx", mode="#", length=2},
    [0xa4]={opcode="ldy", mode="zp", length=2},
    [0xa5]={opcode="lda", mode="zp", length=2, format = "lda $00<1>"},
    [0xa6]={opcode="ldx", mode="zp", length=2},
    [0xa8]={opcode="tay", mode="i", length=1},
    [0xa9]={opcode="lda", mode="#", length=2, format = "lda #$<1>"},
    [0xaa]={opcode="tax", mode="i", length=1},
    [0xac]={opcode="ldy", mode="a", length=3},
    [0xad]={opcode="lda", mode="a", length=3},
    [0xae]={opcode="ldx", mode="a", length=3},
    [0xb0]={opcode="bcs", mode="r", length=2},
    [0xb1]={opcode="lda", mode="(zp),y", length=2},
    [0xb4]={opcode="ldy", mode="zp,x", length=2},
    [0xb5]={opcode="lda", mode="zp,x", length=2},
    [0xb6]={opcode="ldx", mode="zp,y", length=2},
    [0xb8]={opcode="clv", mode="i", length=1},
    [0xb9]={opcode="lda", mode="a,y", length=3},
    [0xba]={opcode="tsx", mode="i", length=1},
    [0xbc]={opcode="ldy", mode="a,x", length=3},
    [0xbd]={opcode="lda", mode="a,x", length=3},
    [0xbe]={opcode="ldx", mode="a,y", length=3},
    [0xc0]={opcode="cpy", mode="#", length=2},
    [0xc1]={opcode="cmp", mode="(zp,x)", length=2},
    [0xc4]={opcode="cpy", mode="zp", length=2},
    [0xc5]={opcode="cmp", mode="zp", length=2},
    [0xc6]={opcode="dec", mode="zp", length=2},
    
    [0xc8]={opcode="iny", mode="i", length=1, format = "iny"},
    
    [0xc9]={opcode="cmp", mode="#", length=2},
    [0xca]={opcode="dex", mode="i", length=1, format="dex"},
    [0xcc]={opcode="cpy", mode="a", length=3},
    [0xcd]={opcode="cmp", mode="a", length=3},
    [0xce]={opcode="dec", mode="a", length=3},
    [0xd0]={opcode="bne", mode="r", length=2},
    [0xd1]={opcode="cmp", mode="(zp),y", length=2},
    [0xd5]={opcode="cmp", mode="zp,x", length=2},
    [0xd6]={opcode="dec", mode="zp,x", length=2},
    [0xd8]={opcode="cld", mode="i", length=1},
    [0xd9]={opcode="cmp", mode="a,y", length=3},
    [0xdd]={opcode="cmp", mode="a,x", length=3},
    [0xde]={opcode="dec", mode="a,x", length=3},
    [0xe0]={opcode="cpx", mode="#", length=2},
    [0xe1]={opcode="sbc", mode="(zp,x)", length=2},
    [0xe4]={opcode="cpx", mode="zp", length=2},
    [0xe5]={opcode="sbc", mode="zp", length=2},
    [0xe6]={opcode="inc", mode="zp", length=2},
    
    [0xe8]={opcode="inx", mode="i", length=1, format = "inx"},
    
    [0xe9]={opcode="sbc", mode="#", length=2, format = "SBC #$<1>"},
    [0xea]={opcode="nop", mode="i", length=1, format="nop"},
    [0xec]={opcode="cpx", mode="a", length=3},
    [0xed]={opcode="sbc", mode="a", length=3},
    [0xee]={opcode="inc", mode="a", length=3},
    [0xf0]={opcode="beq", mode="r", length=2},
    [0xf1]={opcode="sbc", mode="(zp),y", length=2},
    [0xf5]={opcode="sbc", mode="zp,x", length=2},
    [0xf6]={opcode="inc", mode="zp,x", length=2},
    [0xf8]={opcode="sed", mode="i", length=1},
    [0xf9]={opcode="sbc", mode="a,y", length=3},
    [0xfd]={opcode="sbc", mode="a,x", length=3},
    [0xfe]={opcode="inc", mode="a,x", length=2},
    ["default"]={opcode="", mode="", length=1, format="undefined"},
}


asm.print = function(s)
    local data = hex2bin(s)
    local out = ""
    local i = 1
    
    
    while true do
        local n = rawToNumber(data:sub(i,i))
        local s = asm.set[n] or asm.set.default
        
        for j = 1,3 do
            if j<= s.length then
                out = out .. string.format("%02x",rawToNumber(data:sub(i+j-1,i+j-1)))
            else
                out = out .. "  "
            end
        end
        
        --out = out .. string.format(" %s %s",s.opcode, s.mode)
        
        local f = ""
        if s.format then
            out = out .. " ("
            f = s.format
            f=string.gsub(f, "<1>",bin2hex(data:sub(i+1,i+1)))
            f=string.gsub(f, "<2>",bin2hex(data:sub(i+2,i+2)))
            out = out..f..")"
        else
            out = out .. string.format(" %s %s",s.opcode, s.mode)
        end
        out = out .. "\n"
        
        i=i+s.length
        if i>#data then break end
    end
    
    return out
end

patcher.asm = asm

--print("#  l  op  mode")
--for i=0,255 do
--    if asm.set[i] then
--        local o=asm.set[i]
--        printf("%02x %02x %s %s",i,o.length or -1, o.opcode,o.mode)
        --printf('[0x%02x]={opcode="%s", mode="%s", length=%1x},',i,o.opcode,o.mode,o.length)
--    end
--end

function util.split(s, delim, max)
  assert (type (delim) == "string" and string.len (delim) > 0,
          "bad delimiter")
  assert(max == nil or max >= 1)
  local start = 1
  local t = {}
  local nSplits = 0
  while true do
    if max then
        if nSplits>= max then break end
    end
    local pos = string.find (s, delim, start, true) -- plain find
    if not pos then
      break
    end
    nSplits=nSplits+1
    table.insert (t, string.sub (s, start, pos - 1))
    start = pos + string.len (delim)
  end
  table.insert (t, string.sub (s, start))
  return t
end

patcher.help.extra = "\nSome commands require Lua-GD https://sourceforge.net/projects/lua-gd/\n"
patcher.help.info = string.format("%s %s - %s %s",patcher.info.name,patcher.info.version,patcher.info.author,patcher.info.url)
patcher.help.description = "A custom patcher for use with NES romhacking or general use."
patcher.help.usage = [[
Usage: davepatcher [options...] <patch file> [<file to patch>]
       davepatcher [options...] -i <file to patch>

Options:
  -h          show help
  -commands   show commands
  -i          interactive mode
]]
patcher.help.interactive = [[Type "help" for this help, "commands" for more information or "break" to quit.]]
patcher.help.commands = [[
Lines starting with // are comments.
    
    // This is a comment
    
You can also do a comment at the end of a line:
    
    put 1200 a963 // set lives to 99
    
When comments are stripped, it will remove up to one space before the // 
automatically, so if you need whitespace in your command, add an extra 
space before the // like so:
    
    text 3400 FOOBAR  // set name to "FOOBAR "
    
Lines starting with # are "annotations"; Annotations are comments that are
shown in the output when running the patcher.
    
    # This is an annotation
    
Lines starting with : are labels.  See also "goto" keyword.
    
    :myLabel
    
You can use %variable% for variables to make replacements in a line:
    
    var foobar = fox
    var baz = dog
    # the quick brown %foobar% jumps over the lazy %baz%.
    
Keywords are lowercase, usually followed by a space.  Some "keywords" consist
of multiple words.  Possible keywords:

    help
    commands
        Show this help.  May be useful in interactive mode.
        
    load <file>
        Loads <file> and refreshes the data.
    
    file <file>
        Changes the file but does not refresh the data.
    
    outputfile <file>
        Sets the output file.  If not set, defaults to output.nes.
        
    get <address> <len>
        Display <len> bytes of data at <address>
    get hex <address> <len>
        (depreciated) same as get
    
    get asm <address> <len>
        Get <len> bytes of data at <address> and analyze using 6502 opcodes,
        display formatted asm data.
    
    print asm <data>
        Analyze hexidecimal data <data> using 6502 opcodes, display formatted
        asm data.
    
    put <address> <data>
        Set data at <address> to <data>.  <data> should be hexidecimal, and
        its length should be a multiple of 2.  You may include spaces in data
        for readability.
        Example:
            put a010 0001ff
    hex <address> <data>
        (depreciated) same as put
    
    fill <address> <count> <data>
        Fill the address at <address> with <data> repeated <count> times.
        
        Example:
            put a010 06 a900
            
        This is the same as:
            put a010 a900a900a900a900a900a900
    
    copy <address1> <address2> <length>
        Copies data from <address1> to <address2>.  The number of bytes is
        specified in hexidecimal by <length>.

        Example:
            copy a010 b010 0a
            
    copy hex <address1> <address2> <length>
        (depreciated) same as copy
        
    text <address> <text>
        Set data at <address> to <text>.  Use the textmap command to set a 
        custom format for the text.  If no textmap is set, ASCII is assumed.
        Example:
            text a010 FOOBAR
            
    find text <text>
        Find text data.  Use the textmap command to set a custom format for
        the text.  If no textmap is set, ASCII is assumed.
        Example:
            find text FOOBAR
            
    find <data>
        Find data in hexidecimal.  The length of the data must be a multiple
        of 2.
        Example:
            find 00ff1012
            
    find hex <data>
        (depreciated) same as find
        
    textmap <characters> <map to>
        Map text characters to specific values.  These will be used in other
        commands like the "text" command.
        Example:
            textmap ABCD 30313233
            
    textmap space <map to>
        Use this format to map the space character.
        Example:
            textmap space 00
            
    skip
    ...
    end skip
        skip this section.  You may put text after skip and end.
        Example:
        skip -------------
        // unstable
        put 10000 55
        end skip ---------
    
    break
        Use this to end the patch early.  Handy if you want to add some
        testing stuff at the bottom.
        
    goto <label>
        Go to the label <label>.
        Example:
            goto foobar
            :foobar
        
    start <address>
        Set the starting address for commands
        Example:
            start 10200
            find a901
            
    offset <address>
        Set the offset to use.  All addresses used and shown will be offset by
        this amount.  This is useful when the file contains a header you'd like
        to skip.
        Example:
            offset 10
            
    ips <file>
        apply ips patch to the file
    
    palette file <file>
        set the available NES palette via file
        Example:
            palette file FCEUX.pal
    
    palette <data>
        set the current 4-color palette from a hexidecimal string.
        Example:
            palette 0f182737
    
    export <address> <nTiles> <file>
        export tile data to png file.
        Example:
            export 20010 100 tiles.png
    
    import <address> <nTiles> <file>
        import tile data from png using current palette as a reference.
        Example:
            import 20010 100 tiles.png
            
    start tilemap <name>
    ...
    end tilemap
        Define a tile map to be used with the export map command.
        valid commands within the block are:
        
        address = <address>
            Set the address for the tile map.
        <tileNum> <x> <y> [h]
            Tile map entry.  "h" in the fourth field is used to optionally flip
            the tile horizontally.  In the future, other flags like "v" for
            vertical flipping will be used here as well.
        
        Example:
            start tilemap batman
            address = 2c000
            81 1 0 h
            82 2 0 h
            90 0 1 h
            91 1 1 h
            92 2 1 h
            a0 0 2 h
            a1 1 2 h
            a2 2 2 h
            b0 0 3 h
            b1 1 3 h
            b2 2 3 h
            end tilemap

    export map <tilemap> <file>
        export tile data to png file using a tile map.
        Example:
            export map batman batman_sprite_test.png
    
    import map
        import tile data from png file using a tile map
        Example:
            import map batman batman_sprite_test.png
    
    gg <gg code> [anything]
        decode and apply a NES Game Genie code.  If there is a space after the
        code you may add whatever text you like, as a convenience.
        Example:
            gg SZNZVOVK        Infinite bombs
        
    refresh
        refreshes the data so that keywords like "find text" will use the new
        altered data.
    
    refresh auto
        automatically refresh the data after each change.
    
    refresh manual
        do not automatically refresh the data after each change.  Use "refresh"
        command manually.
        
    code
        Execute Lua code
        Example:
            code print("Hello World!")
        
    eval
        Evaluate Lua expression and print the result
        Examples:
            eval "Hello World!"
            eval 5+5*2^10
        
    verbose [on | off]
        Turn verbose mode on or off.  This prints more information when using
        various commands.  If verbose is used without a parameter, off is
        assumed.
        
    diff <file>
        Show differences between the current file and <file>
    
    repeat <n>
    ...
    end repeat
        Repeat the lines in the block <n> times.
    
    var <var name> = <string>
        A basic variable assignment.  Currently you can only assign a string
        value.  You may also do variable assignment without using "var" if
        not in strict mode.
    
    if <var>==<string>
    ...
    else
    ...
    end if
        A basic if,else,end if block.  "else" is optional, and it's very 
        limited.  Can not be nested currently, only comparison with string
        is supported.
    
    include <file>
        include another patch file as if it were inserted at this line.
    
    strict [on | off]
        Turn strict mode on or off.  If strict is used without a parameter, on is
        assumed.  In strict mode:
        * "var" keyword is required for variable assignment.
        * break on all warnings.

]]

printVerbose = function(s, ...)
    if patcher.verbose then
        return print(s:format(...))
    end
end

patcher.colors={[0]=0x0f,0x0c,0x1c,0x3c}
patcher.palette={[0]=
{0x74,0x74,0x74},
{0x24,0x18,0x8c},
{0x00,0x00,0xa8},
{0x44,0x00,0x9c},
{0x8c,0x00,0x74},
{0xa8,0x00,0x10},
{0xa4,0x00,0x00},
{0x7c,0x08,0x00},
{0x40,0x2c,0x00},
{0x00,0x44,0x00},
{0x00,0x50,0x00},
{0x00,0x3c,0x14},
{0x18,0x3c,0x5c},
{0x00,0x00,0x00},
{0x00,0x00,0x00},
{0x00,0x00,0x00},
{0xbc,0xbc,0xbc},
{0x00,0x70,0xec},
{0x20,0x38,0xec},
{0x80,0x00,0xf0},
{0xbc,0x00,0xbc},
{0xe4,0x00,0x58},
{0xd8,0x28,0x00},
{0xc8,0x4c,0x0c},
{0x88,0x70,0x00},
{0x00,0x94,0x00},
{0x00,0xa8,0x00},
{0x00,0x90,0x38},
{0x00,0x80,0x88},
{0x00,0x00,0x00},
{0x00,0x00,0x00},
{0x00,0x00,0x00},
{0xfc,0xfc,0xfc},
{0x3c,0xbc,0xfc},
{0x5c,0x94,0xfc},
{0xcc,0x88,0xfc},
{0xf4,0x78,0xfc},
{0xfc,0x74,0xb4},
{0xfc,0x74,0x60},
{0xfc,0x98,0x38},
{0xf0,0xbc,0x3c},
{0x80,0xd0,0x10},
{0x4c,0xdc,0x48},
{0x58,0xf8,0x98},
{0x00,0xe8,0xd8},
{0x78,0x78,0x78},
{0x00,0x00,0x00},
{0x00,0x00,0x00},
{0xfc,0xfc,0xfc},
{0xa8,0xe4,0xfc},
{0xc4,0xd4,0xfc},
{0xd4,0xc8,0xfc},
{0xfc,0xc4,0xfc},
{0xfc,0xc4,0xd8},
{0xfc,0xbc,0xb0},
{0xfc,0xd8,0xa8},
{0xfc,0xe4,0xa0},
{0xe0,0xfc,0xa0},
{0xa8,0xf0,0xbc},
{0xb0,0xfc,0xcc},
{0x9c,0xfc,0xf0},
{0xc4,0xc4,0xc4},
{0x00,0x00,0x00},
{0x00,0x00,0x00},
}

util.sandbox = {}

util.sandbox.context = {
    string=string,
    table=table,
    print=print,

    math=math,
    min = math.min,
    max = math.max,
    abs = math.abs,
    exp = math.exp,
    log = math.log,
    sin = math.sin,
    atan2 = math.atan2,
    cos = math.cos,
    
    util=util,
    patcher=patcher,
}

util.sandbox.loadCode = function(self, code)
    environment = self.context
    if setfenv and loadstring then
        local f = assert(loadstring(code))
        setfenv(f,environment)
        return f
    else
        return assert(load(code, nil,"t",environment))
    end
end

function quit(text,...)
  if text then printf(text,...) end
  os.exit()
end

function err(text,...)
    quit("Error: "..text,...)
end

function warning(text,...)
    if text then printf("Warning: "..text,...) end
    -- Does not exit unless strict mode
    if patcher.strict ==true then
        os.exit()
    end
end

function getfilecontents(path)
    local file = io.open(path,"rb")
    if file==nil then return nil end
    io.input(file)
    ret=io.read("*a")
    io.close(file)
    return ret
end

local patch = {
    file = "patch.txt",
    index = 1,
    includeCount = 0,
    includeLimit = 20,
}

function patch.load(file)
    local lines = {}
    file = file or patch.file
    for line in io.lines(file) do
        if string.find(line," //") then
            -- remove comments with a space before them
            line = string.sub(line, 1, string.find(line," //") -1)
        end
        if string.find(line,"//") then
            -- remove comments
            line = string.sub(line, 1, string.find(line,"//") -1)
        end
        
        -- variable replacement
--        for k,v in pairs(patcher.variables) do
--            if type(v) == "number" then
--                v = string.format("%x",v)
--            end
--            line = string.gsub(line, "%%"..k.."%%", v)
--        end
        
        if util.trim(line or "") == "" then
            --ignore empty lines
        elseif util.split(line," ",1)[1] == "include" then
            patch.includeCount = patch.includeCount + 1
            if patch.includeCount > patch.includeLimit then
                err("patch include limit exceeded.")
            end
            local f = util.split(line," ",1)[2]
            local l = patch.load(f)
            for i = 1,#l do
                lines[#lines + 1] = l[i]
            end
        else
            lines[#lines + 1] = line
        end
    end
    patch.lines = lines
    return lines
end

function patch.readLine()
    if patch.index > # patch.lines then return nil end

    local line = patch.lines[patch.index]
    line = util.ltrim(line)
    
    -- variable replacement
    for k,v in pairs(patcher.variables) do
        if type(v) == "number" then
            v = string.format("%x",v)
        end
        line = string.gsub(line, "%%"..k.."%%", v)
    end

    patch.index = patch.index + 1

    return line
end


function setfilecontents(file, data)
    local f,err = io.open(file,"w")
    if err then print(err) end
    if not f then return nil end
    f:write(data)
    f:close()
    return true
end

function util.fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

-- Write data to patcher.newFileData
function patcher.write(address, data)
    patcher.newFileData = patcher.newFileData:sub(1,address) .. data .. patcher.newFileData:sub(address+#data+1)
    if patcher.autoRefresh == true then
        patcher.fileData = patcher.newFileData
    end
end

function util.writeToFile(file,address, data)
    if not util.fileExists(file) then
        local f=io.open(file,"w")
        f:close()
    end
    if not data then return nil end
    local f = io.open(file,"r+b")
    if not f then return nil end
    f:seek("set",address)
    f:write(data)
    f:close()
    return true
end

function bin2hex(str)
    local output = ""
    for i = 1, #str do
        local c = string.byte(str:sub(i,i))
        output=output..string.format("%02x", c)
    end
    return output
end

function hex2bin(str)
    local output = ""
    for i = 1, (#str/2) do
        local c = str:sub(i*2-1,i*2)
        output=output..string.char(tonumber(c, 16))
    end
    return output
end

function rawToNumber(d)
    -- msb first
    local v = 0
    for i=1,#d do
        v = v * 256
        v = v + d:sub(i,i):byte()
    end
    return v
end


function makepointer(addr,returnbinary)
    local a,p,pbin
    returnbinary=returnbinary or nil
    a=string.format("%08X",addr)
    p=string.sub(a,7,8)..string.sub(a,5,6).."4"..string.sub(a,4,4)..string.sub(a,1,2)
    pbin=hex2bin(p)
    p=tonumber(p,16)
    if returnbinary then return pbin else return p end
end

function mapText(txt, reverse)
    if not textMap then return txt end
    
    local txtNew=""
    if reverse==true then
        for i=1,#txt do
            local c=txt:sub(i,i)
            local found=false
            for k,v in pairs(textMap) do
                if v==c then
                    txtNew=txtNew..k
                    found=true
                    break
                end
            end
            if found==false then txtNew=txtNew.."?" end
        end
        return txtNew
    end
    
    
    
    for i=1,#txt do
        local c=txt:sub(i,i)
        if textMap[c] then
            txtNew=txtNew..textMap[c]
        else
            txtNew=txtNew..c
        end
    end
    return txtNew
end

bit = {}
bit.OR, bit.XOR, bit.AND = 1, 3, 4

function bit.oper(a, b, oper)
   local r, m, s = 0, 2^52
   repeat
      s,a,b = a+b+m, a%m, b%m
      r,m = r + m*oper%(s-a-b), m/2
   until m < 1
   return r
end

function bit.isSet(n,b)
    if n==bit.oper(n,2^b,bit.OR) then
        return true
    else
        return false
    end
end

function imageToTile(len, fileName)
    local out = {
        t={}
    }
    
    local nTiles = len/16
    
    local image = gd.createFromPng(fileName)
    local h = math.max(8,math.floor(nTiles/16)*8)
    local w = math.min(16, nTiles)*8
    local colors={}
    for i=0,3 do
        --print(string.format("%02x %02x %02x",table.unpack(nesPalette[colors[i]])))
        colors[i]=image:colorAllocate(table.unpack(patcher.palette[patcher.colors[i]]))
    end
    local xo=0
    local yo=0
    
    local pr,pg,pb = table.unpack(patcher.palette[patcher.colors[3]])
    for t=0,nTiles-1 do
        out.t[t] = {}
        for y = 0, 7 do
            out.t[t][y] = 0
            out.t[t][y+8] = 0
            --local byte = string.byte(tileData:sub(t*16+y+1,t*16+y+1))
            --local byte2 = string.byte(tileData:sub(t*16+y+9,t*16+y+9))
            for x=0, 7 do
                local c=0
                --if bit.isSet(byte,7-x)==true then c=c+1 end
                --if bit.isSet(byte2,7-x)==true then c=c+2 end
                local c = image:getPixel(x+xo,y+yo)
                local r,g,b=image:red(c),image:green(c),image:blue(c)
                
                for i=0,3 do
                    local pr,pg,pb = table.unpack(patcher.palette[patcher.colors[i]])
                    if string.format("%02x%02x%02x",r,g,b) == string.format("%02x%02x%02x",pr,pg,pb) then
                        --io.write("*")
                        --out.t[t][y*8+x]=i % 2
                        --out.t[t][y*8+x+8]=math.floor(i / 2)
                        out.t[t][y]=out.t[t][y] + (2^(7-x)) * (i%2)
                        out.t[t][y+8]=out.t[t][y+8] + (2^(7-x)) * (math.floor(i/2))
                    end
                end
                
                --print(string.format("%02x (%02x,%02x) %02x%02x%02x  %02x%02x%02x",t, x,y, r,g,b,  pr,pg,pb))
            end
        end
        xo=xo+8
        if xo>=w then
            xo=0
            yo=yo+8
        end
        --io.write("\n")
    end
    local tileData = ""
    for t=0,nTiles-1 do
        for i=0,#out.t[t] do
            tileData = tileData .. string.char(out.t[t][i])
        end
    end
    return tileData
end

function imageToTile2(tileMap, fileName)
    local tm=patcher.tileMap[tileMap]
    local out = {
        t={},
        th={},
        pos={},
    }
    
    --local nTiles = len/16
    nTiles=32*32
    
    local image = gd.createFromPng(fileName)
    local h = math.max(8,math.floor(nTiles/16)*8)
    local w = math.min(16, nTiles)*8
    h=256
    w=256

    local colors={}
    for i=0,3 do
        --print(string.format("%02x %02x %02x",table.unpack(nesPalette[colors[i]])))
        colors[i]=image:colorAllocate(table.unpack(patcher.palette[patcher.colors[i]]))
    end
    local xo=0
    local yo=0
    
    local pr,pg,pb = table.unpack(patcher.palette[patcher.colors[3]])
    for t=0,nTiles-1 do
        out.t[t] = {}
        for y = 0, 7 do
            out.t[t][y] = 0
            out.t[t][y+8] = 0
            for x=0, 7 do
                local c = image:getPixel(x+xo,y+yo) or 0
                local r,g,b=image:red(c),image:green(c),image:blue(c)
                for i=0,3 do
                    local pr,pg,pb = table.unpack(patcher.palette[patcher.colors[i]])
                    if string.format("%02x%02x%02x",r,g,b) == string.format("%02x%02x%02x",pr,pg,pb) then
                        out.t[t][y]=out.t[t][y] + (2^(7-x)) * (i%2)
                        out.t[t][y+8]=out.t[t][y+8] + (2^(7-x)) * (math.floor(i/2))
                    end
                end
                --print(string.format("%02x (%02x,%02x) %02x%02x%02x  %02x%02x%02x",t, x,y, r,g,b,  pr,pg,pb))
            end
        end
        xo=xo+8
        if xo>=w then
            xo=0
            yo=yo+8
        end
    end

    local tileData = ""
    local tileData = {} --It's an array here, because it's not guaranteed to be a continuous string of data; it can have gaps.
    
    -- Iterate the tilemap
    for i=1,#tm do
        tileData[i]={}
        
        t=tm[i].tileNum
        local o=""
        if tm[i].flip.vertical then
            for j=7,0,-1 do
                o=o..string.char(out.t[tm[i].y*w/8+tm[i].x][j])
            end
            for j=15,8,-1 do
                o=o..string.char(out.t[tm[i].y*w/8+tm[i].x][j])
            end
        elseif tm[i].flip.horizontal then
            for j=0,#out.t[t] do
                local b=out.t[tm[i].y*w/8+tm[i].x][j]
                local b2=0
                for jj=0,7 do
                    if bit.isSet(b, 7-jj) then
                        b2=b2+2^jj
                    end
                end
                o=o..string.char(b2)
            end
        else
            for j=0,#out.t[t] do
                o=o..string.char(out.t[tm[i].y*w/8+tm[i].x][j])
            end
        end
        
        
        
        
        tileData[i].t = o                           -- the tile data for this tile to be applied
        tileData[i].address = tm[i].address + t*16  -- the address to apply it to
        --printf("tileNum=%02x %02x,",t,tileData[i].address)
        --printf("tilemap index=%02x tileNum=%02x pos=(%02x,%02x) %04x %s",i, t, tm[i].x, tm[i].y, tileData[i].address, bin2hex(tileData[i].t))
    end
    
    return tileData
end

function tileToImage(tileData, fileName)
    local nTiles = #tileData/16
    
    local h = math.max(8,math.floor(nTiles/16)*8)
    local w = math.min(16, nTiles)*8
    local image=gd.createTrueColor(w,h)
    local colors={}
    for i=0,3 do
        --print(string.format("%02x %02x %02x",table.unpack(nesPalette[colors[i]])))
        colors[i]=image:colorAllocate(table.unpack(patcher.palette[patcher.colors[i]]))
    end
    local xo=0
    local yo=0
    for t=0,nTiles-1 do
        for y = 0, 7 do
            local byte = string.byte(tileData:sub(t*16+y+1,t*16+y+1))
            local byte2 = string.byte(tileData:sub(t*16+y+9,t*16+y+9))
            for x=0, 7 do
                local c=0
                if bit.isSet(byte,7-x)==true then c=c+1 end
                if bit.isSet(byte2,7-x)==true then c=c+2 end
                image:setPixel(x+xo,y+yo,colors[c])
            end
        end
        xo=xo+8
        if xo>=w then
            xo=0
            yo=yo+8
        end
    end
    image:png(fileName)
end

function tileToImage2(tileMap, fileName)
    local tm=patcher.tileMap[tileMap]
    h=256
    w=256
    local image=gd.createTrueColor(w,h)
    local colors={}
    for i=0,3 do
        --print(string.format("%02x %02x %02x",table.unpack(nesPalette[colors[i]])))
        colors[i]=image:colorAllocate(table.unpack(patcher.palette[patcher.colors[i]]))
    end
    local xo=0
    local yo=0
    
    local tileData = ""
    for i=1,#tm do
        local address = tm[i].address + tm[i].tileNum*16
        local len = 16
        tileData = patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
        --printf("address=%08x tileData=%s",address, bin2hex(tileData))
        --tm[#tm+1]={address=address, tileNum=tileNum, x=x,y=y}
        for y = 0, 7 do
            local byte = string.byte(tileData:sub(y+1,y+1))
            local byte2 = string.byte(tileData:sub(y+9,y+9))
            for x=0, 7 do
                local c=0
                if bit.isSet(byte,7-x)==true then c=c+1 end
                if bit.isSet(byte2,7-x)==true then c=c+2 end
                xo=tm[i].x*8+tm[i].adjust.x or 0
                yo=tm[i].y*8+tm[i].adjust.y or 0
                if tm[i].flip.horizontal then
                    image:setPixel(7-x+xo,y+yo,colors[c])
                else
                    image:setPixel(x+xo,y+yo,colors[c])
                end
            end
        end
        --printf("tilemap index=%02x tileNum=%02x pos=(%02x,%02x) %02x %s",i,tm[i].tileNum, tm[i].x,tm[i].y,address,bin2hex(tileData))
    end
    image:png(fileName)
end


if arg[1]=="-readme" then
    if (util.writeToFile("README.md",0,"```\n"..patcher.help.info .."\n".. patcher.help.description .."\n\n"..patcher.help.extra.."\n\n".. patcher.help.commands.."\n```")) then
        print("README updated")
    else
        quit("Error: README update failed.")
    end
    quit()
end

if arg[1]=="-commands" then
    print(patcher.help.info)
    print(patcher.help.description)
    print(patcher.help.commands)
    quit()
end

if arg[1]=="-?" or arg[1]=="/?" or arg[1]=="/help" or arg[1]=="/h" or arg[1]=="-h" then
    print(patcher.help.info)
    print(patcher.help.description)
    print(patcher.help.usage)
    quit()
end

if not arg[1] or arg[3] then
    print(patcher.help.info)
    print(patcher.help.description)
    print(patcher.help.usage)
    quit()
end

if arg[2] then
    patcher.fileName = arg[2]
    printVerbose(string.format("file: %s",patcher.fileName))
    patcher.fileData = getfilecontents(patcher.fileName)
    patcher.newFileData = patcher.fileData
    patcher.header = patcher.getHeader()
end

if arg[1] == "-i" then
    patcher.interactive = true
    print(patcher.help.info)
    print(patcher.help.interactive)
end

file_dumptext = nil

if not patcher.interactive==true then
    patch.load(arg[1] or "patch.txt")
    print(patcher.help.info)
end
local breakLoop = false
while true do
    local writeToFile = util.writeToFile
    local line
    if patcher.interactive==true then
        io.write(patcher.prompt)
        line = io.stdin:read("*l")
    else
        line = patch.readLine()
    end
    if line == nil then break end
    local status, err = pcall(function()
    
    local keyword, data = unpack(util.split(line," ",1))
    local assignment = false
    
    keyword=keyword:lower()
    
    if #util.split(line, "=",1)>1  then
        local k, d = unpack(util.split(line,"=",1))
        k = util.trim(k)
        if #util.split(k, " ",1)==1 then
            keyword = k
            data = d
            assignment = true
        end
    end
    
    
    
    patcher.lineQueue={}
    if keyword == "repeat" then
        patcher.lineQueue.r = util.toNumber(data)
        printf("repeat %02x",patcher.lineQueue.r)
        while true do
            line = patch.readLine()
            keyword,data = unpack(util.split(line," ",1))
            keyword=keyword:lower()
            --if keyword == "end repeat" then break end
            if startsWith(line, "end repeat") then break end
            patcher.lineQueue[#patcher.lineQueue+1]={line=line,keyword=keyword,data=data}
        end
    end
    
    --for loopCount = 1,lineQueue.count or 1 do
    local lineRepeat, r
    for lineRepeat = 1, patcher.lineQueue.r or 1 do
    for r=1,math.max(#patcher.lineQueue, 1) do
        if #patcher.lineQueue>=1 then
            line=patcher.lineQueue[r].line
            keyword,data=patcher.lineQueue[r].keyword,patcher.lineQueue[r].data
        end
        
        if startsWith(line, "#") then
            if patcher.showAnnotations or patcher.verbose then
                print(string.sub(line,1))
            end
        elseif startsWith(line, "//") then
            -- comment
        elseif startsWith(line, "verbose off") then
            patcher.verbose = false
            print("verbose off")
        elseif startsWith(line, "verbose on") or line == "verbose" then
            patcher.verbose = true
            print("verbose on")
        elseif keyword == "strict" then
            data = util.trim(data or "on")
            if data == "on" or data == "" then
                patcher.strict = true
                print("strict mode on")
            elseif data == "off" then
                patcher.strict = false
                print("strict mode off")
            else
                err("invalid strict mode %s",data)
            end
        elseif keyword == "test" then
            print("")
            local lines = patch.load("patch.txt")
            for k,v in pairs(lines) do
              printf("line[%02x] [%s]",k,v)
            end
            print("")
        elseif keyword == "help" then
            print(patcher.help.interactive)
        elseif keyword == "commands" then
            print(patcher.help.commands)
--        elseif keyword == "replace" then
--            print(patcher.lastFound or "none")
        elseif keyword == "_corrupt" then
            local address = util.random(1,#patcher.fileData-patcher.offset)
            local len = 1
            local oldData=bin2hex(patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len))
            local newData = bin2hex(string.char(util.random(255)))
            
            printf("Corrupting data at 0x%08x: %s --> %s",address, oldData, newData)
            patcher.write(address+patcher.offset,hex2bin(newData))
            --if not writeToFile(patcher.fileName, address+patcher.offset,hex2bin(newData)) then err("Could not write to file.") end
        elseif startsWith(line:lower(), "_smartsearch lives ") then
            --search for a9xx8dyyyy (xx is given number of, yyyy is memory location we'll save for later)
            --search for ceyyyy for each result (ce is decrement, yyyy is the memory location we just found)
            --search for eeyyyy for each result (ce is increment, yyyy is the memory location we just found)
            -- The assumption here is that there's going to be a way to get more lives in any game (item, points, etc)
            
            -- Alternate:
            --search for a9xx85yy (xx is given number of, 00yy is memory location we'll save for later)
            --search for c6yy for each result (c6 is decrement, 00yy is the memory location we just found)
            --search for e6yy for each result (e6 is increment, 00yy is the memory location we just found)
            
            local data = string.sub(line,20)
            local nLives = util.split(data, " ")[1]
            local can_increase = util.split(data, " ", 1)[2]
            can_increase = can_increase:lower()
            
--            printf("nLives = [%s]",nLives)
--            printf("can_increase = [%s]",can_increase)
            
            if can_increase == "true" then
                can_increase = true
            elseif can_increase == "false" then
                can_increase = false
            else
                err('unknown smartsearch parameter: "%s".', can_increase)
            end
            
            printf("* * * Smart search * * *")
            printf("Searching for lives (Starting lives = %s, can increase = %s):", nLives, can_increase and "true" or "false")
            
            local methods = {}
            --methods[1] = {"a9%s8d",2,"ce%s","ee%s",can_increase, "put %04x eaeaea"}
            --methods[2] = {"a9%s85",1,"c6%s","e6%s",can_increase, "put %04x eaea"}
            methods[1] = {"a9%s8d",2,"ce%s","ee%s",can_increase, "put %x ad"}
            methods[2] = {"a9%s85",1,"c6%s","e6%s",can_increase, "put %x a5"}
            --methods[3] = {"a9%s85",1,"ce%s","ee%s"}
            
            --printf("can_increase = %s",can_increase and "true" or "false")
            
            print("Possible infinite lives parameters:")
            for method = 1, #methods do
                --printf("method %s: ",method)
                local data = string.format(methods[method][1], nLives)
                
                local results = patcher.findHex(data)
                local results2={}
                local results2_flags = {} -- this is to help with duplicates
                for i=1, #results do
                    local a = patcher.getHex(results[i].address+3, methods[method][2])
                    --printf("test 0x%08x %s",results[i].address, a)
                    if results2_flags[a] or (a=="00" or a=="01" or a=="02") then
                    else
                        results2_flags[a]= true
                        results2[#results2+1] = a
                    end
                end
                
                --printf("nresults2 %s",#results2)
                
                local results3 = {}
                for i = 1, #results2 do
                    --if patcher.findHex(string.format(methods[method][3],results2[i])) and patcher.findHex(string.format(methods[method][4],results2[i])) then
                    if patcher.findHex(string.format(methods[method][3],results2[i])) and ((not not patcher.findHex(string.format(methods[method][4],results2[i])))==methods[method][5]) then
                        --printf(methods[method][3],results2[i])
                        local r = patcher.findHex(string.format(methods[method][3],results2[i]))
                        for j=1,#r do
                            results3[#results3+1]=r[j].address
                        end
                    end
                end
                if #results3>0 then
                    printf("\n//method %s: ",method)
                end
                for i=1,#results3 do
                    local v = ""
                    for jj=methods[method][2],1,-1 do
                        v = v..patcher.getHex(results3[i]+jj,1)
                    end
                    printf("//RAM address: %s",v)
                    printf(methods[method][6],results3[i])
                end
            end
            printf("")
        --elseif startsWith(line:lower(), "replace hex ") then
        elseif keyword == "replace" then
            
            if util.split(util.ltrim(data), " ",1)[1]=="hex" then
                data = util.split(util.ltrim(data), " ",1)[2]
                warning('depreciated keyword "replace hex". use "replace" instead')
            end
            data = util.ltrim(data)
            
            --local data=string.sub(line,13)
            local address=0
            local findValue = util.split(data," ")[1]
            local replaceValue = util.split(data," ")[2]
            
            local nResults = 0
            local limit = 50
            if util.split(data, " ")[3] then
                limit = tonumber(util.split(data, " ")[3],16)
            end
            
            print(string.format("Find and replace hex: %s --> %s (limit %s)",findValue, replaceValue, limit))
            patcher.results.clear()
            
            while true do
            --for i=1,50 do
                address = patcher.fileData:find(hex2bin(findValue),address+1+patcher.offset, true)
                if address then
                    if address>patcher.startAddress+patcher.offset then
                        print(string.format("    %s Found at 0x%08x, replacing with %s",findValue,address-1-patcher.offset,replaceValue))
                        patcher.write(address-1,hex2bin(replaceValue))
                        --if not writeToFile(patcher.fileName, address-1,hex2bin(replaceValue)) then err("Could not write to file.") end
                        patcher.results[#patcher.results+1]={address=address-1-patcher.offset}
                        nResults = nResults + 1
                        if nResults >= limit then break end
                    end
                else
                    break
                end
            end
            patcher.results.index = 1
            if #patcher.results > 0 then
                patcher.lastFound = patcher.results[1].address
            else
                patcher.lastFound = nil
            end
        elseif startsWith(line:lower(), "get asm ") then
            local data=string.sub(line,9)

            local address = data:sub(1,(data:find(" ")))
            address = util.toNumber(address, 16)
            
            local len = data:sub((data:find(" ")+1))
            len = util.toNumber(len, 16)

            local hexData=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            hexData=bin2hex(hexData)
            
            print(string.format("Analyzing data at 0x%08x:\n[%s]",address, hexData))
            print(asm.print(hexData))
        elseif startsWith(line:lower(), "print asm ") then
            hexData=string.sub(line,11)
            
            print(string.format("Analyzing ASM data:\n[%s]",hexData))
            print(asm.print(hexData))
        elseif startsWith(line:lower(), "get hex ") then
            warning('depreciated keyword "get hex". use "get" instead')
            local data=string.sub(line,9)

            local address = data:sub(1,(data:find(" ")))
            address = tonumber(address, 16)
            
            local len = data:sub((data:find(" ")+1))
            len = tonumber(len, 16)

            local old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            old=bin2hex(old)
            
            print(string.format("Hex data at 0x%08x: %s",address, old))
        elseif keyword == "get" then
            local data=string.sub(line,5)

            local address = data:sub(1,(data:find(" ")))
            address = util.toNumber(address)
            
            local len = data:sub((data:find(" ")+1))
            len = util.toNumber(len)

            local old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            old=bin2hex(old)
            
            print(string.format("Hex data at 0x%08x: %s",address, old))
        elseif startsWith(line, "find text ") then
            local txt=string.sub(line,11)
            address=0
            print(string.format("Find text: %s",txt))
            for i=1,10 do
                address = patcher.fileData:find(mapText(txt),address+1+patcher.offset, true)
                if address then
                    if address>patcher.startAddress+patcher.offset then
                        print(string.format("    %s Found at 0x%08x",txt,address-1-patcher.offset))
                    end
                else
                    if i==1 then
                        print "    Not found."
                    end
                    break
                end
            end
        elseif startsWith(line:lower(), "get text ") then
            local data=string.sub(line,10)
            local address = data:sub(1,(data:find(" ")))
            address = tonumber(address, 16)
            local len = data:sub((data:find(" ")+1))
            len = tonumber(len, 16)
            
            local old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            --old=bin2hex(old)
            
            print(string.format("Hex data at 0x%08x: %s",address,mapText(old,true)))
        --elseif startsWith(line:lower(), "find hex ") then
        elseif keyword == "find" then
            if util.split(util.ltrim(data), " ",1)[1]=="hex" then
                data = util.split(util.ltrim(data), " ",1)[2]
                warning('depreciated keyword "find hex". use "find" instead')
            end
            
            address=0
            print(string.format("Find hex: %s",data))
            data = util.stripSpaces(data)
            patcher.results.clear()
            
            local nResults = 0
            local limit = 50
            while true do
            --for i=1,50 do
                address = patcher.fileData:find(hex2bin(data),address+1+patcher.offset, true)
                if address then
                    if address>patcher.startAddress+patcher.offset then
                        print(string.format("    %s Found at 0x%08x",data,address-1-patcher.offset))
                        patcher.results[#patcher.results+1]={address=address-1-patcher.offset}
                        nResults = nResults + 1
                        if nResults >= limit then break end
                    end
                else
                    break
                end
            end
            patcher.results.index = 1
            if #patcher.results > 0 then
                patcher.lastFound = patcher.results[1].address
            else
                patcher.lastFound = nil
            end
        --elseif keyword == "fontdata" then
            --local font = {"33":[0,0,0,0,0,8,8,8,8,8,0,8,0,0,0,0],"34":[0,0,0,0,0,20,20,0,0,0,0,0,0,0,0,0],"35":[0,0,0,0,0,0,40,124,40,40,124,40,0,0,0,0],"36":[0,0,0,0,16,56,84,20,56,80,84,56,16,0,0,0],"37":[0,0,0,0,0,264,148,72,32,144,328,132,0,0,0,0],"38":[0,0,0,0,0,48,72,48,168,68,196,312,0,0,0,0],"39":[0,0,0,0,0,8,8,0,0,0,0,0,0,0,0,0],"40":[0,0,0,0,0,8,4,4,4,4,4,8,0,0,0,0],"41":[0,0,0,0,0,4,8,8,8,8,8,4,0,0,0,0],"42":[0,0,0,0,32,168,112,428,112,168,32,0,0,0,0,0],"43":[0,0,0,0,0,0,16,16,124,16,16,0,0,0,0,0],"44":[0,0,0,0,0,0,0,0,0,0,24,24,16,8,0,0],"45":[0,0,0,0,0,0,0,0,60,0,0,0,0,0,0,0],"46":[0,0,0,0,0,0,0,0,0,0,24,24,0,0,0,0],"47":[0,0,0,0,0,16,16,8,8,8,4,4,0,0,0,0],"48":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"49":[0,0,0,0,0,8,8,8,8,8,8,8,0,0,0,0],"50":[0,0,0,0,0,24,36,32,16,8,4,60,0,0,0,0],"51":[0,0,0,0,0,24,36,32,24,32,36,24,0,0,0,0],"52":[0,0,0,0,0,32,36,36,60,32,32,32,0,0,0,0],"53":[0,0,0,0,0,60,4,4,24,32,36,24,0,0,0,0],"54":[0,0,0,0,0,24,36,4,28,36,36,24,0,0,0,0],"55":[0,0,0,0,0,60,32,32,16,8,8,8,0,0,0,0],"56":[0,0,0,0,0,24,36,36,24,36,36,24,0,0,0,0],"57":[0,0,0,0,0,24,36,36,56,32,36,24,0,0,0,0],"58":[0,0,0,0,0,0,24,24,0,0,24,24,0,0,0,0],"59":[0,0,0,0,0,0,24,24,0,0,24,24,16,8,0,0],"60":[0,0,0,0,0,32,16,8,4,8,16,32,0,0,0,0],"61":[0,0,0,0,0,0,0,60,0,0,60,0,0,0,0,0],"62":[0,0,0,0,0,4,8,16,32,16,8,4,0,0,0,0],"63":[0,0,0,0,0,24,36,32,16,8,0,8,0,0,0,0],"64":[0,0,0,0,240,264,612,660,660,484,8,240,0,0,0,0],"65":[0,0,0,0,0,24,36,36,60,36,36,36,0,0,0,0],"66":[0,0,0,0,0,28,36,36,28,36,36,28,0,0,0,0],"67":[0,0,0,0,0,24,36,4,4,4,36,24,0,0,0,0],"68":[0,0,0,0,0,28,36,36,36,36,36,28,0,0,0,0],"69":[0,0,0,0,0,60,4,4,28,4,4,60,0,0,0,0],"70":[0,0,0,0,0,60,4,4,28,4,4,4,0,0,0,0],"71":[0,0,0,0,0,24,36,4,52,36,36,24,0,0,0,0],"72":[0,0,0,0,0,36,36,36,60,36,36,36,0,0,0,0],"73":[0,0,0,0,0,28,8,8,8,8,8,28,0,0,0,0],"74":[0,0,0,0,0,60,16,16,16,20,20,8,0,0,0,0],"75":[0,0,0,0,0,36,36,20,12,20,36,36,0,0,0,0],"76":[0,0,0,0,0,4,4,4,4,4,4,60,0,0,0,0],"77":[0,0,0,0,0,68,68,108,84,84,68,68,0,0,0,0],"78":[0,0,0,0,0,68,76,84,84,84,100,68,0,0,0,0],"79":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"80":[0,0,0,0,0,28,36,36,28,4,4,4,0,0,0,0],"81":[0,0,0,0,0,24,36,36,36,52,36,88,0,0,0,0],"82":[0,0,0,0,0,28,36,36,28,36,36,36,0,0,0,0],"83":[0,0,0,0,0,24,36,4,24,32,36,24,0,0,0,0],"84":[0,0,0,0,0,124,16,16,16,16,16,16,0,0,0,0],"85":[0,0,0,0,0,36,36,36,36,36,36,24,0,0,0,0],"86":[0,0,0,0,0,68,68,68,68,40,40,16,0,0,0,0],"87":[0,0,0,0,0,84,84,84,84,84,56,40,0,0,0,0],"88":[0,0,0,0,0,68,68,40,16,40,68,68,0,0,0,0],"89":[0,0,0,0,0,68,68,40,16,16,16,16,0,0,0,0],"90":[0,0,0,0,0,60,32,16,16,8,4,60,0,0,0,0],"91":[0,0,0,0,0,28,4,4,4,4,4,28,0,0,0,0],"92":[0,0,0,0,0,4,4,8,8,8,16,16,0,0,0,0],"93":[0,0,0,0,0,28,16,16,16,16,16,28,0,0,0,0],"94":[0,0,0,0,0,24,36,0,0,0,0,0,0,0,0,0],"95":[0,0,0,0,0,0,0,0,0,0,0,0,508,0,0,0],"96":[0,0,0,0,0,4,8,0,0,0,0,0,0,0,0,0],"97":[0,0,0,0,0,0,0,24,32,56,36,88,0,0,0,0],"98":[0,0,0,0,0,0,4,4,28,36,36,28,0,0,0,0],"99":[0,0,0,0,0,0,0,0,24,4,4,24,0,0,0,0],"100":[0,0,0,0,0,0,32,32,56,36,36,88,0,0,0,0],"101":[0,0,0,0,0,0,0,24,36,28,4,56,0,0,0,0],"102":[0,0,0,0,0,0,48,8,8,28,8,8,0,0,0,0],"103":[0,0,0,0,0,0,0,0,88,36,36,56,32,36,24,0],"104":[0,0,0,0,0,0,4,4,4,28,36,36,0,0,0,0],"105":[0,0,0,0,0,0,8,0,12,8,8,8,0,0,0,0],"106":[0,0,0,0,0,0,0,16,0,24,16,16,16,12,0,0],"107":[0,0,0,0,0,0,0,4,20,12,20,20,0,0,0,0],"108":[0,0,0,0,0,0,4,4,4,4,4,8,0,0,0,0],"109":[0,0,0,0,0,0,0,0,4,88,168,168,0,0,0,0],"110":[0,0,0,0,0,0,0,0,4,28,36,36,0,0,0,0],"111":[0,0,0,0,0,0,0,0,24,36,36,24,0,0,0,0],"112":[0,0,0,0,0,0,0,4,56,72,72,56,8,8,8,0],"113":[0,0,0,0,0,0,0,0,88,36,36,56,32,32,64,0],"114":[0,0,0,0,0,0,0,0,52,72,8,8,0,0,0,0],"115":[0,0,0,0,0,0,0,24,4,24,32,24,0,0,0,0],"116":[0,0,0,0,0,0,8,8,28,8,8,16,0,0,0,0],"117":[0,0,0,0,0,0,0,0,36,36,36,88,0,0,0,0],"118":[0,0,0,0,0,0,0,0,68,68,40,16,0,0,0,0],"119":[0,0,0,0,0,0,0,0,84,84,84,40,0,0,0,0],"120":[0,0,0,0,0,0,0,0,36,24,24,36,0,0,0,0],"121":[0,0,0,0,0,0,0,0,36,36,36,56,32,36,24,0],"122":[0,0,0,0,0,0,0,0,60,16,8,60,0,0,0,0],"123":[0,0,0,16,8,8,8,4,8,8,8,16,0,0,0,0],"124":[0,0,0,8,8,8,8,8,8,8,8,8,0,0,0,0],"125":[0,0,0,4,8,8,8,16,8,8,8,4,0,0,0,0],"126":[0,0,0,0,0,0,0,24,292,192,0,0,0,0,0,0],"161":[0,0,0,0,0,8,0,8,8,8,8,8,0,0,0,0],"162":[0,0,0,0,0,0,16,56,20,20,56,16,0,0,0,0],"163":[0,0,0,0,0,48,8,8,28,8,8,60,0,0,0,0],"164":[0,0,0,0,0,0,132,120,72,72,120,132,0,0,0,0],"165":[0,0,0,0,68,40,16,56,16,56,16,16,0,0,0,0],"166":[0,0,0,8,8,8,8,0,8,8,8,8,0,0,0,0],"167":[0,0,0,0,0,0,48,72,8,48,72,72,48,64,72,48],"168":[0,0,0,0,0,108,108,0,0,0,0,0,0,0,0,0],"169":[0,0,0,0,240,264,612,532,532,612,264,240,0,0,0,0],"8364":[0,0,0,0,0,112,8,60,8,60,8,112,0,0,0,0],"name":"SlightlyFancyPix","copy":"SpiderDave","letterspace":"64","basefont_size":"512","basefont_left":"62","basefont_top":"0","basefont":"Arial","basefont2":""}
        elseif startsWith(line, "export map ") then
            if not gd then
                err("could not use export command because gd did not load.")
            end
            local dummy, dummy, tileMap, fileName=unpack(util.split(line," ",3))
            printf("exporting tile map %s to %s",tileMap, fileName)
            tileToImage2(tileMap, fileName)
        elseif startsWith(line, "export ") then
            if not gd then
                err("could not use export command because gd did not load.")
            end
            local dummy, address,len,fileName=unpack(util.split(line," ",3))
            if not address then err("missing export address") end
            if not len then err("missing export length") end
            if not fileName then err("missing export fileName") end
            address=tonumber(address,16)
            len=tonumber(len,16)*16
            print(string.format("exporting tile data at 0x%08x",address))
            
            tileData = patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            printVerbose(bin2hex(tileData))
            tileToImage(tileData, fileName)
        elseif startsWith(line, "import map ") then
            if not gd then
                err("could not use import command because gd did not load.")
            end
            local dummy, dummy, tileMap, fileName=unpack(util.split(line," ",3))
            --address=tonumber(address,16)
            --len=tonumber(len,16)*16
            
            print(string.format("importing tile map %s",fileName))
            local tileData = imageToTile2(tileMap, fileName)
            
            local address,td
            for i=1,#tileData do
                address,td=tileData[i].address, tileData[i].t
                patcher.write(address+patcher.offset,td)
                --if not writeToFile(patcher.fileName, address+patcher.offset,td) then err("Could not write to file.") end
            end
            
            --if not writeToFile(patcher.fileName, address+patcher.offset,tileData) then err("Could not write to file.") end
        elseif startsWith(line, "import ") then
            if not gd then
                err("could not use import command because gd did not load.")
            end
            local dummy, address,len,fileName=unpack(util.split(line," ",3))
            address=tonumber(address,16)
            len=tonumber(len,16)*16
            
            print(string.format("importing tile at 0x%08x",address))
            local tileData = imageToTile(len, fileName)
            
            patcher.write(address+patcher.offset,tileData)
            --if not writeToFile(patcher.fileName, address+patcher.offset,tileData) then err("Could not write to file.") end
        elseif startsWith(line, "goto ") then
            local label = util.trim(string.sub(line,6))
            patch.index = 1
            while true do
                line = patch.readLine()
                if startsWith(line, ":"..label) then break end
            end
            patcher.gotoCount = patcher.gotoCount + 1
            if patcher.gotoCount >= patcher.gotoLimit then
                err("goto limit reached (could be infinite loop).")
            end
            
        elseif startsWith(line, "skip") then
            local nSkipped = 0
            while true do
                nSkipped = nSkipped +1
                line = patch.readLine()
                if startsWith(line, "end skip") then break end
            end
            print(string.format("skipped %d lines.", nSkipped-1))
        elseif keyword == "var" then
            local k,v = table.unpack(util.split(data, "="))
            k,v = util.trim(k), util.trim(v)
            patcher.variables[k] = v
            printf('Variable: %s = "%s"', k, v)
        elseif keyword == "if" then
            local k,v = table.unpack(util.split(data, "=="))
            k,v = util.trim(k), util.trim(v)
            printVerbose('Compare variable: "%s" == "%s"', k, v)
            if patcher.variables[k] == v then
                patcher["if"] = true
                printVerbose(" true")
            else
                patcher["if"] = false
                printVerbose(" true")
                
                local nSkipped = 0
                while true do
                    nSkipped = nSkipped +1
                    line = patch.readLine()
                    if startsWith(line, "end if") then break end
                    if startsWith(line, "else") then break end
                end
                --print(string.format("skipped %d lines.", nSkipped-1))
            end
        elseif keyword == "else" then
            -- If the last "if" block was true, then we treat the "else" section like a skip
            if patcher["if"] == true then
                local nSkipped = 0
                while true do
                    nSkipped = nSkipped +1
                    line = patch.readLine()
                    if startsWith(line, "end if") then break end
                end
                --print(string.format("skipped %d lines.", nSkipped-1))
            end
        elseif startsWith(line, "end if") then
        elseif startsWith(line, "start tilemap ") then
            local n = string.sub(line,15)
            local tm={}
            local address = 0
            local adjustX = 0
            local adjustY = 0
            while true do
                line = patch.readLine()
                if startsWith(line, "end tilemap") then break end
                if line:find("=") then
                    local k,v=unpack(util.split(line, "="))
                    k=util.trim(k)
                    v=util.trim(v)
                    if k == "address" then
                        --printf("%s=%s",k,v)
                        address = tonumber(v,16)
                    end
                    if k == "adjust" then
                        adjustX = tonumber(util.split(v," ")[1],10)
                        adjustY = tonumber(util.split(v," ")[2],10)
                        print(string.format("adjust x = %s (%s)",adjustX, util.split(v," ")[1]))
                        print(string.format("adjust y = %s (%s)",adjustY, util.split(v," ")[2]))
                    end
                elseif line=="" or startsWith(line, "//") then
                else
                    local tileNum, x, y, flip = unpack(util.split(line," ",3))
                    tileNum = tonumber(tileNum,16)
                    x = tonumber(x,16)
                    y = tonumber(y,16)
                    if flip=="h" then 
                        flip = {horizontal=true}
                    else
                        flip = {}
                    end
                    tm[#tm+1]={address=address, tileNum=tileNum, x=x,y=y, flip=flip, adjust = {x=adjustX,y=adjustY}}
                    --printf("%s: %s, %s", tileNum, x, y)
                end
            end
            patcher.tileMap[n] = tm
        elseif keyword == "eval" then
            local f=util.sandbox:loadCode("return "..data)
            print(f())
        elseif keyword == "code" then
            local f=util.sandbox:loadCode(data)
            f()
        elseif keyword == "plugin" then
            local f=util.sandbox:loadCode(data)
            f()
        elseif keyword == "text" then
            local address = data:sub(1,(data:find(" ")))
            address = tonumber(address, 16)
            txt=data:sub((data:find(" ")+1))
            print(string.format("Setting ascii text: 0x%08x: %s",address,txt))
            txt=string.gsub(txt, "|", string.char(0))
            
            txt=mapText(txt)
            
            patcher.write(address+patcher.offset,txt)
            --if not writeToFile(patcher.fileName, address+patcher.offset,txt) then err("Could not write to file.") end
        elseif keyword == "textmap" then
            local mapOld = data:sub(1,(data:find(" ")-1))
            local mapNew = data:sub((data:find(" ")+1))
            textMap=textMap or {}
            if mapOld=="space" then
                textMap[" "]=hex2bin(mapNew)
            else
                mapNew=hex2bin(mapNew)
                for i=1,#mapOld do
                    textMap[mapOld:sub(i,i)]=mapNew:sub(i,i)
                end
            end
        elseif keyword == "hex" or keyword == "put" then
            if keyword == "hex" then
                warning('depreciated keyword "hex". use "put" instead')
            end
            local address = data:sub(1,(data:find(" ")))
            --address = tonumber(address, 16)
            address = util.toNumber(address)
            local newData=data:sub((data:find(" ")+1))
            newData = util.stripSpaces(newData)
            
            old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+#newData/2)
            old=bin2hex(old)
            printf("Setting bytes: 0x%08x: %s --> %s",address,old, newData)
            patcher.write(address+patcher.offset,hex2bin(newData))
            --if not writeToFile(patcher.fileName, address+patcher.offset,hex2bin(newData)) then err("Could not write to file.") end
        elseif keyword == "fill" then
            address = util.toNumber(util.split(data, " ", 1)[1])
            data = util.split(data, " ", 1)[2]
            fillCount = util.toNumber(util.split(data, " ", 1)[1])
            fillString = util.stripSpaces(util.split(data, " ", 1)[2])
            printf("fill: 0x%x 0x%02x [%s]",address, fillCount, fillString)
            
            local newData = string.rep(fillString, fillCount)
            printVerbose("Fill data: 0x%08x: %s",address, newData)
            patcher.write(address+patcher.offset,hex2bin(newData))
            --if not writeToFile(patcher.fileName, address+patcher.offset,hex2bin(newData)) then err("Could not write to file.") end
        elseif keyword == "gg" then
            local gg=data:upper()
            gg=util.split(data," ",1)[1] -- Let's allow stuff after the code for descriptions, etc.  figure out a better comment system later.
            -- Used to map the GG characters to binary
            local ggMap={
                A="0000", P="0001", Z="0010", L="0011", G="0100", I="0101", T="0110", Y="0111",
                E="1000", O="1001", X="1010", U="1011", K="1100", S="1101", V="1110", N="1111"
            }
            --ggMap2={1,6,7,8,17,2,3,4,nil,18,19,20,21,10,11,12,13,22,23,24,5,14,15,16}
            --ggMap2={1,6,7,8,17,2,3,4,-,18,19,20,21,10,11,12,13,22,23,24,29,14,15,16,25,30,31,32,5,26,27,28}
            if #gg == 6 then
                ggMap2={1,6,7,8,21,2,3,4,nil,14,15,16,17,22,23,24,5,10,11,12,13,18,19,20}
            elseif #gg == 8 then
                ggMap2={1,6,7,8,29,2,3,4,nil,14,15,16,17,22,23,24,5,10,11,12,13,18,19,20,25,30,31,32,21,26,27,28}
            else
                err("Bad gg length")
            end
            
            -- Map to binary string
            local binString=""
            for i=1,#gg do
                binString=binString..ggMap[gg:sub(i,i)]
            end
            
            -- Unscramble the binary string
            local binString2=""
            for i=1,#binString do
                if ggMap2[i] then
                    binString2=binString2..binString:sub(ggMap2[i],ggMap2[i])
                else
                    binString2=binString2.." "
                end
            end
            local v,a,c
            if #gg == 6 then
                v=tonumber(binString2:sub(1,8),2)
                a=tonumber(binString2:sub(10),2)
                print(string.format("gg %s: 0x%08x value=0x%02x",gg,a,v))
            elseif #gg == 8 then
                v = tonumber(binString2:sub(1,8),2)
                a = tonumber(("1"..binString2:sub(10,24)),2)
                c = tonumber(binString2:sub(25,32),2)
                print(string.format("gg %s: 0x%08x compare=0x%02x value=0x%02x",gg,a,c,v))
            end
            
            -- Hopefully this is right
            local address=a % 0x4000
            
            print("    Addresses:")
            for i=1,100 do
                if c then
                    local b=patcher.fileData:sub(address+patcher.offset+1,address+patcher.offset+1):byte()
                    if c == b then
                        printf("    %04x",address)
                        patcher.write(address+patcher.offset,string.char(v))
                        --if not writeToFile(patcher.fileName, address+patcher.offset,string.char(v)) then err("Could not write to file.") end
                    end
                    --printf("%04x %02x %02x",address+patcher.offset,b,c)
                else
                    printf("    %04x",address)
                    patcher.write(address+patcher.offset,string.char(v))
                    --if not writeToFile(patcher.fileName, address+patcher.offset,string.char(v)) then err("Could not write to file.") end
                end
                address=address+ 0x2000
                if address > #patcher.fileData or address>=0x20000 then break end
            end
            
        elseif startsWith(line, "copy hex ") then
            warning('depreciated keyword "copy hex". use "copy" instead')
            local data=string.sub(line,10)
            local address = data:sub(1,(data:find(" ")))
            data = data:sub((data:find(" ")+1))
            local address2 = data:sub(1,(data:find(" ")))
            data = data:sub((data:find(" ")+1))
            local l = data:sub(1,(data:find(" ")))
            address = tonumber(address, 16)
            address2 = tonumber(address2, 16)
            l = tonumber(l, 16)
            data = patcher.fileData:sub(address+1+patcher.offset,address+1+patcher.offset+l-1)
            print(string.format("Copying 0x%08x bytes from 0x%08x to 0x%08x",l, address, address2))
            patcher.write(address2+patcher.offset,data)
            --if not writeToFile(patcher.fileName, address2+patcher.offset,data) then err("Could not write to file.") end
        elseif startsWith(line, "copy ") then
            local data=string.sub(line,6)
            local address = data:sub(1,(data:find(" ")))
            data = data:sub((data:find(" ")+1))
            local address2 = data:sub(1,(data:find(" ")))
            data = data:sub((data:find(" ")+1))
            local l = data:sub(1,(data:find(" ")))
            address = tonumber(address, 16)
            address2 = tonumber(address2, 16)
            l = tonumber(l, 16)
            data = patcher.fileData:sub(address+1+patcher.offset,address+1+patcher.offset+l-1)
            print(string.format("Copying 0x%08x bytes from 0x%08x to 0x%08x",l, address, address2))
            patcher.write(address2+patcher.offset,data)
            --if not writeToFile(patcher.fileName, address2+patcher.offset,data) then err("Could not write to file.") end
        elseif line=="break" or line == "quit" or line == "exit" then
            print("[break]")
            --break
            breakLoop=true
        elseif keyword=="refresh" then
            if data == "auto" then
                patcher.autoRefresh = true
            elseif data == "manual" then
                patcher.autoRefresh = false
            else
                patcher.fileData = patcher.newFileData
            end
        elseif line=="header" then
            local header = patcher.getHeader()
            print(string.format("\niNES header data:\nid: %s\nPRG ROM: %02x x 4000\nCHR ROM: %02x x 2000\n\n",header.id,header.prg_rom_size,header.chr_rom_size))
        elseif line=="_test" then
            for i=0,255-26 do
                local out = "textmap ABCDEFGHIJKLMNOPQRSTUVWXYZ "
                for j=1,26 do
                    out=out..string.format("%02x",i+j)
                end
                print(string.format("# %s",out))
                print(out)
                print("find text YES")
                print("find text FUTURE")
                print("find text SCORE")
            end
            
        elseif line=="write all" then
            --if not writeToFile(patcher.fileName, patcher.offset,patcher.fileData) then err("Could not write to file.") end
        elseif keyword=="file" then
            patcher.fileName = data
            file = data
            printf("File: %s",patcher.fileName)
            --patcher.fileData=getfilecontents(patcher.fileName)
        elseif keyword=="load" then
            patcher.fileName = data
            printf("Loading file: %s",patcher.fileName)
            patcher.fileData = getfilecontents(patcher.fileName)
            patcher.newFileData = patcher.fileData
            patcher.header = patcher.getHeader()
        elseif keyword=="outputfile" then
            patcher.outputFileName = data
            printf("Output file: %s",patcher.outputFileName)
            --patcher.fileData=getfilecontents(patcher.fileName)
        elseif keyword == "start" then
            patcher.startAddress = tonumber(data, 16)
            print("Setting Start Address: "..data)
        elseif keyword == "offset" then
            patcher.offset = tonumber(data, 16)
            print("Setting offset: "..data)
        elseif keyword == "palette" then
            if startsWith(data, "file") then
                local fileName = util.split(data, " ", 1)[2]
                local fileData = getfilecontents(fileName)
                
                patcher.palette = {}
                i=1
                for c=0,63 do
                    patcher.palette[c]={}
                    for i=1,3 do
                        patcher.palette[c][i]=rawToNumber(fileData:sub(c*3+i,c*3+i))
                    end
                end
            elseif #data==8 then
                for i=0,3 do
                    patcher.colors[i]=tonumber(string.sub(data,i*2+1,i*2+2),16)
                    --print(patcher.colors[i])
                end
                patcher.variables["PALETTE"] = string.format("%02x%02x%02x%02x", patcher.colors[0],patcher.colors[1],patcher.colors[2],patcher.colors[3])
            else
                err("bad palette string length")
            end
        elseif keyword == "base" then
            patcher.base = tonumber(data,10)
            printf("base: %s",patcher.base)
        elseif keyword == "diff" then
            local diff={}
            diff.fileName = data
            diff.data = getfilecontents(diff.fileName)
            diff.count=1
            printf("file1: %s bytes",#patcher.fileData)
            printf("file2: %s bytes",#diff.data)
            for i = 0,#patcher.fileData do
                diff.old =string.byte(patcher.fileData:sub(i+1,i+1))
                diff.new =string.byte(diff.data:sub(i+1,i+1))
                if diff.old~=diff.new then
                    printf("%02x %06x  %02x | %02x",diff.count, i, diff.old,diff.new)
                    diff.count=diff.count+1
                    if diff.count>patcher.diffMax then break end
                end
            end
        elseif startsWith(line, "ips ") then
            local ips = {}
            ips.n=string.sub(line,5)
            print("Applying ips patch: "..ips.n)
            --ips.file = io.open(ips.n,"r")
            ips.data = getfilecontents(ips.n)
            print(#ips.data)
            ips.header = ips.data:sub(1,5)
            if ips.header ~= "PATCH" then quit ("Error: Invalid ips header.") end
            --print ("ips header: "..ips.header)
            ips.address = 5
            local loopLimit = 90001
            --local loopLimit = 20
            local loopCount = 0
            
            while true do
                ips.offset = ips.data:sub(ips.address+1,ips.address+3)
                if ips.offset == "EOF" then
                    printVerbose("EOF found")
                    break
                end
                
    --            if ips.address+1 > #ips.data+3 then
    --                err("Early end of file")
    --            end
                --print(#ips.offset)
                ips.offset = rawToNumber(ips.offset)
                printVerbose(string.format("offset: 0x%08x",ips.offset))
                ips.address = ips.address + 3
                ips.chunkSize = rawToNumber(ips.data:sub(ips.address+1,ips.address+2))
                printVerbose(string.format("chunkSize: 0x%08x",ips.chunkSize))
                ips.address = ips.address + 2
                if ips.chunkSize == 0 then
                    -- RLE
                    printVerbose(string.format("RLE detected at: 0x%08x",ips.address))
                    ips.chunkSize = rawToNumber(ips.data:sub(ips.address+1,ips.address+2))
                    ips.address = ips.address + 2
                    if ips.chunkSize == 0 then err("bad RLE size") end
                    printVerbose(string.format("RLE length: 0x%08x",ips.chunkSize))
                    ips.fill = ips.data:sub(ips.address+1,ips.address+1)
                    ips.address = ips.address + 1
                    printVerbose(string.format("RLE fill: %s", bin2hex(ips.fill)))
                    ips.replaceData = string.rep(ips.fill, ips.chunkSize)
                else
                    ips.replaceData = ips.data:sub(ips.address+1,ips.address+ips.chunkSize)
                    ips.address=ips.address+ips.chunkSize
                end
                printVerbose(string.format("replacing 0x%08x bytes at 0x%08x", #ips.replaceData, ips.offset))
                --printVerbose(string.format("replacing: 0x%08x %s", ips.offset, bin2hex(ips.replaceData))) -- MAKES IT HANG
                printVerbose(string.format("0x%08x",ips.address))
                patcher.write(ips.offset+patcher.offset,ips.replaceData)
                --if not writeToFile(patcher.fileName, ips.offset+patcher.offset,ips.replaceData) then err("Could not write to file.") end
                loopCount = loopCount+1
                if loopCount >=loopLimit then
                    quit ("Error: Loop limit reached.")
                end
            end
            print("ips done.")
            
    --        old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+#txt/2)
    --        old=bin2hex(old)
        elseif keyword == "readme" then
            if not (data == "update") then
                err("bad or missing readme parameter.")
            end
            -- Throw in a little extra info here
            if (util.writeToFile("README.md",0,"```\n"..patcher.help.info .."\n".. patcher.help.description .."\n\n"..patcher.help.extra.."\n\n".. patcher.help.commands.."\n```")) then
                print("README updated")
            else
                quit("Error: README update failed.")
            end
        elseif line == "" then
        elseif (assignment == true) and (patcher.strict~=true) then
            patcher.variables[keyword] = util.trim(data)
            printf('Variable: %s = "%s"', keyword, data)
        else
            if patcher.interactive then
                print(string.format("unknown command: %s",line))
            else
                if (patcher.strict==true) or patcher.verbose then
                    warning("Unknown command: %s",line)
                end
            end
        end
    end
    end --loopCount
    end)
    
    if status==true then
        -- no errors
    else
        quit(err)
    end
    if breakLoop==true then
        break
    end
end

if not util.writeToFile(patcher.outputFileName or "output.nes", 0, patcher.newFileData) then err("Could not write to file.") end

printVerbose(string.format("\nelapsed time: %.2f\n", os.clock() - executionTime))
print("done.")

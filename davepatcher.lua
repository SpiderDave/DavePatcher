-- ToDo:
--  * import/export tiles to/from sections of an existing image
--  * create tile maps to make above easier
--  * apply game genie codes

table.unpack = table.unpack or unpack
local gd

-- let gd fail gracefully.
if not pcall(function()
    gd = require("gd")
end) then
    gd = false
end

--local winapi = require("winapi")


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

printf = util.printf


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

asm.set={
    [0x00]={opcode="brk", mode="i", length=1},
    [0x01]={opcode="ora", mode="(zp,x)", length=2},
    [0x05]={opcode="ora", mode="zp", length=2},
    [0x06]={opcode="asl", mode="zp", length=2},
    [0x08]={opcode="php", mode="i", length=1},
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
    [0x30]={opcode="bmi", mode="r", length=2},
    [0x31]={opcode="and", mode="(zp),y", length=2},
    [0x35]={opcode="and", mode="zp,x", length=2},
    [0x36]={opcode="rol", mode="zp,x", length=2},
    [0x38]={opcode="sec", mode="i", length=1},
    [0x39]={opcode="and", mode="a,y", length=3},
    [0x3c]={opcode="rts", mode="i", length=1},
    [0x3d]={opcode="and", mode="a,x", length=3},
    [0x3e]={opcode="rol", mode="a,x", length=3},
    [0x41]={opcode="eor", mode="(zp,x)", length=2},
    [0x45]={opcode="eor", mode="zp", length=2},
    [0x46]={opcode="lsr", mode="zp", length=2},
    [0x48]={opcode="pha", mode="i", length=1},
    [0x49]={opcode="eor", mode="#", length=2},
    [0x4a]={opcode="lsr", mode="A", length=1},
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
    [0x85]={opcode="sta", mode="zp", length=2},
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
    [0xa0]={opcode="ldy", mode="#", length=2},
    [0xa1]={opcode="lda", mode="(zp,x)", length=2},
    [0xa2]={opcode="ldx", mode="#", length=2},
    [0xa4]={opcode="ldy", mode="zp", length=2},
    [0xa5]={opcode="lda", mode="zp", length=2},
    [0xa6]={opcode="ldx", mode="zp", length=2},
    [0xa8]={opcode="tay", mode="i", length=1},
    [0xa9]={opcode="lda", mode="#", length=2},
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
    [0xc9]={opcode="cmp", mode="#", length=2},
    [0xca]={opcode="dex", mode="i", length=1},
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
    [0xe9]={opcode="sbc", mode="#", length=2},
    [0xea]={opcode="nop", mode="i", length=1},
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
}

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


local patcher = {
    info = {
        name = "DavePatcher",
        version = "0.5.5",
        released = "2015",
        author = "SpiderDave",
        url = 'https://github.com/SpiderDave/DavePatcher'
    },
    help={},
    startAddress=0,
    offset = 0,
    verbose = false,
    interactive = false,
    prompt = "> ",
    tileMap={}
}

patcher.help.info = string.format("%s %s (%s) - %s %s",patcher.info.name,patcher.info.version,patcher.info.released,patcher.info.author,patcher.info.url)
patcher.help.description = "A custom patcher for use with NES romhacking or general use."
patcher.help.usage = [[
Usage: davepatcher [options...] <patch file> <file to patch>
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
    
Lines starting with # are "annotations"; Annotations are comments that are
shown in the output when running the patcher.
    
    # This is an annotation
    
Keywords are lowercase, usually followed by a space.  Some "keywords" consist
of multiple words.  Possible keywords:

    help
    commands
        Show this help.  May be useful in interactive mode.
        
    hex <address> <data>
        Set data at <address> to <data>.  <data> should be hexidecimal, and
        its length should be a multiple of 2.  You may include spaces in data
        for readability.
        Example:
            hex a010 0001ff
            
    copy hex <address1> <address2> <length>
        Copies data from <address1> to <address2>.  The number of bytes is
        specified in hexidecimal by <length>.

        Example:
            copy hex a010 b010 0a
            
    text <address> <text>
        Set data at <address> to <text>.  Use the textmap command to set a 
        custom format for the text.  If no textmap is set, ASCII is assumed.
        Example:
            hex a010 FOOBAR
            
    find text <text>
        Find text data.  Use the textmap command to set a custom format for
        the text.  If no textmap is set, ASCII is assumed.
        Example:
            find text FOOBAR
            
    find hex <data>
        Find data in hexidecimal.  The length of the data must be a multiple
        of 2.
        Example:
            find hex 00ff1012
            
    textmap <characters> <map to>
        Map text characters to specific values.  These will be used in other
        commands like the "text" command.
        Example:
            textmap ABCD 30313233
            
    textmap space <map to>
        Use this format to map the space character.
        Example:
            textmap space 00
            
    break
        Use this to end the patch early.  Handy if you want to add some
        testing stuff at the bottom.
        
    start <address>
        Set the starting address for commands
        Example:
            start 10200
            find hex a901
            
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
    end
        Define a tile map to be used with the export map command.
        Example:
            start tilemap batman
            address = 2c000
            81 1 0
            82 2 0
            90 0 1
            91 1 1
            92 2 1
            a0 0 2
            a1 1 2
            a2 2 2
            b0 0 3
            b1 1 3
            b2 2 3
            end

    export map <tilemap> <file>
        export tile data to png file using a tile map.
        Example:
            export map batman batman_sprite_test.png
    
    import map
        import tile data from png file using a tile map
        Example:
            import map batman batman_sprite_test.png
    
    gg <gg code>
        WIP
        decode a NES Game Genie code (does not apply it)
        
    refresh
        refreshes the data so that keywords like "find text" will use the new
        altered data.
        
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
]]

printVerbose = function(txt)
    if patcher.verbose then
        print(txt)
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

function quit(text)
  if text then print(text) end
  os.exit()
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

function getfilecontents(path)
    local file = io.open(path,"rb")
    if file==nil then return nil end
    io.input(file)
    ret=io.read('*a')
    io.close(file)
    return ret
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
    local output=''
    for i = 1, #str do
        local c = string.byte(str:sub(i,i))
        output=output..string.format("%02x", c)
    end
    return output
end

function hex2bin(str)
    local output=''
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
    p=string.sub(a,7,8)..string.sub(a,5,6)..'4'..string.sub(a,4,4)..string.sub(a,1,2)
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
    end

    local tileData = ""
    local tileData = {} --It's an array here, because it's not guaranteed to be a continuous string of data; it can have gaps.
    
    -- Iterate the tilemap
    for i=1,#tm do
        tileData[i]={}
        
        t=tm[i].tileNum
        local o=""
        
        for j=0,#out.t[t] do
            o=o..string.char(out.t[tm[i].y*w/8+tm[i].x][j])
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
                xo=tm[i].x*8
                yo=tm[i].y*8
                image:setPixel(x+xo,y+yo,colors[c])
            end
        end
        --printf("tilemap index=%02x tileNum=%02x pos=(%02x,%02x) %02x %s",i,tm[i].tileNum, tm[i].x,tm[i].y,address,bin2hex(tileData))
    end
    image:png(fileName)
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

file=arg[2]
if not arg[1] or not arg[2] or arg[3] then
    print(patcher.help.info)
    print(patcher.help.description)
    print(patcher.help.usage)
    quit()
end

if arg[1] == "-i" then
    patcher.interactive = true
    print(patcher.help.info)
    print(patcher.help.interactive)
end

printVerbose(string.format("file: %s",file))

file_dumptext = nil
patcher.fileData = getfilecontents(file)

local patchfile
if not patcher.interactive==true then
    patchfile = io.open(arg[1] or "patch.txt","r")
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
        line = patchfile:read("*l")
    end
    if line == nil then break end
    line = util.ltrim(line)
    local status, err = pcall(function()
    
    local keyword,data = unpack(util.split(line," ",1))
    keyword=keyword:lower()
    
    if startsWith(line, '#') then
        print(string.sub(line,1))
    elseif startsWith(line, '//') then
        -- comment
    elseif startsWith(line, "verbose off") then
        patcher.verbose = false
        print("verbose off")
    elseif startsWith(line, "verbose on") or line == "verbose" then
        patcher.verbose = true
        print("verbose on")
    elseif keyword == "help" then
        print(patcher.help.interactive)
    elseif keyword == "commands" then
        print(patcher.help.commands)
    elseif startsWith(line:lower(), 'find hex ') then
        local data=string.sub(line,10)
        address=0
        print(string.format("Find hex: %s",data))
        for i=1,50 do
            --address = filedata:find(hex2bin(data),address+1+patcher.offset, true)
            address = patcher.fileData:find(hex2bin(data),address+1+patcher.offset, true)
            if address then
                if address>patcher.startAddress+patcher.offset then
                    print(string.format("    %s Found at 0x%08x",data,address-1-patcher.offset))
                end
            else
                break
            end
        end
    elseif startsWith(line:lower(), 'get hex ') then
        local data=string.sub(line,9)

        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        
        local len = data:sub((data:find(' ')+1))
        len = tonumber(len, 16)

        local old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
        old=bin2hex(old)
        
        print(string.format("Hex data at 0x%08x: %s",address, old))
    elseif startsWith(line, 'testtext ') then
        local txt=string.sub(line,10)
        print(bin2hex(mapText(txt)))
        print(string.format("[%s] = [%s]",txt,bin2hex(mapText(txt))))
    elseif startsWith(line, 'find text ') then
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
    elseif startsWith(line:lower(), 'get text ') then
        local data=string.sub(line,10)
        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        local len = data:sub((data:find(' ')+1))
        len = tonumber(len, 16)
        
        local old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
        --old=bin2hex(old)
        
        print(string.format("Hex data at 0x%08x: %s",address,mapText(old,true)))
    elseif keyword == 'fontdata' then
        --local font = {"33":[0,0,0,0,0,8,8,8,8,8,0,8,0,0,0,0],"34":[0,0,0,0,0,20,20,0,0,0,0,0,0,0,0,0],"35":[0,0,0,0,0,0,40,124,40,40,124,40,0,0,0,0],"36":[0,0,0,0,16,56,84,20,56,80,84,56,16,0,0,0],"37":[0,0,0,0,0,264,148,72,32,144,328,132,0,0,0,0],"38":[0,0,0,0,0,48,72,48,168,68,196,312,0,0,0,0],"39":[0,0,0,0,0,8,8,0,0,0,0,0,0,0,0,0],"40":[0,0,0,0,0,8,4,4,4,4,4,8,0,0,0,0],"41":[0,0,0,0,0,4,8,8,8,8,8,4,0,0,0,0],"42":[0,0,0,0,32,168,112,428,112,168,32,0,0,0,0,0],"43":[0,0,0,0,0,0,16,16,124,16,16,0,0,0,0,0],"44":[0,0,0,0,0,0,0,0,0,0,24,24,16,8,0,0],"45":[0,0,0,0,0,0,0,0,60,0,0,0,0,0,0,0],"46":[0,0,0,0,0,0,0,0,0,0,24,24,0,0,0,0],"47":[0,0,0,0,0,16,16,8,8,8,4,4,0,0,0,0],"48":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"49":[0,0,0,0,0,8,8,8,8,8,8,8,0,0,0,0],"50":[0,0,0,0,0,24,36,32,16,8,4,60,0,0,0,0],"51":[0,0,0,0,0,24,36,32,24,32,36,24,0,0,0,0],"52":[0,0,0,0,0,32,36,36,60,32,32,32,0,0,0,0],"53":[0,0,0,0,0,60,4,4,24,32,36,24,0,0,0,0],"54":[0,0,0,0,0,24,36,4,28,36,36,24,0,0,0,0],"55":[0,0,0,0,0,60,32,32,16,8,8,8,0,0,0,0],"56":[0,0,0,0,0,24,36,36,24,36,36,24,0,0,0,0],"57":[0,0,0,0,0,24,36,36,56,32,36,24,0,0,0,0],"58":[0,0,0,0,0,0,24,24,0,0,24,24,0,0,0,0],"59":[0,0,0,0,0,0,24,24,0,0,24,24,16,8,0,0],"60":[0,0,0,0,0,32,16,8,4,8,16,32,0,0,0,0],"61":[0,0,0,0,0,0,0,60,0,0,60,0,0,0,0,0],"62":[0,0,0,0,0,4,8,16,32,16,8,4,0,0,0,0],"63":[0,0,0,0,0,24,36,32,16,8,0,8,0,0,0,0],"64":[0,0,0,0,240,264,612,660,660,484,8,240,0,0,0,0],"65":[0,0,0,0,0,24,36,36,60,36,36,36,0,0,0,0],"66":[0,0,0,0,0,28,36,36,28,36,36,28,0,0,0,0],"67":[0,0,0,0,0,24,36,4,4,4,36,24,0,0,0,0],"68":[0,0,0,0,0,28,36,36,36,36,36,28,0,0,0,0],"69":[0,0,0,0,0,60,4,4,28,4,4,60,0,0,0,0],"70":[0,0,0,0,0,60,4,4,28,4,4,4,0,0,0,0],"71":[0,0,0,0,0,24,36,4,52,36,36,24,0,0,0,0],"72":[0,0,0,0,0,36,36,36,60,36,36,36,0,0,0,0],"73":[0,0,0,0,0,28,8,8,8,8,8,28,0,0,0,0],"74":[0,0,0,0,0,60,16,16,16,20,20,8,0,0,0,0],"75":[0,0,0,0,0,36,36,20,12,20,36,36,0,0,0,0],"76":[0,0,0,0,0,4,4,4,4,4,4,60,0,0,0,0],"77":[0,0,0,0,0,68,68,108,84,84,68,68,0,0,0,0],"78":[0,0,0,0,0,68,76,84,84,84,100,68,0,0,0,0],"79":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"80":[0,0,0,0,0,28,36,36,28,4,4,4,0,0,0,0],"81":[0,0,0,0,0,24,36,36,36,52,36,88,0,0,0,0],"82":[0,0,0,0,0,28,36,36,28,36,36,36,0,0,0,0],"83":[0,0,0,0,0,24,36,4,24,32,36,24,0,0,0,0],"84":[0,0,0,0,0,124,16,16,16,16,16,16,0,0,0,0],"85":[0,0,0,0,0,36,36,36,36,36,36,24,0,0,0,0],"86":[0,0,0,0,0,68,68,68,68,40,40,16,0,0,0,0],"87":[0,0,0,0,0,84,84,84,84,84,56,40,0,0,0,0],"88":[0,0,0,0,0,68,68,40,16,40,68,68,0,0,0,0],"89":[0,0,0,0,0,68,68,40,16,16,16,16,0,0,0,0],"90":[0,0,0,0,0,60,32,16,16,8,4,60,0,0,0,0],"91":[0,0,0,0,0,28,4,4,4,4,4,28,0,0,0,0],"92":[0,0,0,0,0,4,4,8,8,8,16,16,0,0,0,0],"93":[0,0,0,0,0,28,16,16,16,16,16,28,0,0,0,0],"94":[0,0,0,0,0,24,36,0,0,0,0,0,0,0,0,0],"95":[0,0,0,0,0,0,0,0,0,0,0,0,508,0,0,0],"96":[0,0,0,0,0,4,8,0,0,0,0,0,0,0,0,0],"97":[0,0,0,0,0,0,0,24,32,56,36,88,0,0,0,0],"98":[0,0,0,0,0,0,4,4,28,36,36,28,0,0,0,0],"99":[0,0,0,0,0,0,0,0,24,4,4,24,0,0,0,0],"100":[0,0,0,0,0,0,32,32,56,36,36,88,0,0,0,0],"101":[0,0,0,0,0,0,0,24,36,28,4,56,0,0,0,0],"102":[0,0,0,0,0,0,48,8,8,28,8,8,0,0,0,0],"103":[0,0,0,0,0,0,0,0,88,36,36,56,32,36,24,0],"104":[0,0,0,0,0,0,4,4,4,28,36,36,0,0,0,0],"105":[0,0,0,0,0,0,8,0,12,8,8,8,0,0,0,0],"106":[0,0,0,0,0,0,0,16,0,24,16,16,16,12,0,0],"107":[0,0,0,0,0,0,0,4,20,12,20,20,0,0,0,0],"108":[0,0,0,0,0,0,4,4,4,4,4,8,0,0,0,0],"109":[0,0,0,0,0,0,0,0,4,88,168,168,0,0,0,0],"110":[0,0,0,0,0,0,0,0,4,28,36,36,0,0,0,0],"111":[0,0,0,0,0,0,0,0,24,36,36,24,0,0,0,0],"112":[0,0,0,0,0,0,0,4,56,72,72,56,8,8,8,0],"113":[0,0,0,0,0,0,0,0,88,36,36,56,32,32,64,0],"114":[0,0,0,0,0,0,0,0,52,72,8,8,0,0,0,0],"115":[0,0,0,0,0,0,0,24,4,24,32,24,0,0,0,0],"116":[0,0,0,0,0,0,8,8,28,8,8,16,0,0,0,0],"117":[0,0,0,0,0,0,0,0,36,36,36,88,0,0,0,0],"118":[0,0,0,0,0,0,0,0,68,68,40,16,0,0,0,0],"119":[0,0,0,0,0,0,0,0,84,84,84,40,0,0,0,0],"120":[0,0,0,0,0,0,0,0,36,24,24,36,0,0,0,0],"121":[0,0,0,0,0,0,0,0,36,36,36,56,32,36,24,0],"122":[0,0,0,0,0,0,0,0,60,16,8,60,0,0,0,0],"123":[0,0,0,16,8,8,8,4,8,8,8,16,0,0,0,0],"124":[0,0,0,8,8,8,8,8,8,8,8,8,0,0,0,0],"125":[0,0,0,4,8,8,8,16,8,8,8,4,0,0,0,0],"126":[0,0,0,0,0,0,0,24,292,192,0,0,0,0,0,0],"161":[0,0,0,0,0,8,0,8,8,8,8,8,0,0,0,0],"162":[0,0,0,0,0,0,16,56,20,20,56,16,0,0,0,0],"163":[0,0,0,0,0,48,8,8,28,8,8,60,0,0,0,0],"164":[0,0,0,0,0,0,132,120,72,72,120,132,0,0,0,0],"165":[0,0,0,0,68,40,16,56,16,56,16,16,0,0,0,0],"166":[0,0,0,8,8,8,8,0,8,8,8,8,0,0,0,0],"167":[0,0,0,0,0,0,48,72,8,48,72,72,48,64,72,48],"168":[0,0,0,0,0,108,108,0,0,0,0,0,0,0,0,0],"169":[0,0,0,0,240,264,612,532,532,612,264,240,0,0,0,0],"8364":[0,0,0,0,0,112,8,60,8,60,8,112,0,0,0,0],"name":"SlightlyFancyPix","copy":"SpiderDave","letterspace":"64","basefont_size":"512","basefont_left":"62","basefont_top":"0","basefont":"Arial","basefont2":""}
    elseif startsWith(line, 'export map ') then
        if not gd then
            quit("Error: could not use export command because gd did not load.")
        end
        local dummy, dummy, tileMap, fileName=unpack(util.split(line," ",3))
        printf("exporting tile map %s to %s",tileMap, fileName)
        tileToImage2(tileMap, fileName)
    elseif startsWith(line, 'export ') then
        if not gd then
            quit("Error: could not use export command because gd did not load.")
        end
        local dummy, address,len,fileName=unpack(util.split(line," ",3))
        address=tonumber(address,16)
        len=tonumber(len,16)*16
        
        tileData = patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
        
        print(string.format("exporting tile data at 0x%08x",address))
        printVerbose(bin2hex(tileData))
        tileToImage(tileData, fileName)
    elseif startsWith(line, 'import map ') then
        if not gd then
            quit("Error: could not use import command because gd did not load.")
        end
        local dummy, dummy, tileMap, fileName=unpack(util.split(line," ",3))
        --address=tonumber(address,16)
        --len=tonumber(len,16)*16
        
        print(string.format("importing tile map %s",fileName))
        local tileData = imageToTile2(tileMap, fileName)
        
        local address,td
        for i=1,#tileData do
            address,td=tileData[i].address, tileData[i].t
            if not writeToFile(file, address+patcher.offset,td) then quit("Error: Could not write to file.") end
        end
        
        --if not writeToFile(file, address+patcher.offset,tileData) then quit("Error: Could not write to file.") end
    elseif startsWith(line, 'import ') then
        if not gd then
            quit("Error: could not use import command because gd did not load.")
        end
        local dummy, address,len,fileName=unpack(util.split(line," ",3))
        address=tonumber(address,16)
        len=tonumber(len,16)*16
        
        print(string.format("importing tile at 0x%08x",address))
        local tileData = imageToTile(len, fileName)
        
        if not writeToFile(file, address+patcher.offset,tileData) then quit("Error: Could not write to file.") end
    elseif startsWith(line, 'start tilemap ') then
        local n = string.sub(line,15)
        local tm={}
        local address = 0
        while true do
            line = util.trim(patchfile:read("*l"))
            if startsWith(line, "end") then break end
            if line:find("=") then
                local k,v=unpack(util.split(line, "="))
                k=util.trim(k)
                v=util.trim(v)
                if k == "address" then
                    --printf("%s=%s",k,v)
                    address = tonumber(v,16)
                end
            else
                local tileNum, x, y = unpack(util.split(line," ",3))
                tileNum = tonumber(tileNum,16)
                x = tonumber(x,16)
                y = tonumber(y,16)
                tm[#tm+1]={address=address, tileNum=tileNum, x=x,y=y}
                --printf("%s: %s, %s", tileNum, x, y)
            end
        end
        patcher.tileMap[n] = tm
    elseif keyword == 'eval' then
        local f=util.sandbox:loadCode('return '..data)
        print(f())
    elseif keyword == 'code' then
        local f=util.sandbox:loadCode(data)
        f()
    elseif keyword == 'text' then
        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        txt=data:sub((data:find(' ')+1))
        print(string.format("Setting ascii text: 0x%08x: %s",address,txt))
        txt=string.gsub(txt, "|", string.char(0))
        
        txt=mapText(txt)
        
        if not writeToFile(file, address+patcher.offset,txt) then quit("Error: Could not write to file.") end
    elseif keyword == 'textmap' then
        local mapOld = data:sub(1,(data:find(' ')-1))
        local mapNew = data:sub((data:find(' ')+1))
        textMap=textMap or {}
        if mapOld=="space" then
            textMap[" "]=hex2bin(mapNew)
        else
            mapNew=hex2bin(mapNew)
            for i=1,#mapOld do
                textMap[mapOld:sub(i,i)]=mapNew:sub(i,i)
            end
        end
    elseif keyword == 'hex' then
        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        txt=data:sub((data:find(' ')+1))
        txt = util.stripSpaces(txt)
        
        old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+#txt/2)
        old=bin2hex(old)
        print(string.format("Setting hex bytes: 0x%08x: %s --> %s",address,old, txt))
        if not writeToFile(file, address+patcher.offset,hex2bin(txt)) then quit("Error: Could not write to file.") end
    elseif keyword == 'gg' then
        local gg=data:upper()
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
            quit("Error: Bad gg length")
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
        if #gg == 6 then
            local value=tonumber(binString2:sub(1,8),2)
            local address=tonumber(binString2:sub(10),2)
            print(string.format("gg %s: 0x%08x value=0x%02x",gg,address,value))
        elseif #gg == 8 then
            local value = tonumber(binString2:sub(1,8),2)
            local address = tonumber(("1"..binString2:sub(10,24)),2)
            local compare = tonumber(binString2:sub(25,32),2)
            print(string.format("gg %s: 0x%08x compare=0x%02x value=0x%02x",gg,address,compare,value))
        end
    elseif startsWith(line, 'copy hex ') then
        local data=string.sub(line,10)
        local address = data:sub(1,(data:find(' ')))
        data = data:sub((data:find(' ')+1))
        local address2 = data:sub(1,(data:find(' ')))
        data = data:sub((data:find(' ')+1))
        local l = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        address2 = tonumber(address2, 16)
        l = tonumber(l, 16)
        data = patcher.fileData:sub(address+1+patcher.offset,address+1+patcher.offset+l-1)
        print(string.format("Copying 0x%08x bytes from 0x%08x to 0x%08x",l, address, address2))
        if not writeToFile(file, address2+patcher.offset,data) then quit("Error: Could not write to file.") end
    elseif line=="break" or line == "quit" or line == "exit" then
        print("[break]")
        --break
        breakLoop=true
    elseif line=="refresh" then
        patcher.fileData=getfilecontents(file)
    elseif keyword == 'start' then
        patcher.startAddress = tonumber(data, 16)
        print("Setting Start Address: "..data)
    elseif keyword == 'offset' then
        patcher.offset = tonumber(data, 16)
        print("Setting offset: "..data)
    elseif keyword == 'palette' then
        if startsWith(data, 'file') then
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
        else
            quit("Error: bad palette string length")
        end
    elseif keyword == 'diff' then
        local diff={}
        diff.fileName = data
        diff.data = getfilecontents(diff.fileName)
        diff.count=0
        printf("file1: %s bytes",#patcher.fileData)
        printf("file2: %s bytes",#diff.data)
        for i = 0,#patcher.fileData do
            diff.old =string.byte(patcher.fileData:sub(i+1,i+1))
            diff.new =string.byte(diff.data:sub(i+1,i+1))
            if diff.old~=diff.new then
                printf("%02x %06x  %02x | %02x",diff.count, i, diff.old,diff.new)
                diff.count=diff.count+1
                if diff.count>100 then break end
            end
        end
    elseif startsWith(line, 'ips ') then
        local ips = {}
        ips.n=string.sub(line,5)
        print("Applying ips patch: "..ips.n)
        --ips.file = io.open(ips.n,"r")
        ips.data = getfilecontents(ips.n)
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
--                quit("Error: Early end of file")
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
                if ips.chunkSize == 0 then quit("Error: bad RLE size") end
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
            if not writeToFile(file, ips.offset+patcher.offset,ips.replaceData) then quit("Error: Could not write to file.") end
            loopCount = loopCount+1
            if loopCount >=loopLimit then
                quit ("Error: Loop limit reached.")
            end
        end
        print("ips done.")
        
--        old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+#txt/2)
--        old=bin2hex(old)
    elseif keyword == 'readme' then
        if not (data == 'update') then
            quit("Error: bad or missing readme parameter.")
        end
        if (writeToFile("README.md",0,'```\n'..patcher.help.info ..'\n'.. patcher.help.description ..'\n'.. patcher.help.commands..'\n```')) then
            print('README updated')
        else
            print('README update failed')
        end
    elseif line == "" then
    else
        if patcher.interactive then
            print(string.format("unknown command: %s",line))
        else
            printVerbose(string.format("Unknown command: %s",line))
        end
    end
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
if not patcher.interactive then
    patchfile:close()
end
print('done.')
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
        version = "0.5.3",
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
        its length should be a multiple of 2.
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

    gg <gg code>
        WIP
        decode a NES Game Genie code (does not apply it)
        
    refresh
        refreshes the data so that keywords like "find text" will use the new
        altered data.
]]

if patcher.verbose then
    printVerbose = print
else
    printVerbose = function() end
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

function quit(text)
  if text then print(text) end
  os.exit()
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function startsWith(haystack, needle)
  return string.sub(haystack, 1, string.len(needle)) == needle
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

function writeToFile(file,address, data)
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

function mapText(txt)
    if not textMap then return txt end
    
    local txtNew=""
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
filedata=getfilecontents(file)

local patchfile
if not patcher.interactive==true then
    patchfile = io.open(arg[1] or "patch.txt","r")
    print(patcher.help.info)
end
local breakLoop = false
while true do
    local line
    if patcher.interactive==true then
        io.write(patcher.prompt)
        line = io.stdin:read("*l")
    else
        line = patchfile:read("*l")
    end
    if line == nil then break end
    lineOld=line
    line = trim(line)
    local status, err = pcall(function()
    
    if startsWith(line, '#') then
        print(string.sub(line,1))
    elseif startsWith(line, '//') then
        -- comment
    elseif startsWith(line, "help") then
        print(patcher.help.interactive)
    elseif startsWith(line, "commands") then
        print(patcher.help.commands)
    elseif startsWith(line, 'find hex ') then
        local data=string.sub(line,10)
        address=0
        print(string.format("Find hex: %s",data))
        for i=1,50 do
            --address = filedata:find(hex2bin(data),address+1+patcher.offset, true)
            address = filedata:find(hex2bin(data),address+1+patcher.offset, true)
            if address then
                if address>patcher.startAddress+patcher.offset then
                    print(string.format("    %s Found at 0x%08x",data,address-1-patcher.offset))
                end
            else
                break
            end
        end
    elseif startsWith(line, 'get hex ') then
        local data=string.sub(line,9)

        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        
        local len = data:sub((data:find(' ')+1))
        len = tonumber(len, 16)

        local old=filedata:sub(address+1+patcher.offset,address+patcher.offset+len)
        old=bin2hex(old)
        
        print(string.format("Hex data at 0x%08x: %s",address, old))
    elseif startsWith(line, 'find text') then
        local txt=string.sub(line,11)
        address=0
        print(string.format("Find text: %s",txt))
        for i=1,10 do
            address = filedata:find(mapText(txt),address+1+patcher.offset)
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
    elseif startsWith(line, 'fontdata ') then
        --local font = {"33":[0,0,0,0,0,8,8,8,8,8,0,8,0,0,0,0],"34":[0,0,0,0,0,20,20,0,0,0,0,0,0,0,0,0],"35":[0,0,0,0,0,0,40,124,40,40,124,40,0,0,0,0],"36":[0,0,0,0,16,56,84,20,56,80,84,56,16,0,0,0],"37":[0,0,0,0,0,264,148,72,32,144,328,132,0,0,0,0],"38":[0,0,0,0,0,48,72,48,168,68,196,312,0,0,0,0],"39":[0,0,0,0,0,8,8,0,0,0,0,0,0,0,0,0],"40":[0,0,0,0,0,8,4,4,4,4,4,8,0,0,0,0],"41":[0,0,0,0,0,4,8,8,8,8,8,4,0,0,0,0],"42":[0,0,0,0,32,168,112,428,112,168,32,0,0,0,0,0],"43":[0,0,0,0,0,0,16,16,124,16,16,0,0,0,0,0],"44":[0,0,0,0,0,0,0,0,0,0,24,24,16,8,0,0],"45":[0,0,0,0,0,0,0,0,60,0,0,0,0,0,0,0],"46":[0,0,0,0,0,0,0,0,0,0,24,24,0,0,0,0],"47":[0,0,0,0,0,16,16,8,8,8,4,4,0,0,0,0],"48":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"49":[0,0,0,0,0,8,8,8,8,8,8,8,0,0,0,0],"50":[0,0,0,0,0,24,36,32,16,8,4,60,0,0,0,0],"51":[0,0,0,0,0,24,36,32,24,32,36,24,0,0,0,0],"52":[0,0,0,0,0,32,36,36,60,32,32,32,0,0,0,0],"53":[0,0,0,0,0,60,4,4,24,32,36,24,0,0,0,0],"54":[0,0,0,0,0,24,36,4,28,36,36,24,0,0,0,0],"55":[0,0,0,0,0,60,32,32,16,8,8,8,0,0,0,0],"56":[0,0,0,0,0,24,36,36,24,36,36,24,0,0,0,0],"57":[0,0,0,0,0,24,36,36,56,32,36,24,0,0,0,0],"58":[0,0,0,0,0,0,24,24,0,0,24,24,0,0,0,0],"59":[0,0,0,0,0,0,24,24,0,0,24,24,16,8,0,0],"60":[0,0,0,0,0,32,16,8,4,8,16,32,0,0,0,0],"61":[0,0,0,0,0,0,0,60,0,0,60,0,0,0,0,0],"62":[0,0,0,0,0,4,8,16,32,16,8,4,0,0,0,0],"63":[0,0,0,0,0,24,36,32,16,8,0,8,0,0,0,0],"64":[0,0,0,0,240,264,612,660,660,484,8,240,0,0,0,0],"65":[0,0,0,0,0,24,36,36,60,36,36,36,0,0,0,0],"66":[0,0,0,0,0,28,36,36,28,36,36,28,0,0,0,0],"67":[0,0,0,0,0,24,36,4,4,4,36,24,0,0,0,0],"68":[0,0,0,0,0,28,36,36,36,36,36,28,0,0,0,0],"69":[0,0,0,0,0,60,4,4,28,4,4,60,0,0,0,0],"70":[0,0,0,0,0,60,4,4,28,4,4,4,0,0,0,0],"71":[0,0,0,0,0,24,36,4,52,36,36,24,0,0,0,0],"72":[0,0,0,0,0,36,36,36,60,36,36,36,0,0,0,0],"73":[0,0,0,0,0,28,8,8,8,8,8,28,0,0,0,0],"74":[0,0,0,0,0,60,16,16,16,20,20,8,0,0,0,0],"75":[0,0,0,0,0,36,36,20,12,20,36,36,0,0,0,0],"76":[0,0,0,0,0,4,4,4,4,4,4,60,0,0,0,0],"77":[0,0,0,0,0,68,68,108,84,84,68,68,0,0,0,0],"78":[0,0,0,0,0,68,76,84,84,84,100,68,0,0,0,0],"79":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"80":[0,0,0,0,0,28,36,36,28,4,4,4,0,0,0,0],"81":[0,0,0,0,0,24,36,36,36,52,36,88,0,0,0,0],"82":[0,0,0,0,0,28,36,36,28,36,36,36,0,0,0,0],"83":[0,0,0,0,0,24,36,4,24,32,36,24,0,0,0,0],"84":[0,0,0,0,0,124,16,16,16,16,16,16,0,0,0,0],"85":[0,0,0,0,0,36,36,36,36,36,36,24,0,0,0,0],"86":[0,0,0,0,0,68,68,68,68,40,40,16,0,0,0,0],"87":[0,0,0,0,0,84,84,84,84,84,56,40,0,0,0,0],"88":[0,0,0,0,0,68,68,40,16,40,68,68,0,0,0,0],"89":[0,0,0,0,0,68,68,40,16,16,16,16,0,0,0,0],"90":[0,0,0,0,0,60,32,16,16,8,4,60,0,0,0,0],"91":[0,0,0,0,0,28,4,4,4,4,4,28,0,0,0,0],"92":[0,0,0,0,0,4,4,8,8,8,16,16,0,0,0,0],"93":[0,0,0,0,0,28,16,16,16,16,16,28,0,0,0,0],"94":[0,0,0,0,0,24,36,0,0,0,0,0,0,0,0,0],"95":[0,0,0,0,0,0,0,0,0,0,0,0,508,0,0,0],"96":[0,0,0,0,0,4,8,0,0,0,0,0,0,0,0,0],"97":[0,0,0,0,0,0,0,24,32,56,36,88,0,0,0,0],"98":[0,0,0,0,0,0,4,4,28,36,36,28,0,0,0,0],"99":[0,0,0,0,0,0,0,0,24,4,4,24,0,0,0,0],"100":[0,0,0,0,0,0,32,32,56,36,36,88,0,0,0,0],"101":[0,0,0,0,0,0,0,24,36,28,4,56,0,0,0,0],"102":[0,0,0,0,0,0,48,8,8,28,8,8,0,0,0,0],"103":[0,0,0,0,0,0,0,0,88,36,36,56,32,36,24,0],"104":[0,0,0,0,0,0,4,4,4,28,36,36,0,0,0,0],"105":[0,0,0,0,0,0,8,0,12,8,8,8,0,0,0,0],"106":[0,0,0,0,0,0,0,16,0,24,16,16,16,12,0,0],"107":[0,0,0,0,0,0,0,4,20,12,20,20,0,0,0,0],"108":[0,0,0,0,0,0,4,4,4,4,4,8,0,0,0,0],"109":[0,0,0,0,0,0,0,0,4,88,168,168,0,0,0,0],"110":[0,0,0,0,0,0,0,0,4,28,36,36,0,0,0,0],"111":[0,0,0,0,0,0,0,0,24,36,36,24,0,0,0,0],"112":[0,0,0,0,0,0,0,4,56,72,72,56,8,8,8,0],"113":[0,0,0,0,0,0,0,0,88,36,36,56,32,32,64,0],"114":[0,0,0,0,0,0,0,0,52,72,8,8,0,0,0,0],"115":[0,0,0,0,0,0,0,24,4,24,32,24,0,0,0,0],"116":[0,0,0,0,0,0,8,8,28,8,8,16,0,0,0,0],"117":[0,0,0,0,0,0,0,0,36,36,36,88,0,0,0,0],"118":[0,0,0,0,0,0,0,0,68,68,40,16,0,0,0,0],"119":[0,0,0,0,0,0,0,0,84,84,84,40,0,0,0,0],"120":[0,0,0,0,0,0,0,0,36,24,24,36,0,0,0,0],"121":[0,0,0,0,0,0,0,0,36,36,36,56,32,36,24,0],"122":[0,0,0,0,0,0,0,0,60,16,8,60,0,0,0,0],"123":[0,0,0,16,8,8,8,4,8,8,8,16,0,0,0,0],"124":[0,0,0,8,8,8,8,8,8,8,8,8,0,0,0,0],"125":[0,0,0,4,8,8,8,16,8,8,8,4,0,0,0,0],"126":[0,0,0,0,0,0,0,24,292,192,0,0,0,0,0,0],"161":[0,0,0,0,0,8,0,8,8,8,8,8,0,0,0,0],"162":[0,0,0,0,0,0,16,56,20,20,56,16,0,0,0,0],"163":[0,0,0,0,0,48,8,8,28,8,8,60,0,0,0,0],"164":[0,0,0,0,0,0,132,120,72,72,120,132,0,0,0,0],"165":[0,0,0,0,68,40,16,56,16,56,16,16,0,0,0,0],"166":[0,0,0,8,8,8,8,0,8,8,8,8,0,0,0,0],"167":[0,0,0,0,0,0,48,72,8,48,72,72,48,64,72,48],"168":[0,0,0,0,0,108,108,0,0,0,0,0,0,0,0,0],"169":[0,0,0,0,240,264,612,532,532,612,264,240,0,0,0,0],"8364":[0,0,0,0,0,112,8,60,8,60,8,112,0,0,0,0],"name":"SlightlyFancyPix","copy":"SpiderDave","letterspace":"64","basefont_size":"512","basefont_left":"62","basefont_top":"0","basefont":"Arial","basefont2":""}
    elseif startsWith(line, 'export ') then
        if not gd then
            quit("Error: could not use export command because gd did not load.")
        end
        local dummy, address,len,fileName=unpack(util.split(line," ",3))
        address=tonumber(address,16)
        len=tonumber(len,16)*16
        
        --local old=filedata:sub(address+1+patcher.offset,address+patcher.offset+len)
        tileData = filedata:sub(address+1+patcher.offset,address+patcher.offset+len)
        --old=bin2hex(old)
        
        --print(string.format("Hex data at 0x%08x: %s",address, old))
        print(string.format("exporting tile data at 0x%08x",address))
        tileToImage(tileData, fileName)
        
    elseif startsWith(line, 'import ') then
        if not gd then
            quit("Error: could not use import command because gd did not load.")
        end
        local dummy, address,len,fileName=unpack(util.split(line," ",3))
        address=tonumber(address,16)
        len=tonumber(len,16)*16
        
        --local old=filedata:sub(address+1+patcher.offset,address+patcher.offset+len)
        --tileData = filedata:sub(address+1+patcher.offset,address+patcher.offset+len)
        --old=bin2hex(old)
        
        --print(string.format("Hex data at 0x%08x: %s",address, old))
        print(string.format("importing tile at 0x%08x",address))
        local tileData = imageToTile(len, fileName)
        if not writeToFile(file, address+patcher.offset,tileData) then quit("Error: Could not write to file.") end
    elseif startsWith(line, 'text ') then
        line=lineOld
        local data=string.sub(line,6)
        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        txt=data:sub((data:find(' ')+1))
        print(string.format("Setting ascii text: 0x%08x: %s",address,txt))
        txt=string.gsub(txt, "|", string.char(0))
        
        txt=mapText(txt)
        
        if not writeToFile(file, address+patcher.offset,txt) then quit("Error: Could not write to file.") end
    elseif startsWith(line, 'textmap ') then
        local data=string.sub(line,9)
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
    elseif startsWith(line, 'hex ') then
        local data=string.sub(line,5)
        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        txt=data:sub((data:find(' ')+1))
        old=filedata:sub(address+1+patcher.offset,address+patcher.offset+#txt/2)
        old=bin2hex(old)
        print(string.format("Setting hex bytes: 0x%08x: %s --> %s",address,old, txt))
        if not writeToFile(file, address+patcher.offset,hex2bin(txt)) then quit("Error: Could not write to file.") end
    elseif startsWith(line, 'gg ') then
        local data=string.sub(line,4)
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
        data = filedata:sub(address+1+patcher.offset,address+1+patcher.offset+l-1)
        print(string.format("Copying 0x%08x bytes from 0x%08x to 0x%08x",l, address, address2))
        if not writeToFile(file, address2+patcher.offset,data) then quit("Error: Could not write to file.") end
    elseif line=="break" or line == "quit" or line == "exit" then
        print("[break]")
        --break
        breakLoop=true
    elseif line=="refresh" then
        filedata=getfilecontents(file)
    elseif startsWith(line, 'start ') then
        local data=string.sub(line,7)
        patcher.startAddress = tonumber(data, 16)
        print("Setting Start Address: "..data)
    elseif startsWith(line, 'offset ') then
        local data=string.sub(line,8)
        patcher.offset = tonumber(data, 16)
        print("Setting offset: "..data)
    elseif startsWith(line, 'palette ') then
        local data=string.sub(line,9)
        if #data==8 then
            for i=0,3 do
                patcher.colors[i]=tonumber(string.sub(data,i*2+1,i*2+2),16)
                --print(patcher.colors[i])
            end
        else
            quit("Error: bad palette string length")
        end
    elseif startsWith(line, 'palette file ') then
        local fileName=string.sub(line,14)
        local data = getfilecontents(fileName)
        patcher.palette = {}
        i=1
        for c=0,63 do
            patcher.palette[c]={}
            for i=1,3 do
                patcher.palette[c][i]=rawToNumber(data:sub(c*3+i,c*3+i))
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
            
            print(string.format("replacing: 0x%08x %s", ips.offset, bin2hex(ips.replaceData)))
            
            printVerbose(string.format("0x%08x",ips.address))
            
            if not writeToFile(file, ips.offset+patcher.offset,ips.replaceData) then quit("Error: Could not write to file.") end
            
            loopCount = loopCount+1
            if loopCount >=loopLimit then
                quit ("Error: Loop limit reached.")
            end
        end
        print("ips done.")
        
--        old=filedata:sub(address+1+patcher.offset,address+patcher.offset+#txt/2)
--        old=bin2hex(old)
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
-- 
--
--                 ABANDON HOPE ALL YE WHO ENTER HERE
--                      (WARNING: SLOPPY CODE)
--
-----------------------------------------------------------------------------

-- ToDo:
--   * Clean up variable and function names
--   * Clean up scope of variables
--   * Add more asm set formats
--   * Create example scripts
--     *DONE* "SMB Chill" and "test" scripts so far.
--   * Create ips patches and other possible patch formats
--     + ips support done.  Needs RLE support.
--   * Better control when importing and exporting graphics:
--     + Set palette for each tilemap
--       *DONE* via "palette auto"
--   * Rework repeat so the repeated lines are evaluated for each iteration, not once
--       *DONE*
--   * Improve "find text" to include unknown characters
--   * Improve "find" to include unknown bytes
--   * Tilemap setting for precise placement or grid
--     *DONE* "gridsize" parameter in tilemaps makes this possible.
--   * Allow textmap to be flexible for characters with multiple codes
--   * search for locations of tiles using images
--   * create gg codes
--   * comment code better
--   * test/handle writes and reads outside length of file
--   * allow patch addresses like 02:1200
--   * allow graphics importing to use the closest color if it doesn't match exactly
--   * multiple (named) textmaps
--      *DONE*
--   * add output levels (verbose, silent, etc)
--      *DONE* using "verbose" keyword with new parameters.
--   * migrate some useful variables to the patcher's "special variables"
--   * test on other OS
--   * more cairo integration
--   * better control over graphics library to use
--   * split things off into seperate files, since we aren't using srlua anymore.
--   * better include paths
--     + search from a list
--   * fix goto statements and labels inside functions
--   * add more RET values
--   * use delimiter everywhere instead of just space

-- Notes:
--   * Keywords starting with _ are experimental or unfinished

local executionTime = os.clock()

table.unpack = table.unpack or unpack

require("include.Tserial")
local util = require("include.util")
util.deque = require("include.deque")
util.md5=require("include.md5")


local graphics = require("include.graphics")

require "os"
math.randomseed(os.time ()) math.random() math.random() math.random()

--local winapi = require("winapi")

local rand = require("include.random")
local rng = rand.newRandomGenerator()
rng:setSeed(math.random(65536))

version = version or {stage="",date="?",time="?"}

local allow_plugins = false
local plugins = {
}

--verbose levels: 
--0 quiet
--1 normal
--2 verbose
--3 verbose 2
--4 debug

local patcher = {
    info = {
        name = "DavePatcher",
        version = string.format("v%s%s", version.date, version.stage and " "..version.stage or ""),
        author = "SpiderDave",
        url = "https://github.com/SpiderDave/DavePatcher"
    },
    help={},
    startAddress=0,
    offset = 0,
    diffMax = 1000,
    gotoCount = 0,
    gotoLimit = 100,
    verboseLevel = 1,
    annotations = false,
    interactive = false,
    prompt = "> ",
    tileMap={},
    results={
        index = 0
    },
    base = 16,
    smartSearch={},
    variables = {
        DEFTYPE="str",
        LOGFILE="log.txt",
        BITOPER="NORMAL",
        REPLACELIMIT = 50,
        DELIM = " ",
    },
    autoRefresh = false,
    outputFileName = "output.nes",
    strict=false,
    breakLoop=false,
    tbl={},
    textMaps = {
        current = "default",
    },
}

-- Initialize to an empty file
patcher.fileData = ""
patcher.originalFileData = patcher.fileData
patcher.newFileData = patcher.fileData
patcher.variables.FILESIZE = #patcher.fileData

patcher.storage = {
    fileData="",
    originalFileData="",
    newFileData=""
}

local oldPrint = print
patcher.print = function(txt)
    txt = txt or ""
    if patcher.verboseLevel == 0 then return end
    if patcher.autolog== true or patcher.launcher then
        patcher.textOut=(patcher.textOut or "")..txt.."\n"
    else
        --print(txt)
        oldPrint(txt)
    end
end

print=patcher.print

patcher.path = love.filesystem.getSourceBaseDirectory()
patcher.variableStack = util.deque:new()

function patcher.setPalette(p)
    if #p~=8 then return false end
    for i=0,3 do
        patcher.colors[i]=tonumber(string.sub(p,i*2+1,i*2+2),16)
    end
    patcher.variables["PALETTE"] = string.format("%02x%02x%02x%02x", patcher.colors[0],patcher.colors[1],patcher.colors[2],patcher.colors[3])
end

-- This will print out directives for the launcher to use
function patcher.addLauncherDirective(k,v)
    if patcher.launcher then
        print(string.format("#launcher.%s=%s",k,v))
    end
end

function patcher.getHeader(str)
    local str = str or patcher.fileData:sub(1,16)
    local header = {
        id=str:sub(1,4),
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
    
    if header.id~="NES"..string.char(0x1a) then header.valid=false end
    patcher.variables["INES"]=true
    patcher.variables["CHRSTART"]=header.prg_rom_size*0x4000
    patcher.variables["CHRSIZE"]=header.chr_rom_size*0x2000
    patcher.variables["PRGCOUNT"]=header.prg_rom_size
    patcher.variables["CHRCOUNT"]=header.chr_rom_size
    return header
end

function patcher.load(f)
    patcher.fileName = f or patcher.fileName

    if not util.fileExists(patcher.fileName) then
        err('The file "%s" does not exist.', patcher.fileName)
    end

    printf("Loading file: %s",patcher.fileName)
    patcher.fileData = util.getFileContents(patcher.fileName)
    patcher.originalFileData = patcher.fileData
    patcher.newFileData = patcher.fileData
    patcher.variables.FILESIZE = #patcher.fileData
    pcall(function()
        patcher.header = patcher.getHeader()
    end)
end

-- Unloads current file/data
function patcher.unload()
    patcher.fileName = nil
    patcher.fileData = ""
    patcher.originalFileData = patcher.fileData
    patcher.newFileData = patcher.fileData
    patcher.variables.FILESIZE = #patcher.fileData

    patcher.header = nil
end

function patcher.makeIPS(oldData, newData)
    local a = 0
    local out = "PATCH"
    local d1,d2
    local nRecords = 0
    while true do
        if a > #newData then break end
        
        d1 = oldData:sub(a+1,a+1)
        d2 = newData:sub(a+1,a+1)
        if d1==d2 then
            a=a+1
        else
            local len = 1
            while true do
                d1 = oldData:sub(a+1+len,a+1+len)
                d2 = newData:sub(a+1+len,a+1+len)
                if (d1==d2) or len == 0xffff then
                    break
                else
                    len=len+1
                end
            end
            
            out = out..hex2bin(string.format("%06x",a)) -- address
            out = out..hex2bin(string.format("%04x",len)) -- length
            out = out..newData:sub(a+1,a+len)
            printVerbose("address:%s length:%s", string.format("%06x",a), string.format("%04x",len))
            
            nRecords = nRecords +1
            a=a+len
            if a > #newData then break end
        end
    end
    out = out.."EOF"
    --out = out..hex2bin(string.format("%04x",#newData)) -- truncate
    printVerbose("%s records",nRecords)
    return out
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


--local condition = load_code("return " .. args.condition, context)

util.toNumber = function(s, base)
    base = base or patcher.base
    local n
    if type(s)=="number" then return s end
    s=util.trim(s)
    if s=="_" then
        n=patcher.results[patcher.results.index].address
        patcher.results.index=patcher.results.index+1
    else
        local neg = 1
        if util.startsWith(s,"-") then
            s = util.split(s,"-",1)[2]
            neg = -1
        end
        if util.startsWith(s,"0x") then
            s = util.split(s,"0x",1)[2]
            base = 16
        elseif util.startsWith(s,"0o") then
            s = util.split(s,"0o",1)[2]
            base = 8
        elseif util.startsWith(s,"~h") then
            s = util.split(s,"~h",1)[2]
            base = 16
        elseif util.startsWith(s,"~o") then
            s = util.split(s,"~o",1)[2]
            base = 8
        elseif util.startsWith(s,"~b") then
            s = util.split(s,"~b",1)[2]
            base = 2
        elseif util.startsWith(s,"~d") then
            s = util.split(s,"~d",1)[2]
            base = 10
        end
        n=tonumber(s, base)
        if n then n=n*neg end
    end
    return n
end

util.toAddress = function(a)
    if util.trim(a) == "*" then
        a = patcher.variables["ADDRESS"] or "0" 
    end
    a = util.toNumber(a)
    return a
end

util.isTrue = function(n)
    if tonumber(n) == 0 then return nil end
    if n == "" then return nil end
    if type(n) == "string" and n:lower() == "false" then return false end
    if n then return true end
    return nil
end

-- The empty string is considered null
util.isNull = function(n)
    if n == "" then return true end
    if n then return false end
    return false
end

util.isTrueOrZero = function(n)
    if tonumber(n) == 0 then return true end
    if n == "" then return nil end
    if type(n) == "string" and n:lower() == "false" then return false end
    if n then return true end
    return nil
end

util.isEqual = function(a,b)
    if a==b then return true end
    if (tonumber(a)~=nil and tonumber(b)~=nil) and (tonumber(a)==tonumber(b)) then return true end
    return nil
end

printf = util.printf

util.random = math.random

function patcher.save(f)
    patcher.outputFileName = f or patcher.outputFileName or "output.nes"
    
    if util.endsWith(string.lower(patcher.outputFileName), ".ips") then
        printf("saving as ips patch to %s", patcher.outputFileName)
        if not util.writeToFile(patcher.outputFileName, 0, patcher.makeIPS(patcher.originalFileData,patcher.newFileData), true) then err("Could not write to file.") end    
    else
        printf("saving to %s", patcher.outputFileName)
        if not util.writeToFile(patcher.outputFileName, 0, patcher.newFileData, true) then err("Could not write to file.") end
    end
    patcher.saved = true
end

local asm = require("include.asm")
asm.init{util=util, variables=patcher.variables}
patcher.asm = asm

--print("#  l  op  mode")
--for i=0,255 do
--    if asm.set[i] then
--        local o=asm.set[i]
--        printf("%02x %02x %s %s",i,o.length or -1, o.opcode,o.mode)
        --printf('[0x%02x]={opcode="%s", mode="%s", length=%1x},',i,o.opcode,o.mode,o.length)
--    end
--end



patcher.help.extra = [[Some commands require Lua Cairo (recommended) <http://www.dynaset.org/dogusanh/luacairo.html>
--or--
Lua-GD <https://sourceforge.net/projects/lua-gd/>

For documentation, see <http://spiderdave.com/davepatcher/ref.php>
]]
patcher.help.info = string.format("%s %s - %s <%s>",patcher.info.name,patcher.info.version, patcher.info.author,patcher.info.url)
patcher.help.description = "A custom patcher for use with NES romhacking or general use."
patcher.help.usage = [[
Usage: davepatcher [options...] <patch file> [<file to patch>]
       davepatcher [options...] -i <file to patch>

Options:
  -h          show help
]]
--  -i          interactive mode (broken at the moment!)
patcher.help.interactive = [[Type "help" for this help, or "break" to quit.]]

printSilent = function(s, ...)
    if patcher.verboseLevel >=0 then
        return oldPrint(s:format(...))
    end
end
printNormal = function(s, ...)
    if patcher.verboseLevel >=1 then
        return print(s:format(...))
    end
end
printVerbose = function(s, ...)
    if patcher.verboseLevel >=2 then
        return print(s:format(...))
    end
end
printVerbose2 = function(s, ...)
    if patcher.verboseLevel >=3 then
        return print(s:format(...))
    end
end
printDebug = function(s, ...)
    if patcher.verboseLevel >=4 then
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


    if patcher.autolog then
        util.deleteFile(patcher.path.."/autolog.txt")
        if not util.logToFile(patcher.path.."/autolog.txt", patcher.textOut) then err("Could not write to file.") end
    end



    if love then
        love.event.push('quit')
    end
    os.exit()
end

function err(text,...)
    --love.window.showMessageBox("Error", text, "error", false)
    quit("Error: "..text,...)
end

function warning(text,...)
    if text then printf("Warning: "..text,...) end
    -- Does not exit unless strict mode
    if patcher.strict ==true then
        quit()
    end
end

local patch = {
    file = "patch.txt",
    index = 1,
    includeCount = 0,
    includeLimit = 20,
    f={},
    loopStack = util.deque:new()
}

function patch.load(file, opt)
    --print(package.path)
    
    local lines = {}
    local opt = opt or {}
    local patchLines ={}
    
    if opt.nofile then
        patchLines = opt.lines
    else
        file = file or patch.file

        if util.fileExists(file)==false then
            err("The file %s does not exist.",file)
        end
        
        for line in io.lines(file) do
            patchLines[#patchLines + 1] = line
        end
    end
    
    if opt.extra then
        for k,v in ipairs(opt.extra) do
            if util.fileExists(v) then
                patch.includeCount = patch.includeCount + 1
                if patch.includeCount > patch.includeLimit then
                    err("patch include limit exceeded.")
                end
                local l = patch.load(v)
                for i = 1,#l do
                    lines[#lines + 1] = l[i]
                end
            end
        end
    end
    
    for _,line in ipairs(patchLines) do
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
        
        if false then
        --if util.trim(line or "") == "" then
            --ignore empty lines
        elseif util.split(line," ",1)[1] == "_include" then
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
    if opt.returnOnly then return lines end
    patch.lines = lines
    return lines
end

function patcher.replaceVariables(line)
    local d=os.date("*t")
    patcher.variables["YEAR"] = string.format("%04d", d.year)
    patcher.variables["MONTH"] = string.format("%02d", d.month)
    patcher.variables["DAY"] = string.format("%02d", d.day)
    patcher.variables["HOUR"] = string.format("%02d", d.hour)
    patcher.variables["MIN"] = string.format("%02d", d.min)
    patcher.variables["SEC"] = string.format("%02d", d.sec)
    patcher.variables["WDAY"] = string.format("%02d", d.wday)
    patcher.variables["GD"] = gd and "true" or "false"
    
    patcher.variables["PALETTE"] = string.format("%02x%02x%02x%02x", patcher.colors[0],patcher.colors[1],patcher.colors[2],patcher.colors[3])
    
    -- using a closure thing here
    local f = function(k)
        return function()
            patcher.variables["RANDOMBYTE"]=rng:random(0,255)
            if patcher.fileData then
                patcher.variables["RANDOMADDRESS"] = util.random(1,#patcher.fileData-patcher.offset)
            else
                patcher.variables["RANDOMADDRESS"] = 0
            end
            v = patcher.variables[k]
            if type(v) == "number" then
                v = string.format("%x",v)
            end

            return v
        end
    end
    
    -- experimental delayed expansion stuff
    --line = string.gsub(line, "%$", "$%%")
    
    -- variable replacement
    for k,v in pairs(patcher.variables) do
        if type(v) == "number" then
            v = string.format("%x",v)
        end
        line = string.gsub(line, "%%"..k.."%%", f(k))
    end
    
    --line = string.gsub(line, "%$", "%%")
    return line
end

function patch.parseFunctionString(s)
    -- no (, not a function
    if not string.find(s,"%(") then return end
    
    -- space comes before (, not a function
    if string.match(s, " ") and (#util.split(s, "(",1)[1] > #util.split(s, " ",1)[1]) then
        return
    end
    -- == comes before (, not a function
    if string.match(s, "==") and (#util.split(s, "(",1)[1] > #util.split(s, "==",1)[1]) then
        return
    end
    
    
    local fname=util.split(s, "(",1)[1]
    local data=util.split(s, "==",1)[2]
    
    local param = util.split(s, "(",1)[2] or ""
    param = util.split(param, "==",1)[1]
    param = param:sub(1, -2) -- remove last character
    --printf("fname=%s, data=%s, param=%s",fname,data,param)
    return fname,param,data
end


function patch.parseLine(line)
    line = patcher.replaceVariables(line)
    
    local keyword, data
    keyword, data = unpack(util.split(line," ",1))
    
    
    -- if a ( comes before a space, then assume it's a function, so we'll make the whole line the keyword
    if (#util.split(line,"(",1)[1]>1) and (#util.split(line,"(",1)[1]<#keyword) then
        keyword=line
        data=""
    end
    
    
    local keywordOriginal=keyword
    keyword=keyword:lower()

    local assignment = false
    
    if #util.split(line, "=",1)>1  then
        local k, d = unpack(util.split(line,"=",1))
        
        k = util.trim(k)
        if #util.split(k, " ",1)==1 then
            keyword = k
            data = d
            assignment = true
        end
    end
    
    return line, {keyword=keyword, data=data, assignment=assignment,keywordOriginal=keywordOriginal}
end



function patch.readLine(replaceVariables)
    if replaceVariables == nil then replaceVariables = true end
    if patch.index > #patch.lines then return nil end

    local line = patch.lines[patch.index]
    local indent = #line-#util.ltrim(line)
    line = util.ltrim(line)
    
    if replaceVariables == true then
        line = patcher.replaceVariables(line)
    end
    
    patch.index = patch.index + 1
    
    return line, {indent=indent}
end

-- this stuff taken from bitty:
local tconcat = table.concat
local floor, ceil, max, log =
        math.floor, math.ceil, math.max, math.log
local tonumber, assert, type = tonumber, assert, type

local function tobittable_r(x, ...)
    if (x or 0) == 0 then return ... end
    return tobittable_r(floor(x/2), x%2, ...)
end

local function tobittable(x)
    assert(type(x) == "number", "argument must be a number")
    if x == 0 then return { 0 } end
    return { tobittable_r(x) }
end

local function makeop(cond)
    local function oper(x, y, ...)
        if not y then return x end
        x, y = tobittable(x), tobittable(y)
        local xl, yl = #x, #y
        local t, tl = { }, max(xl, yl)
        for i = 0, tl-1 do
            local b1, b2 = x[xl-i], y[yl-i]
            if not (b1 or b2) then break end
            t[tl-i] = (cond((b1 or 0) ~= 0, (b2 or 0) ~= 0)
                    and 1 or 0)
        end
        return oper(tonumber(tconcat(t), 2), ...)
    end
    return oper
end
local band = makeop(function(a, b) return a and b end)
local bor = makeop(function(a, b) return a or b end)
local bxor = makeop(function(a, b) return a ~= b end)
local function bnot(x, bits) return bxor(x, (2^(bits or floor(log(x, 2))))-1) end
local function blshift(x, bits) return floor(x) * (2^bits) end
local function brshift(x, bits) return floor(floor(x) / (2^bits)) end
local function tobin(x, bits)
    local r = tconcat(tobittable(x))
    return ("0"):rep((bits or 1)+1-#r)..r
end
local function frombin(x)
    return tonumber(x:match("^0*(.*)"), 2)
end
local function bisset(x, bit, ...)
    if not bit then return end
    return brshift(x, bit)%2 == 1, bisset(x, ...)
end
local function bset(x, bit)
    return bor(x, 2^bit)
end
local function bunset(x, bit)
    return band(x, bnot(2^bit, ceil(log(x, 2))))
end
local function repr(x)
    return (type(x)=="string" and ("%q"):format(x) or tostring(x))
end
-------------

function storageMode()
    return util.isTrue(patcher.variables.STORAGE)
end

function patcher.read(address, len)
    local old
    if storageMode() then
        old=patcher.storage.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
    else
        old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
    end
    return old
end

-- Write data to patcher.newFileData
function patcher.write(address, data)
    local old
    local storageMode=storageMode()
    
    if storageMode then
        old=patcher.storage.fileData:sub(address+1,address+#data)
    else
        old=patcher.fileData:sub(address+1,address+#data)
    end
    old=bin2hex(old)
    local new = bin2hex(data)
    patcher.variables["OLDDATA"] = old
    patcher.variables["NEWDATA"] = new

    if bit[patcher.variables["BITOPER"]] then
        local new2=""
        for i=0,#old/2-1 do
            local n = tonumber(old:sub(i*2+1,i*2+2),16)
            local n2 = tonumber(new:sub(i*2+1,i*2+2),16)
            new2=new2..string.format("%02x", bit.oper(n,n2,bit[patcher.variables["BITOPER"]]))
        end
        patcher.variables["NEWDATA"] = new2
        data = hex2bin(new2)
    end
    
    if storageMode then
        -- expand it
        if #patcher.storage.newFileData < address then
            patcher.storage.newFileData = patcher.storage.newFileData..util.hex2bin(string.rep("00", address-#patcher.storage.newFileData+1))
        end
    else
        -- expand it
        if #patcher.newFileData < address then
            patcher.newFileData = patcher.newFileData..util.hex2bin(string.rep("00", address-#patcher.newFileData+1))
        end
    end
    
    if storageMode then
        patcher.storage.newFileData = patcher.storage.newFileData:sub(1,address) .. data .. patcher.storage.newFileData:sub(address+#data+1)
        if patcher.autoRefresh == true then
            patcher.storage.fileData = patcher.storage.newFileData
            patcher.variables.FILESIZE = #patcher.storage.fileData
        end
    else
        patcher.newFileData = patcher.newFileData:sub(1,address) .. data .. patcher.newFileData:sub(address+#data+1)
        if patcher.autoRefresh == true then
            patcher.fileData = patcher.newFileData
            patcher.variables.FILESIZE = #patcher.fileData
        end
    end
    
end

bin2hex=util.bin2hex
hex2bin=util.hex2bin

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
    
    --local image = gd.createFromPng(fileName)
    local image = graphics:loadPng(fileName)
    local h = math.max(8,math.floor(nTiles/16)*8)
    local w = math.min(16, nTiles)*8
    local colors={}
    for i=0,3 do
        colors[i]=patcher.palette[patcher.colors[i]]
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
                local r,g,b = graphics:getPixel(image, x+xo, y+yo)
                
                for i=0,3 do
                    local pr,pg,pb = table.unpack(patcher.palette[patcher.colors[i]])
                    if string.format("%02x%02x%02x",r,g,b) == string.format("%02x%02x%02x",pr,pg,pb) then
                        out.t[t][y]=out.t[t][y] + (2^(7-x)) * (i%2)
                        out.t[t][y+8]=out.t[t][y+8] + (2^(7-x)) * (math.floor(i/2))
                    end
                end
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

function imageToTile3(tileMap, fileName)
    local tm=patcher.tileMap[tileMap]
    local out = {
        t={},
        th={},
        pos={},
    }
    nTiles=32*32
    
    local image = graphics:loadPng(fileName)
    local h = math.max(8,math.floor(nTiles/16)*8)
    local w = math.min(16, nTiles)*8
    h=256
    w=256

    local colors={}
    for i=0,3 do
        colors[i]=patcher.palette[patcher.colors[i]]
    end
    local xo=0
    local yo=0
    
    local tilemapX = util.toNumber(patcher.variables["TILEMAPX"] or 0)
    local tilemapY = util.toNumber(patcher.variables["TILEMAPY"] or 0)
    
    local f = function(xo,yo)
        local pr,pg,pb = table.unpack(patcher.palette[patcher.colors[3]])

        out = {}
        for y = 0, 7 do
            out[y] = 0
            out[y+8] = 0
            for x=0, 7 do
                local r,g,b = graphics:getPixel(image, x+xo+tilemapX, y+yo+tilemapY)
                for i=0,3 do
                    local pr,pg,pb = table.unpack(patcher.palette[patcher.colors[i]])
                    if string.format("%02x%02x%02x",r,g,b) == string.format("%02x%02x%02x",pr,pg,pb) then
                        out[y]=out[y] + (2^(7-x)) * (i%2)
                        out[y+8]=out[y+8] + (2^(7-x)) * (math.floor(i/2))
                    end
                end
            end
        end
        xo=xo+8
        if xo>=w then
            xo=0
            yo=yo+8
        end

        return out
    end

    --local tileData = ""
    local tileData = {} --It's an array here, because it's not guaranteed to be a continuous string of data; it can have gaps.
    
    -- Iterate the tilemap
    for i=1,#tm do
        tileData[i]={}
        
        local t=tm[i].tileNum
        
        
        local tileImageData = f(tm[i].realX,tm[i].realY)
        
        local o=""
        if tm[i].flip.horizontal and tm[i].flip.vertical then
            for j=7,0,-1 do
                local b = tileImageData[j]
                local b2=0
                for jj=0,7 do
                    if bit.isSet(b, 7-jj) then
                        b2=b2+2^jj
                    end
                end
                o=o..string.char(b2)
            end
            for j=15,8,-1 do
                local b = tileImageData[j]
                local b2=0
                for jj=0,7 do
                    if bit.isSet(b, 7-jj) then
                        b2=b2+2^jj
                    end
                end
                o=o..string.char(b2)
            end
        elseif tm[i].flip.vertical then
            for j=7,0,-1 do
                o=o..string.char(tileImageData[j])
            end
            for j=15,8,-1 do
                o=o..string.char(tileImageData[j])
            end
        elseif tm[i].flip.horizontal then
            --err('test')
            for j=0,#tileImageData do
                local b = tileImageData[j]
                local b2=0
                for jj=0,7 do
                    if bit.isSet(b, 7-jj) then
                        b2=b2+2^jj
                    end
                end
                o=o..string.char(b2)
            end
        else
            for j=0,#tileImageData do
                if tileImageData[j]>=0x100 then
                    print(string.format("%02x %02x (%02x,%02x)",j, tileImageData[j], tm[i].realX, tm[i].realY))
                    --o=o..string.char(math.floor(tileImageData[j] / 0x100))
                    --o=o..string.char(tileImageData[j] % 0x100)
                    
                else
                    o=o..string.char(tileImageData[j])
                end
                
                
            end
        end
        
        tileData[i].t = o                           -- the tile data for this tile to be applied
        tileData[i].address = tm[i].address + t*16  -- the address to apply it to
    end
    
    return tileData
end

function tileToImage(tileData, fileName)
    local nTiles = #tileData/16
    
    local h = math.max(8,math.floor(nTiles/16)*8)
    local w = math.min(16, nTiles)*8
    local image = graphics:createImage(w,h)
    local colors={}
    for i=0,3 do
        colors[i] = patcher.palette[patcher.colors[i]]
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
                graphics:setPixel(image, x+xo,y+yo,table.unpack(colors[c]))
            end
        end
        xo=xo+8
        if xo>=w then
            xo=0
            yo=yo+8
        end
    end
    graphics:savePng(image, fileName)
end

function tileToImage2(tileMap, fileName)
    local tm=patcher.tileMap[tileMap]
    
    if not tm then return false, "Invalid tilemap "..tileMap end
    
    -- get width and height large enough to fit the tilemap
    local w = tm.width
    local h = tm.height
    local tilemapX = util.toNumber(patcher.variables["TILEMAPX"] or 0)
    local tilemapY = util.toNumber(patcher.variables["TILEMAPY"] or 0)
    
    
    w=w+tilemapX
    h=h+tilemapY
    
    
    local image
    
    if util.fileExists(fileName) then
        image = graphics:loadPng(fileName)
        if not image then err("could not load image.") end
    else
        image = graphics:createImage(w,h)
        if not image then err("could not create image.") end
    end
    
    local width, height = graphics:getSize(image)
    
    if (w > width) or (h > height) then
        -- expand width or height if the tilemap doesn't fit
        local newWidth, newHeight = width, height
        if w > newWidth then newWidth = w end
        if h > newHeight then newHeight = h end
        local newImage = graphics:createImage(newWidth,newHeight)
        graphics:copy(newImage, image, 0,0,width,height,0,0)
        --graphics:copy(image, newImage, 0,0,width,height,0,0)
        image = newImage
    end
    
    local colors={}
    for i=0,3 do
        colors[i]=patcher.palette[patcher.colors[i]]
    end
    local xo=0
    local yo=0
    
    local tileData = ""
    for i=1,#tm do
        local address = tm[i].address + tm[i].tileNum*16
        local len = 16
        tileData = patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
        for y = 0, 7 do
            local byte = string.byte(tileData:sub(y+1,y+1))
            local byte2 = string.byte(tileData:sub(y+9,y+9))
            for x=0, 7 do
                local c=0
                if bit.isSet(byte,7-x)==true then c=c+1 end
                if bit.isSet(byte2,7-x)==true then c=c+2 end
                xo=tm[i].x * tm[i].gridSize + tm[i].adjust.x or 0
                yo=tm[i].y * tm[i].gridSize + tm[i].adjust.y or 0
                if tm[i].flip.horizontal and tm[i].flip.vertical then
                    graphics:setPixel(image, 7-x+xo+ tilemapX,7-y+yo+ tilemapY, table.unpack(colors[c]))
                elseif tm[i].flip.horizontal then
                    graphics:setPixel(image, 7-x+xo+ tilemapX,y+yo+ tilemapY, table.unpack(colors[c]))
                elseif tm[i].flip.vertical then
                    graphics:setPixel(image, x+xo+ tilemapX,7-y+yo+ tilemapY, table.unpack(colors[c]))
                else
                    graphics:setPixel(image, x+xo+ tilemapX,y+yo+ tilemapY, table.unpack(colors[c]))
                end
            end
        end
    end
    graphics:savePng(image, fileName)
    return true
end

if arg[1]=="-readme" then
    print("-readme switch no longer supported.")
    quit()
end

if arg[1]=="-launcher" then
    -- patcher was launched from the launcher.
    patcher.launcher = true
end

if arg[1]=="-launcher" then
    patcher.launcher=true
end

if arg[1]=="-autolog" or patcher.launcher then
    patcher.autolog=true
--    print=function(txt)
--        patcher.textOut=(patcher.textOut or "")..txt.."\n"
--    end
    table.remove(arg,1)
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
    patcher.load(arg[2])
end

if arg[1] == "-i" then
    patcher.interactive = true
    print(patcher.help.info)
    print(patcher.help.interactive)
end

if arg[1] == "-nofile" then
    patcher.nofile = true
    print("no file mode")
    
    --patch.lines = {
    local l= {
        "start function interactive",
        "    print",
        "    help",
        "    start loop",
        "        getinput > ",
        "        if %INPUT% == break",
        "            print",
        "            break loop",
        "        else",
        "            %INPUT%",
        "        end if",
        "    end loop",
        "end function",
        "interactive()",
        "break",
    }

    patch.index = 1
    
    local opt = {
        nofile=true,
        lines = l,
    }
    patch.load(nil, opt)
end


file_dumptext = nil

if (not patcher.interactive==true) and (not patcher.nofile==true) then
    local opt = {
        _extra = {"default.txt"}
    }
    patch.load(arg[1] or "patch.txt", opt)
    print(patcher.help.info)
end

while true do
    local writeToFile = util.writeToFile
    local line
    local opt = {indent=0}
    if patcher.interactive==true then
        --io.write(patcher.prompt)
        io.stdout:write(patcher.prompt)
        line = io.stdin:read("*l")
        --line = patcher.replaceVariables(line)
    else
        line, opt = patch.readLine(false)
    end
    if line == nil then break end
    local status, err = pcall(function()
    
    local indent = opt.indent
    
    line, opt = patch.parseLine(line)
    
    local keyword = opt.keyword
    local keywordOriginal = opt.keywordOriginal
    local data = opt.data
    local assignment = opt.assignment
    local fillVar = nil
    local asmLabel = nil
    
    
    patcher.lineQueue={}
    if keyword == "repeat" then
        patcher.lineQueue.r = util.toNumber(data)
        printf("repeat %02x",patcher.lineQueue.r)
        while true do
            line = patch.readLine(false)
            keyword,data = unpack(util.split(line," ",1))
            keyword=keyword:lower()
            --if keyword == "end repeat" then break end
            if util.startsWith(line, "end repeat") then break end
            patcher.lineQueue[#patcher.lineQueue+1]={line=line,keyword=keyword,data=data}
        end
    end
    
    --for loopCount = 1,lineQueue.count or 1 do
    local lineRepeat, r
    for lineRepeat = 1, patcher.lineQueue.r or 1 do
    for r=1,math.max(#patcher.lineQueue, 1) do
        if #patcher.lineQueue>=1 then
            --patcher.lineQueue[r].line = patcher.replaceVariables(patcher.lineQueue[r].line)
            patcher.variables.INDEX = lineRepeat
            
            line=patcher.lineQueue[r].line
            --line = patcher.replaceVariables(line)
            
            --keyword,data = unpack(util.split(line," ",1))
            --keyword=keyword:lower()
            
            local opt
            line, opt = patch.parseLine(line)
            
            keyword = opt.keyword
            keywordOriginal = opt.keywordOriginal
            data = opt.data
            assignment = opt.assignment
            
            
            --keyword,data=patcher.lineQueue[r].keyword,patcher.lineQueue[r].data
        end
        
        if patcher.asmMode then
            --print("----"..line)
        end
        if patcher.asmMode and data then
            data = util.split(data, ";",1)[1]
        end
        
        if patcher.asmMode and (util.trim(keyword):match("^([%a_]+[%w_]*):$")) then
            asmLabel = {
                name=util.trim(keyword):match("^([%a_]+[%w_]*):$"),
                address = patcher.asmAddress,
            }
            
            --printf("(asm label address=%08x) %s:", asmLabel.address, asmLabel.name)
            
            if data then
                data = util.trim(data)
                keyword = util.trim(util.split(data, " ",1)[1])
                data = util.trim(util.split(data, " ",1)[2])
                --printf("*** k=[%s] d=[%s]",keyword,data)
            else
                keyword = "asmlabel"
            end
        end
        
        if util.split(line or "",":=",1)[2] then
            fillVar = util.split(line,":=",1)[1]
            --data = util.split(line,":=",1)[2]
            line = util.ltrim(util.split(line,":=",1)[2])
            local opt
            line, opt = patch.parseLine(line)
            keyword = opt.keyword
            keywordOriginal = opt.keywordOriginal
            data = opt.data
            assignment = opt.assignment
        end
        
        if util.split(data or "","-->",1)[2] then
            fillVar = util.split(data,"-->",1)[2]
            data = util.split(data,"-->",1)[1]
            line = util.split(line,"-->",1)[1]
        end
        
        if util.split(keyword or "","-->",1)[2] then
            fillVar = util.split(keyword,"-->",1)[2]
            keyword = util.split(keyword,"-->",1)[1]
            line = util.split(line,"-->",1)[1]
        end
        
        if util.startsWith(line, "#") then
            if patcher.annotations or patcher.verboseLevel >= 2 then
                print(string.sub(line,1))
            end
        elseif util.startsWith(line:lower(), "print asm ") then
            hexData=string.sub(line,11)
            
            print(string.format("Analyzing ASM data:\n[%s]",hexData))
            print()
            print(asm.print(hexData, util.toNumber(patcher.variables.ORG) or 0))
        elseif (not patcher.asmMode) and keyword == "increment" then
            patcher.variables[data] = patcher.variables[data] + 1
        elseif (not patcher.asmMode) and keyword == "decrement" then
            patcher.variables[data] = patcher.variables[data] - 1
        elseif keyword == "_parsetest" then
            --function patcher.replaceVariables(line)
            
            printf("data=", data or "")
            for k,v in ipairs(util.split(data, "+")) do
                print(v)
            end
            
            --print(data or "")
        elseif keyword == "print" then
            print(data or "")
        elseif keyword == "echo" then
            print(data or "")
            patcher.variables.RET= data or ""
        elseif keyword == "print2" then
            local l=patcher.verboseLevel
            patcher.verboseLevel = 1
            print(data or "")
            patcher.verboseLevel = l
        elseif keyword == "choose" then
            local choice = util.split(data,patcher.variables.DELIM)
            choice = choice[rng:random(1, #choice)]
            patcher.variables['CHOICE'] = choice
            patcher.variables['RET'] = choice
        elseif keyword == "split" then
            for i,v in ipairs(util.split(data,patcher.variables.DELIM)) do
                patcher.variables['SPLIT'..string.format("%x",i)] = v
            end
        elseif keyword == "join" then
            local ret = ""
            for k,v in ipairs(util.split(data,patcher.variables.DELIM)) do
                ret = ret .. v
            end
            patcher.variables.RET= ret
        elseif (keyword == "interpolate") or (keyword == "interp") then
            -- Performs string interpolate on the input.  note that the usual string interpolation 
            -- is done automatically on the input as usual, so this is processing it again, making
            -- "variable variables" possible.
            --
            -- foo1=bar
            -- foo2=baz
            -- i=2
            -- interpolate foo%i%-->n
            -- // n==baz
            patcher.variables.RET=patcher.variables[patcher.replaceVariables(data)]
        elseif keyword == "_random" then
            local r = rng:random(0, 255)
            patcher.variables['RET'] = r
        elseif util.startsWith(line, "//") then
            -- comment
        elseif keyword == "silent" then
            local err, switch
            switch, err = util.switch(data, true)
            if err then
                warning('Invalid switch value for %s: "%s"',keyword, data)
            elseif switch then
                patcher.verboseLevel = 0
            else
                patcher.verboseLevel = 1
            end
        elseif keyword == "verbose" then
            if data == "silent" or data == "quiet" then
                printVerbose2("Verbose level: %d",patcher.verboseLevel)
                patcher.verboseLevel = 0
            elseif data == "normal" or data == "" then
                printVerbose2("Verbose level: %d",patcher.verboseLevel)
                patcher.verboseLevel = 1
            elseif data == "verbose" then
                printVerbose2("Verbose level: %d",patcher.verboseLevel)
                patcher.verboseLevel = 2
            elseif data == "verbose2" then
                printVerbose2("Verbose level: %d",patcher.verboseLevel)
                patcher.verboseLevel = 3
            elseif data == "debug" then
                printVerbose2("Verbose level: %d",patcher.verboseLevel)
                patcher.verboseLevel = 4
            else
                local err, switch
                switch, err = util.switch(data, true)
                if err then
                    warning('Invalid switch value for %s: "%s"',keyword, data)
                elseif switch then
                    -- verbose on
                    -- set verboseLevel to verbose
                    patcher.verboseLevel = 2
                else
                    -- verbose off
                    -- set verboseLevel to normal
                    patcher.verboseLevel = 1
                end
                
            end
        elseif keyword == "strict" or keyword == "annotations" then
            local err
            patcher[keyword], err = util.switch(data, true)
            if err then
                warning('Invalid switch value for %s: "%s"',keyword, data)
            elseif patcher[keyword] then 
                printf("%s on", keyword)
            else
                printf("%s off", keyword)
            end
        elseif keyword == "include" then
--            print(love.filesystem.getSourceBaseDirectory( ))
            local path = love.filesystem.getWorkingDirectory( )
            --print("include path: ",path)
            
            local f = util.trim(data)
            if f=="config.txt" then
                patcher.addLauncherDirective("config", f)
            elseif f=="tilemaps.txt" then
                patcher.addLauncherDirective("tilemaps", f)
            end
            if util.startsWith(f, "/") then
                f = patcher.path..f
            else
                --f = path.."/"..f
            end
            
            
            while util.startsWith(f, "../") do
                f = util.split(f,"../",1)[2]
                path=util.upFolder(path)
            end
            f = path.."/"..f

            local i = patch.index
            
            local lines = patch.load(f, {returnOnly=true})
            for k,v in pairs(lines) do
              table.insert(patch.lines, i, v)
              --printf("line[%02x] [%s]",k,v)
              i=i+1
            end
--            for k,v in pairs(patch.lines) do
--              printf("line[%02x] [%s]",k,v)
--            end

        elseif keyword == "help" then
            print(patcher.help.interactive)
        elseif keyword == "_corrupt" then
            local address = util.random(1,#patcher.fileData-patcher.offset)
            local len = 1
            local oldData=bin2hex(patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len))
            local newData = bin2hex(string.char(util.random(255)))
            
            printf("Corrupting data at 0x%08x: %s --> %s",address, oldData, newData)
            patcher.write(address+patcher.offset,hex2bin(newData))
        elseif util.startsWith(line:lower(), "_smartsearch lives ") then
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
                    if results2_flags[a] or (a=="00" or a=="01" or a=="02" or a=="03") then
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
        elseif keyword == "hi" then
            address = string.format("%04x", util.toAddress(data))
            local hi = string.sub(address, 1,2)
            local lo = string.sub(address, 3,4)
            patcher.variables["RET"] = hi
            patcher.variables["HI"] = hi
            patcher.variables["LO"] = lo
            printf(hi)
        elseif keyword == "lo" then
            address = string.format("%04x", util.toAddress(data))
            local hi = string.sub(address, 1,2)
            local lo = string.sub(address, 3,4)
            patcher.variables["RET"] = lo
            patcher.variables["HI"] = hi
            patcher.variables["LO"] = lo
            printf(lo)
        elseif keyword == "pointer" then
            address = string.format("%04x", util.toAddress(data))
            local hi = string.sub(address, 1,2)
            local lo = string.sub(address, 3,4)
            patcher.variables["RET"] = lo..hi
            patcher.variables["HI"] = hi
            patcher.variables["LO"] = lo
            printf(lo..hi)
        elseif keyword == "delim" then
            patcher.variables.DELIM = data or " "
            printf('Setting delimiter to "%s"', patcher.variables.DELIM)
        elseif keyword == "replace" then
            local limit = patcher.variables["REPLACELIMIT"]
            
            if util.split(util.ltrim(data), " ",1)[1]=="hex" then
                data = util.split(util.ltrim(data), " ",1)[2]
                warning('depreciated keyword "replace hex". use "replace" instead')
            end
            
            if util.split(util.ltrim(data), " ",1)[1]=="limit" then
                --limit = util.trim(util.split(util.ltrim(data), " ")[2])
                --data = util.split(util.ltrim(data), " ",2)[3]
                patcher.variables["REPLACELIMIT"] = util.toNumber(util.split(util.ltrim(data), " ",1)[2])
                printf('Setting replace limit: %s',patcher.variables["REPLACELIMIT"])
            else
                data = util.ltrim(data)
                
                local text=false
                local findValue, replaceValue
                local findText, replaceText
                if util.split(data, " ")[1]=="text" then
                    data = util.split(data, " ", 1)[2]
                    text=true
                end
                
                --local data=string.sub(line,13)
                local address=0
                
                if text then
                    --print((patcher.variables.DELIM or "?").."********")
                    findText = util.split(data, patcher.variables.DELIM or " ")[1]
                    replaceText = util.split(data, patcher.variables.DELIM or " ")[2]

                    findValue = bin2hex(mapText(findText))
                    replaceValue = bin2hex(mapText(replaceText))
                else
                    findValue = util.split(data, patcher.variables.DELIM or " ")[1]
                    replaceValue = util.split(data, patcher.variables.DELIM or " ")[2]
                end
                
                local nResults = 0
                
                if util.split(data, patcher.variables.DELIM or " ")[3] then
                    limit = tonumber(util.split(data, " ")[3],16)
                end
                
                if text then
                    print(string.format("Find and replace text: %s --> %s (limit %s)",findText, replaceText, limit))
                else
                    print(string.format("Find and replace hex: %s --> %s (limit %s)",findValue, replaceValue, limit))
                end
                patcher.results.clear()
                
                while true do
                --for i=1,50 do
                    --address = patcher.fileData:find(hex2bin(findValue),address+1+patcher.offset, true)
                    address = patcher.fileData:find(hex2bin(findValue),address+1, true)
                    if (address or 0) > #patcher.fileData-1 then
                        patcher.variables["ADDRESS"] = 0
                        break
                    end

                    if address then
                        if address>patcher.startAddress+patcher.offset then
                            print(string.format("    %s Found at 0x%08x, replacing with %s",findValue,address-1-patcher.offset,replaceValue))
                            patcher.write(address-1,hex2bin(replaceValue))
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
                    patcher.variables["ADDRESS"] = patcher.results[#patcher.results].address+1
                else
                    patcher.lastFound = nil
                end

            end
        elseif util.startsWith(line:lower(), "get asm ") then
            local data=string.sub(line,9)

            local address = data:sub(1,(data:find(" ")))
            address = util.toNumber(address, 16)
            
            local len = data:sub((data:find(" ")+1))
            len = util.toNumber(len, 16)

            local hexData=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            hexData=bin2hex(hexData)
            
            print(string.format("Analyzing data at 0x%08x:\n[%s]",address, hexData))
            print()
            print(asm.print(hexData, util.toNumber(patcher.variables.ORG) or 0))
        elseif util.startsWith(line:lower(), "get hex ") then
            warning('depreciated keyword "get hex". use "get" instead')
            local data=string.sub(line,9)

            local address = data:sub(1,(data:find(" ")))
            address = tonumber(address, 16)
            
            local len = data:sub((data:find(" ")+1))
            len = tonumber(len, 16)

            --local old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            local old=patcher.read(address,len)
            old=bin2hex(old)
            
            print(string.format("Data at 0x%08x: %s",address, old))
        elseif util.startsWith(line:lower(), "get text ") then
            local data=string.sub(line,10)
            local address = data:sub(1,(data:find(" ")))
            --address = tonumber(address, 16)
            address = util.toAddress(address)
            local len = data:sub((data:find(" ")+1))
            len = tonumber(len, 16)
            
            local old=patcher.read(address,len)
            
            --old=bin2hex(old)
            local txt=mapText(old,true)
            print(string.format("Text data at 0x%08x: %s",address, txt))
            patcher.variables["ADDRESS"] = string.format("%x",address + #old)
            patcher.variables["RET"] = txt
        elseif keyword == "get" then
            local data=string.sub(line,5)
            --local address = util.split(data, " ",1)[1]
            --local len = util.split(data, " ",1)[2]

            local address = data:sub(1,(data:find(" ")))
            address = util.toAddress(address)
            
            local len = data:sub((data:find(" ")+1))
            len = util.toNumber(len)

            --local old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            local old=patcher.read(address,len)
            old=bin2hex(old)
            
            print(string.format("Data at 0x%08x: %s",address, util.limitString(old)))
            patcher.variables["ADDRESS"] = string.format("%x",address + #old/2)
            patcher.variables["DATA"] = old
            patcher.variables["RET"] = old
        elseif util.startsWith(line, "find text ") then
            local txt=string.sub(line,11)
            address=patcher.offset
            local startAddress=0
            local firstFound
            print(string.format("Find text: %s",txt))
            for i=1,10 do
                
                if storageMode() then
                    --address = patcher.storage.fileData:find(mapText(txt),startAddress+1+patcher.offset, true)
                    address = patcher.storage.fileData:find(mapText(txt),startAddress+1, true)
                else
                    --address = patcher.fileData:find(mapText(txt),startAddress+1+patcher.offset, true)
                    address = patcher.fileData:find(mapText(txt),startAddress+1, true)
                end
                if address then
                    --startAddress = address-#txt
                    startAddress = address
                    if address>patcher.startAddress+patcher.offset then
                        print(string.format("    %s Found at 0x%08x",txt,address-1-patcher.offset))
                        if not firstFound then
                            firstFound=address-1-patcher.offset
                        end
                        patcher.variables["ADDRESS"]=address-1-patcher.offset+#txt
                    end
                else
                    if i==1 then
                        print "    Not found."
                    end
                    break
                end
            end
            patcher.variables["RET"]=firstFound
        elseif keyword == "bitop" then
            if data then data = data:upper() end
            if bit[data] then
                patcher.variables["BITOPER"] = data
            else
                patcher.variables["BITOPER"] = "NORMAL"
            end
        elseif keyword == "address" then
            if data then
                patcher.variables["ADDRESS"] = data
            end
        elseif keyword == "exist" then
            if util.fileExists(data) then
                patcher.variables["RET"] = 1
                printf('File "%s" exists.', data)
            else
                patcher.variables["RET"] = 0
                printf('File "%s" does not exist.', data)
            end
            
        elseif keyword == "find" then
            if util.split(util.ltrim(data), " ",1)[1]=="hex" then
                data = util.split(util.ltrim(data), " ",1)[2]
                warning('depreciated keyword "find hex". use "find" instead')
            end
            
            address = patcher.offset
            print(string.format("Find: %s",data))
            data = util.stripSpaces(data)
            patcher.results.clear()
            
            local nResults = 0
            
            local limit = util.toNumber(patcher.variables["FINDLIMIT"] or 50)
            while true do
            --for i=1,50 do
                if storageMode() then
                    --address = patcher.storage.fileData:find(hex2bin(data),address+1+patcher.offset, true)
                    address = patcher.storage.fileData:find(hex2bin(data),address+1, true)
                else
                    --address = patcher.fileData:find(hex2bin(data),address+1+patcher.offset, true)
                    address = patcher.fileData:find(hex2bin(data),address+1, true)
                end
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
                patcher.variables["ADDRESS"] = patcher.results[#patcher.results].address + #data/2
                patcher.variables["RET"] = patcher.results[#patcher.results].address
            else
                patcher.lastFound = nil
                patcher.variables["RET"] = nil
            end
        --elseif keyword == "fontdata" then
            --local font = {"33":[0,0,0,0,0,8,8,8,8,8,0,8,0,0,0,0],"34":[0,0,0,0,0,20,20,0,0,0,0,0,0,0,0,0],"35":[0,0,0,0,0,0,40,124,40,40,124,40,0,0,0,0],"36":[0,0,0,0,16,56,84,20,56,80,84,56,16,0,0,0],"37":[0,0,0,0,0,264,148,72,32,144,328,132,0,0,0,0],"38":[0,0,0,0,0,48,72,48,168,68,196,312,0,0,0,0],"39":[0,0,0,0,0,8,8,0,0,0,0,0,0,0,0,0],"40":[0,0,0,0,0,8,4,4,4,4,4,8,0,0,0,0],"41":[0,0,0,0,0,4,8,8,8,8,8,4,0,0,0,0],"42":[0,0,0,0,32,168,112,428,112,168,32,0,0,0,0,0],"43":[0,0,0,0,0,0,16,16,124,16,16,0,0,0,0,0],"44":[0,0,0,0,0,0,0,0,0,0,24,24,16,8,0,0],"45":[0,0,0,0,0,0,0,0,60,0,0,0,0,0,0,0],"46":[0,0,0,0,0,0,0,0,0,0,24,24,0,0,0,0],"47":[0,0,0,0,0,16,16,8,8,8,4,4,0,0,0,0],"48":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"49":[0,0,0,0,0,8,8,8,8,8,8,8,0,0,0,0],"50":[0,0,0,0,0,24,36,32,16,8,4,60,0,0,0,0],"51":[0,0,0,0,0,24,36,32,24,32,36,24,0,0,0,0],"52":[0,0,0,0,0,32,36,36,60,32,32,32,0,0,0,0],"53":[0,0,0,0,0,60,4,4,24,32,36,24,0,0,0,0],"54":[0,0,0,0,0,24,36,4,28,36,36,24,0,0,0,0],"55":[0,0,0,0,0,60,32,32,16,8,8,8,0,0,0,0],"56":[0,0,0,0,0,24,36,36,24,36,36,24,0,0,0,0],"57":[0,0,0,0,0,24,36,36,56,32,36,24,0,0,0,0],"58":[0,0,0,0,0,0,24,24,0,0,24,24,0,0,0,0],"59":[0,0,0,0,0,0,24,24,0,0,24,24,16,8,0,0],"60":[0,0,0,0,0,32,16,8,4,8,16,32,0,0,0,0],"61":[0,0,0,0,0,0,0,60,0,0,60,0,0,0,0,0],"62":[0,0,0,0,0,4,8,16,32,16,8,4,0,0,0,0],"63":[0,0,0,0,0,24,36,32,16,8,0,8,0,0,0,0],"64":[0,0,0,0,240,264,612,660,660,484,8,240,0,0,0,0],"65":[0,0,0,0,0,24,36,36,60,36,36,36,0,0,0,0],"66":[0,0,0,0,0,28,36,36,28,36,36,28,0,0,0,0],"67":[0,0,0,0,0,24,36,4,4,4,36,24,0,0,0,0],"68":[0,0,0,0,0,28,36,36,36,36,36,28,0,0,0,0],"69":[0,0,0,0,0,60,4,4,28,4,4,60,0,0,0,0],"70":[0,0,0,0,0,60,4,4,28,4,4,4,0,0,0,0],"71":[0,0,0,0,0,24,36,4,52,36,36,24,0,0,0,0],"72":[0,0,0,0,0,36,36,36,60,36,36,36,0,0,0,0],"73":[0,0,0,0,0,28,8,8,8,8,8,28,0,0,0,0],"74":[0,0,0,0,0,60,16,16,16,20,20,8,0,0,0,0],"75":[0,0,0,0,0,36,36,20,12,20,36,36,0,0,0,0],"76":[0,0,0,0,0,4,4,4,4,4,4,60,0,0,0,0],"77":[0,0,0,0,0,68,68,108,84,84,68,68,0,0,0,0],"78":[0,0,0,0,0,68,76,84,84,84,100,68,0,0,0,0],"79":[0,0,0,0,0,24,36,36,36,36,36,24,0,0,0,0],"80":[0,0,0,0,0,28,36,36,28,4,4,4,0,0,0,0],"81":[0,0,0,0,0,24,36,36,36,52,36,88,0,0,0,0],"82":[0,0,0,0,0,28,36,36,28,36,36,36,0,0,0,0],"83":[0,0,0,0,0,24,36,4,24,32,36,24,0,0,0,0],"84":[0,0,0,0,0,124,16,16,16,16,16,16,0,0,0,0],"85":[0,0,0,0,0,36,36,36,36,36,36,24,0,0,0,0],"86":[0,0,0,0,0,68,68,68,68,40,40,16,0,0,0,0],"87":[0,0,0,0,0,84,84,84,84,84,56,40,0,0,0,0],"88":[0,0,0,0,0,68,68,40,16,40,68,68,0,0,0,0],"89":[0,0,0,0,0,68,68,40,16,16,16,16,0,0,0,0],"90":[0,0,0,0,0,60,32,16,16,8,4,60,0,0,0,0],"91":[0,0,0,0,0,28,4,4,4,4,4,28,0,0,0,0],"92":[0,0,0,0,0,4,4,8,8,8,16,16,0,0,0,0],"93":[0,0,0,0,0,28,16,16,16,16,16,28,0,0,0,0],"94":[0,0,0,0,0,24,36,0,0,0,0,0,0,0,0,0],"95":[0,0,0,0,0,0,0,0,0,0,0,0,508,0,0,0],"96":[0,0,0,0,0,4,8,0,0,0,0,0,0,0,0,0],"97":[0,0,0,0,0,0,0,24,32,56,36,88,0,0,0,0],"98":[0,0,0,0,0,0,4,4,28,36,36,28,0,0,0,0],"99":[0,0,0,0,0,0,0,0,24,4,4,24,0,0,0,0],"100":[0,0,0,0,0,0,32,32,56,36,36,88,0,0,0,0],"101":[0,0,0,0,0,0,0,24,36,28,4,56,0,0,0,0],"102":[0,0,0,0,0,0,48,8,8,28,8,8,0,0,0,0],"103":[0,0,0,0,0,0,0,0,88,36,36,56,32,36,24,0],"104":[0,0,0,0,0,0,4,4,4,28,36,36,0,0,0,0],"105":[0,0,0,0,0,0,8,0,12,8,8,8,0,0,0,0],"106":[0,0,0,0,0,0,0,16,0,24,16,16,16,12,0,0],"107":[0,0,0,0,0,0,0,4,20,12,20,20,0,0,0,0],"108":[0,0,0,0,0,0,4,4,4,4,4,8,0,0,0,0],"109":[0,0,0,0,0,0,0,0,4,88,168,168,0,0,0,0],"110":[0,0,0,0,0,0,0,0,4,28,36,36,0,0,0,0],"111":[0,0,0,0,0,0,0,0,24,36,36,24,0,0,0,0],"112":[0,0,0,0,0,0,0,4,56,72,72,56,8,8,8,0],"113":[0,0,0,0,0,0,0,0,88,36,36,56,32,32,64,0],"114":[0,0,0,0,0,0,0,0,52,72,8,8,0,0,0,0],"115":[0,0,0,0,0,0,0,24,4,24,32,24,0,0,0,0],"116":[0,0,0,0,0,0,8,8,28,8,8,16,0,0,0,0],"117":[0,0,0,0,0,0,0,0,36,36,36,88,0,0,0,0],"118":[0,0,0,0,0,0,0,0,68,68,40,16,0,0,0,0],"119":[0,0,0,0,0,0,0,0,84,84,84,40,0,0,0,0],"120":[0,0,0,0,0,0,0,0,36,24,24,36,0,0,0,0],"121":[0,0,0,0,0,0,0,0,36,36,36,56,32,36,24,0],"122":[0,0,0,0,0,0,0,0,60,16,8,60,0,0,0,0],"123":[0,0,0,16,8,8,8,4,8,8,8,16,0,0,0,0],"124":[0,0,0,8,8,8,8,8,8,8,8,8,0,0,0,0],"125":[0,0,0,4,8,8,8,16,8,8,8,4,0,0,0,0],"126":[0,0,0,0,0,0,0,24,292,192,0,0,0,0,0,0],"161":[0,0,0,0,0,8,0,8,8,8,8,8,0,0,0,0],"162":[0,0,0,0,0,0,16,56,20,20,56,16,0,0,0,0],"163":[0,0,0,0,0,48,8,8,28,8,8,60,0,0,0,0],"164":[0,0,0,0,0,0,132,120,72,72,120,132,0,0,0,0],"165":[0,0,0,0,68,40,16,56,16,56,16,16,0,0,0,0],"166":[0,0,0,8,8,8,8,0,8,8,8,8,0,0,0,0],"167":[0,0,0,0,0,0,48,72,8,48,72,72,48,64,72,48],"168":[0,0,0,0,0,108,108,0,0,0,0,0,0,0,0,0],"169":[0,0,0,0,240,264,612,532,532,612,264,240,0,0,0,0],"8364":[0,0,0,0,0,112,8,60,8,60,8,112,0,0,0,0],"name":"SlightlyFancyPix","copy":"SpiderDave","letterspace":"64","basefont_size":"512","basefont_left":"62","basefont_top":"0","basefont":"Arial","basefont2":""}
        elseif util.startsWith(line, "export tbl ") then
            data = util.split(line," ",3)[3]
            printf("Outputting textmap to %s...", data)
            local out=""
            local a={}
            for k,v in pairs(textMap) do
                if a[v:byte()] then
                    -- already defined, ignore duplicates
                else
                    a[v:byte()]=k
                end
            end
            for i=0,255 do
                if a[i] then
                    out=out..string.format("%02x=%s\n",i,a[i])
                end
            end
            
            local f = data
            if not util.writeToFile(f, 0, out) then err("Could not write to file") end
        elseif util.startsWith(line, "export map ") then
            local oldTilemapX = patcher.variables['TILEMAPX']
            local oldTilemapY = patcher.variables['TILEMAPY']

            data = util.split(data, " ", 1)[2]
            
            if util.toNumber(util.split(data, " ")[1]) and util.toNumber(util.split(data, " ")[2]) then
                patcher.variables['TILEMAPX']=util.toNumber(util.toNumber(util.split(data, " ")[1]))
                patcher.variables['TILEMAPY']=util.toNumber(util.toNumber(util.split(data, " ")[2]))
                data = util.split(data, " ", 2)[3]
            end
            
            if not gd then
                if not cairo then
                    --err("could not use export command because gd did not load.")
                end
            end
            local tileMap = util.split(data," ",1)[1]
            local fileName = util.split(data," ",1)[2]
            printf("exporting tile map %s to %s",tileMap, fileName)
            local oldPalette
            if patcher.autoPalette and patcher.tileMap[tileMap].palette then
                oldPalette = patcher.variables["PALETTE"]
                patcher.setPalette(patcher.tileMap[tileMap].palette)
            end
            
            local success, err = tileToImage2(tileMap, fileName)
            
            if patcher.autoPalette and patcher.tileMap[tileMap].palette then
                patcher.setPalette(oldPalette)
            end
            
            patcher.variables['TILEMAPX'] = oldTilemapX
            patcher.variables['TILEMAPY'] = oldTilemapY
            
            if not success then
                printf("Error: %s",err)
            end
        elseif util.startsWith(line, "export ") then
            if not gd then
                if not cairo then
                    --err("could not use export command because gd did not load.")
                end
            end
            local dummy, address,len,fileName=unpack(util.split(line," ",3))
            if not address then err("missing export address") end
            if not len then err("missing export length") end
            if not fileName then err("missing export fileName") end
            
            fileName = util.trim(fileName)
            address = util.toAddress(address)
            --len=tonumber(len,16)*16
            len=util.toNumber(len,16)*16
            print(string.format("exporting tile data at 0x%08x",address))
            
            tileData = patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+len)
            printVerbose(bin2hex(tileData))
            tileToImage(tileData, fileName)

            patcher.variables["ADDRESS"] = string.format("%x",address + len)
            --patcher.variables["DATA"] = bin2hex(tileData)
            --patcher.variables["RET"] = 


        elseif util.startsWith(line, "import map ") then
            local oldTilemapX = patcher.variables['TILEMAPX']
            local oldTilemapY = patcher.variables['TILEMAPY']

            data = util.split(data, " ", 1)[2]
            
            if util.toNumber(util.split(data, " ")[1]) and util.toNumber(util.split(data, " ")[2]) then
                patcher.variables['TILEMAPX']=util.toNumber(util.toNumber(util.split(data, " ")[1]))
                patcher.variables['TILEMAPY']=util.toNumber(util.toNumber(util.split(data, " ")[2]))
                data = util.split(data, " ", 2)[3]
            end


--            if not gd then
--                err("could not use import command because gd did not load.")
--            end
            local tileMap = util.split(data," ",1)[1]
            local fileName = util.split(data," ",1)[2]
            
            if not util.fileExists(fileName) then
                err('The file "%s" does not exist.', fileName)
            end
            
            print(string.format("importing tile map %s from %s",tileMap, fileName))
            
            local oldPalette
            if patcher.autoPalette and patcher.tileMap[tileMap].palette then
                oldPalette = patcher.variables["PALETTE"]
                patcher.setPalette(patcher.tileMap[tileMap].palette)
            end
            
            local tileData = imageToTile3(tileMap, fileName)
            
            local address,td
            for i=1,#tileData do
                address,td=tileData[i].address, tileData[i].t
                patcher.write(address+patcher.offset,td)
            end
            
            if patcher.autoPalette and patcher.tileMap[tileMap].palette then
                patcher.setPalette(oldPalette)
            end
            
            patcher.variables['TILEMAPX'] = oldTilemapX
            patcher.variables['TILEMAPY'] = oldTilemapY
            
        elseif keyword=="push" then
            if data == "variables" then
                patcher.variables.OFFSET = patcher.variables.OFFSET or patcher.offset
                patcher.variableStack:push(util.serialize(patcher.variables))
                print("pushing variables")
            end
        elseif keyword=="pop" then
            if data == "variables" then
                patcher.variables = util.unserialize(patcher.variableStack:pop())
                patcher.offset = patcher.variables.OFFSET or patcher.offset
                print("popping variables")
            end
        elseif util.startsWith(line, "import ") then
--            if not gd then
--                err("could not use import command because gd did not load.")
--            end
            local dummy, address,len,fileName=unpack(util.split(line," ",3))
            --address=tonumber(address,16)
            address = util.toAddress(address)
            --len=tonumber(len,16)*16
            len=util.toNumber(len,16)*16
            --printf("%02x",len)
            
            print(string.format("importing tile data at 0x%08x",address))
            local tileData = imageToTile(len, fileName)
            
            patcher.variables["ADDRESS"] = string.format("%x",address + len)
            
            patcher.write(address+patcher.offset,tileData)
        elseif keyword == "format" then
            local fstring = util.split(data," ",1)[1]
            local dstring = util.split(data," ",1)[2]
            patcher.variables.RET = string.format(fstring, patcher.variables[dstring] or dstring)
            --print(patcher.variables.RET)
        elseif keyword == "log" then
            local f = patcher.variables.LOGFILE
            if not util.logToFile(f, data) then err("Could not write to file.") end
        elseif keyword == "goto" then
            local label = util.trim(data)
            local oldPatchIndex = patch.index
            --patch.index = 1
            while true do
                line = patch.readLine()
                if line==nil then
                    patch.index = 1
                    line = patch.readLine()
                end
                if patch.index==oldPatchIndex then break end
                if util.startsWith(line, ":"..label) then break end
            end
            patcher.gotoCount = patcher.gotoCount + 1
            if patcher.gotoCount >= patcher.gotoLimit then
                err("goto limit reached (could be infinite loop).")
            end
        elseif keyword == "skip" or util.startsWith(line, "start skip") then
            local nSkipped = 0
            while true do
                nSkipped = nSkipped +1
                line = patch.readLine()
                if util.startsWith(line, "end skip") then break end
            end
            print(string.format("skipped %d lines.", nSkipped-1))
        elseif util.startsWith(line, "/**") then
            local nSkipped = 0
            while true do
                nSkipped = nSkipped +1
                line = patch.readLine()
                if util.endsWith(line, "**/") then
                    break
                end
            end
            --print(string.format("skipped %d lines.", nSkipped-1))
        elseif util.startsWith(line, "/*") then
            local nSkipped = 0
            while true do
                nSkipped = nSkipped +1
                line = patch.readLine()
                if util.endsWith(line, "*/") then
                    break
                end
            end
            --print(string.format("skipped %d lines.", nSkipped-1))
        elseif util.startsWith(line, "start loop") then
            if util.split(line, "start loop",1)[2] then
                patcher.variables.LOOPEND = util.toNumber(util.split(line, "start loop",1)[2])
                patcher.variables.RET = patcher.variables.LOOPEND
            else
                patcher.variables.LOOPEND = nil
            end
            --printf("start loop %s",patch.index)
            patch.loopStack:push(patch.index)
            patcher.variables.INDEX = 1
            
        elseif util.startsWith(line, "end loop") then
            --local i=patch.loopStack:pop()
            local i=patch.loopStack:last()
            --printf("end loop %s %s %s",i,patch.index,patch.lines[i])
            
            if patcher.variables.LOOPEND and (patcher.variables.INDEX >= patcher.variables.LOOPEND) then
                patch.loopStack:pop()
            else
                patcher.variables.INDEX = (patcher.variables.INDEX or 1)+ 1
                patch.index = i
            end
            --patcher.variables.RET = patcher.variables.INDEX
            --patcher.variables.INDEX = 1
            --line = patch.readLine()
        elseif util.startsWith(line, "break loop") then
            local i=patch.loopStack:pop()

            while true do
                line = patch.readLine()
                if util.startsWith(line, "end loop") then break end
            end
        elseif util.startsWith(line, "start print") then
            while true do
                line = patch.readLine()
                if util.startsWith(line, "end print") then break end
                print(line)
            end
        elseif keyword == "loadasmlist" then
--            local f = io.open(data, "r")
--            for line in f:lines() do
--            end
            local line = "08A8B 99 0A 03                              sta VRAM_Buffer1+9,y  ;put null terminator at end"
            
            print("address: "..string.sub(line, 1,5))
            print("data: "..string.sub(line, 7,32))
            print("code: "..util.trim(string.sub(line, 33)))
        elseif util.startsWith(line, "start asm") then
            print("start asm")
            patcher.asmMode = true
            patcher.asmAddress = 0
        elseif util.startsWith(line, "end asm") then
            patcher.asmMode = false
            print("end asm")
        elseif util.startsWith(line, "start tbl") then
            local tableName=util.identifier(util.split(data, " ",1)[2])
            printf("tbl %s",tableName or "(default)")
            tableName=tableName or "default"
            patcher.tbl[tableName]=patcher.tbl[tableName] or {}
            while true do
                line = patch.readLine()
                
                if #util.split(line, "=",1)>1  then
                    textMap=textMap or {}
                    textMap[util.split(line, "=",1)[2]]=hex2bin(util.split(line, "=",1)[1])
                    patcher.tbl[tableName][hex2bin(util.split(line, "=",1)[1])]=util.split(line, "=",1)[2]
                end
                
                if util.startsWith(line, "end tbl") then break end
            end
        elseif keyword=="expression" then
            local e = data
            e = e:gsub(" ", "")
            print("expression: "..e)
            
            -- find innermost parenthesis
            local f = function(e)
                
                -- split up terms by finding words
                local f2= function(e)
                    --print("f2 e="..e)
                    
                    e = e:gsub("%(","")
                    e = e:gsub("%)","")
                    
--                    local m = e:gmatch("%w+")
--                    for m2 in m do
--                        print("m2="..m2)
--                    end
                    
                    -- convert terms to numbers
                    local f3 = function(e)
                        --print("f3 e="..e)
                        -- convert individual term to number or substitute variable
                        local f4 = function(e)
                            local ret = util.toNumber(e)
                            ret = ret or util.toNumber(patcher.variables[e])
                            if patcher.base == 16 then
                                ret = string.format("%02x",ret)
                            else
                                ret = tostring(ret)
                            end
                            --print("ret = "..ret)
                            return ret
                        end
                        
                        e = e:gsub("%w+", f4)
                        return e
                    end
                    
                    e = e:gsub("%w+", f3)
                    return e
                end
                
                e = e:gsub("%([%w%+%-%*%/]+%)", f2)
                return e
            end
            
            e = "("..e..")"
            for i=1,100 do
                local olde=e
                e = f(e)
                if e==olde then break end
            end
            --print("result after removing parenthesis:"..e)
            
            
--            e = e:gsub("%w+","0x%1")
--            print(e)
--            if true then return end
            
            local operations = {
                ["*"]= function(x,y) return x*y end,
                ["/"]= function(x,y) return x/y end,
                ["+"]= function(x,y) return x+y end,
                ["-"]= function(x,y) return x-y end,
            }
            
            for i=1, 1000 do
                local olde=e
                for _,op in ipairs{"*","/","+","-"} do
                    if e:match("%w+[%"..op.."]%w+") then
                        
                        --print(e:match("%w+[%"..op.."]%w+"))
                        
                        local f = function(m,op,m2)
                            m = util.toNumber(m, patcher.base)
                            m2 = util.toNumber(m2, patcher.base)
                            --printf("m=%s, m2=%s, op=%s",m,m2,op)
                            local ret = operations[op](m,m2,op)
                            if patcher.base==16 then
                                ret = string.format("%02x",ret)
                            else
                                ret = tostring(ret)
                            end
                            --print("ret="..ret)
                            return ret
                        end
                        
                        e=e:gsub("(%w+)([%"..op.."])(%w+)",f)
                        --print("e="..e)
                    end
                end
                if e==olde then break end
            end
            
            print("result:"..e)
            patcher.variables.RET = util.toNumber(e)
            
        elseif keyword=="expressionold" then
            local calc= function(e)
                e="("..e..")"
                printVerbose("e="..e)
                local operations = {
                    ["*"]= function(x,y) return x*y end,
                    ["/"]= function(x,y) return x/y end,
                    ["+"]= function(x,y) return x+y end,
                    ["-"]= function(x,y) return x-y end,
                }
                local calc3 = function(e, op)
                    local m= e:match("(%w+)[%"..op.."]%w+")
                    local m2= e:match("%w+[%"..op.."](%w+)")
                    local o= e:match("%w+([%"..op.."])%w+")
                    
                    --print(m..op..m2)
                    if m and m2 then
                        local f = operations[op]
                        
                        -- Here let's make sure we have a number.
                        -- If not, check if it's a variable
                        -- probably should factor in scrit options
                        -- and do some testing.
                        local x = util.toNumber(m)
                        local y = util.toNumber(m2)
                        x=x or patcher.variables[m]
                        y=y or patcher.variables[m2]
                        return string.format("%x", f(x,y))
                    else
                        return e
                    end
                end

                local calc2 = function(e)
                    local m = e:match("^.[%w%*%-%+%/]-$")
                    --local m = e:match("^.[%w%*%/%+%-]-$")
                    if m then
                        print("  matched:"..m)
                        for _,op in ipairs{"*","/","+","-"} do
                            for _=1,15 do
                                local m= e:match("%w+[%"..op.."]%w+")
                                if m then
                                    --print("    matched:"..m)
                                    e=e:gsub("(%w+[%"..op.."]%w+)", calc3(m, op))
                                end
                            end
                        end
                    end
                    return e
                end

                for _=1,15 do
                    local m = e:match("%((.[^%(%)]-)%)")
                    if m then
                        print("match:"..m)
                        e=e:gsub("%((.[^%(%)]-)%)", "("..calc2(m)..")")
                        printVerbose("e="..e)
                    end


                    local m = e:match("%((%w+)%)")
                    if m then
                        --print("match():"..m)
                        e=e:gsub("%((%w+)%)", m)
                        --print("e="..e)
                        printVerbose("e="..e)
                    end
                    
                end
                return e
            end
            
            local e=data
            
            -- remove all spaces (causes problem if spaces are left in)
            e = e:gsub(" ", "")
            
            print("expression:"..e)
            e=calc(e)
            print("result:"..e)
            patcher.variables.RET = util.toNumber(e)
        elseif util.startsWith(line, "start function") or keyword=="function" then
            if keyword=="function" then
                --pass
            else
                data = util.split(data, " ", 1)[2]
            end
            
            local n = util.trim(data)

            if not n then
                err("Missing function name.")
            end
            
            local args
            
            if n:find("%(") and n:find("%)") then
                args = util.split(n, "(")[2]
                args = args:sub(1, -2) -- remove last character
                if util.trim(args)=="" then args=nil end
                n = util.split(n, "(")[1]
            end
            
            if n=="" then
                err("Missing function name.")
            elseif n:find(" ") then
                err('Invalid function name "%s"',n)
            end
            
            
            patch.f[n]={}
            
            if args then
                patch.f[n][#patch.f[n]+1]="split %PARAM%"
                for i,v in ipairs(util.split(args," ")) do
                    patch.f[n][#patch.f[n]+1]=v.."=".."%SPLIT"..string.format("%x", i).."%"
                end
            end
            
            while true do
                local line, opt = patch.readLine(false)
                if util.startsWith(line, "end function") then break end
                --print(line)
                
                patch.f[n][#patch.f[n]+1]=string.rep(" ",opt.indent)..line
                --print("******"..string.rep(" ",opt.indent)..line)
            end
            local printVerbose=printf
            printVerbose("Creating function %s",n)
        --elseif keyword=="run" or util.endsWith(keyword, "()") then
        elseif keyword=="run" or util.endsWith(keyword, ")") then
            local fName = data
            if util.endsWith(keyword, ")") then
                fName = util.split(keywordOriginal, "(", 1)[1]
                local param = util.split(keywordOriginal, "(", 1)[2]
                param = param:sub(1, -2) -- remove last character
                patcher.variables.PARAM = param
            end
            
            if not patch.f[fName] then
                err('Function "%s()" does not exist.',fName)
            end
            
            local i = patch.index
            local lines = patch.f[fName]
            
            for k,v in pairs(lines) do
              table.insert(patch.lines, i, string.rep(" ",indent)..v)
              i=i+1
            end
            
            -- Defer fillVar to the end of the function
            if fillVar then
                table.insert(patch.lines, i, string.rep(" ",indent).."-->"..fillVar)
                fillVar = nil
            end
            
        elseif keyword == "list" and data == "variables" then
            for _,k in pairs(util.keys(patcher.variables)) do
                local v = patcher.variables[k]
                if type(v) == "number" then
                    v = string.format("%x",v)
                end
                printf("%s = %s",k,v)
            end
        elseif keyword == "deftype" then
            local t = util.trim(data)
            if t=="str" or t=="num" or t=="dec" then
                printf("Default data type: %s",t)
                patcher.variables.DEFTYPE=t
            else
                err("Invalid default data type: %s",t)
            end
        elseif (keyword == "str") or (keyword == "var" and patcher.variables.DEFTYPE=="str") then
            local k,v = table.unpack(util.split(data, "=", 1))
            k,v = util.trim(k), util.trim(v)
            patcher.variables[k] = v
            printVerbose('Variable: %s = "%s"', k, v)
        elseif keyword == "num" or (keyword == "var" and (patcher.variables.DEFTYPE=="num")) then
            local k,v = table.unpack(util.split(data, "=", 1))
            k,v = util.trim(k), util.trim(v)
            patcher.variables[k] = util.toNumber(v)
            printVerbose('Variable: %s = 0x%x (%s)', k, patcher.variables[k], patcher.variables[k])
        elseif ((not patcher.asmMode) and keyword == "dec") or (keyword == "var" and (patcher.variables.DEFTYPE=="dec")) then
            local k,v = table.unpack(util.split(data, "=", 1))
            k,v = util.trim(k), util.trim(v)
            patcher.variables[k] = util.toNumber(v, 10)
            printVerbose('Variable: %s = 0x%x (%s)', k, patcher.variables[k], patcher.variables[k])
        --elseif keyword == "if" and util.endsWith(data, ")") then
        elseif keyword=="if" and patch.parseFunctionString(data) then
            local fName,param,data = patch.parseFunctionString(data)
            
--            local fName = util.split(data, "(", 1)[1]
--            local param = util.split(data, "(", 1)[2]
--            param = param:sub(1, -2) -- remove last character
            
            patcher.variables.PARAM = param
            
            if not patch.f[fName] then
                err('Function "%s()" does not exist.',fName)
            end
            
            local i = patch.index
            local lines = patch.f[fName]
            
            for k,v in pairs(lines) do
              table.insert(patch.lines, i, string.rep(" ",indent)..v)
              i=i+1
            end
            
            -- Defer fillVar to the end of the function
            if fillVar then
                table.insert(patch.lines, i, string.rep(" ",indent).."-->"..fillVar)
                fillVar = nil
            end
            
            -- We add an if block, replacing the original, but use the return value of the function as a test.
            if data then
                table.insert(patch.lines, i, string.rep(" ",indent).."if RET=="..data)
            else
                table.insert(patch.lines, i, string.rep(" ",indent).."if RET")
            end
            
        elseif keyword == "if" then
            --printf("[%s] indent=%s",keyword, indent)
            
            local k,v = table.unpack(util.split(data, "=="))
            
            --printVerbose('Variable debug: k="%s" v="%s" v[k]=%s', k,v, patcher.variables[k])
            local testTrue = false
            if ((not v) and k) then
                testTrue = util.isTrue(patcher.variables[k])
            elseif (patcher.variables[k] == util.trim(v)) or (util.isEqual(patcher.variables[k],util.trim(v))) then
                testTrue = true
            end
            if ((not v) and k) and util.isTrue(patcher.variables[k]) then
                --testTrue = true
                --k = util.trim(k)
                --printVerbose('Test variable: "%s"', k)
            else
                --k,v = util.trim(k), util.trim(v)
                --printVerbose(string.format('Compare variable: "%s" == "%s"', k, v))
            end
            
            if testTrue==true then
            --if testTrue==true or (patcher.variables[k] == v) or (util.isEqual(patcher.variables[k],v)) then
            --if testTrue==true or (k == v) or (util.isEqual(k,v)) then
                patcher["if"..indent] = true
                printVerbose(" true")
            else
                patcher["if"..indent] = false
                printVerbose(" false")
                
                local nSkipped = 0
                while true do
                    nSkipped = nSkipped +1
                    line, opt = patch.readLine()
                    if not line then
                        err('Expected "else" or "end if".  Got end of patch instead.')
                    end
                    if util.startsWith(line, "if ") and opt.indent == indent then
                        err('Expected "else" or "end if".  Got "if" instead.')
                    end
                    if util.startsWith(line, "end if") and opt.indent==indent then break end
                    if util.startsWith(line, "else") and opt.indent==indent then break end
                end
                --print(string.format("skipped %d lines.", nSkipped-1))
            end
        elseif keyword == "else" then
            -- If the last "if" block was true, then we treat the "else" section like a skip
            if patcher["if"..indent] == true then
                local nSkipped = 0
                while true do
                    nSkipped = nSkipped +1
                    line, opt = patch.readLine()
                    if util.startsWith(line, "end if") and indent==opt.indent then break end
                end
                --print(string.format("skipped %d lines.", nSkipped-1))
            end
        elseif util.startsWith(line, "end if") then
            --print("end if use case???????")
        elseif util.startsWith(line, "start tilemap ") then
            local n = string.sub(line,15)
            local tm={}
            tm.width = 0
            tm.height = 0
            local address = 0
            local adjustX = 0
            local adjustY = 0
            local gridSize = 8
            while true do
                line = patch.readLine()
                if util.startsWith(line, "end tilemap") then break end
                if line:find("=") then
                    local k,v=unpack(util.split(line, "="))
                    k=util.trim(k)
                    v=util.trim(v)
                    if k == "address" then
                        --printf("%s=%s",k,v)
                        address = tonumber(v,16)
                    end
                    if k == "palette" then
                        tm.palette = v
                    end
                    if k == "gridsize" then
                        gridSize = tonumber(v,16)
                    end
                    if k == "adjust" then
                        adjustX = tonumber(util.split(v," ")[1],10)
                        adjustY = tonumber(util.split(v," ")[2],10)
                        print(string.format("adjust x = %s (%s)",adjustX, util.split(v," ")[1]))
                        print(string.format("adjust y = %s (%s)",adjustY, util.split(v," ")[2]))
                    end
                elseif line=="" or util.startsWith(line, "//") then
                else
                    local tileNum, x, y, f = unpack(util.split(util.trim(line)," ",4))
                    tileNum = tonumber(tileNum,16)
                    x = tonumber(x,16)
                    y = tonumber(y,16)
                    local flip = {}
                    
                    if f=="h" then
                        flip.horizontal = true
                    elseif f=="v" then 
                        flip.vertical = true
                    elseif f=="hv" then
                        flip.horizontal = true
                        flip.vertical = true
                    end
                    
                    tm[#tm+1]={address=address, tileNum=tileNum,realX=x*gridSize+adjustX,realY=y*gridSize+adjustY, x=x,y=y,flip = {horizontal=flip.horizontal, vertical=flip.vertical}, adjust = {x=adjustX,y=adjustY}, gridSize = gridSize}
                    
                    if x*gridSize+adjustX > tm.width then tm.width = x*gridSize+adjustX end
                    if y*gridSize+adjustY > tm.height then tm.height = y*gridSize+adjustY end
                end

--                    if flip.vertical and flip.horizontal then
--                        err("test??")
--                    end

            end
            tm.width=tm.width+8
            tm.height=tm.height+8

            patcher.tileMap[n] = tm

            --printf("tilemap size: %s %s",tm.width,tm.height)
        elseif keyword == "default" then
            local varName=util.trim(util.split(data, patcher.variables.DELIM or " ")[1])

            if util.isTrueOrZero(patcher.variables[varName])~=true then
                local v = util.ltrim(util.split(data, patcher.variables.DELIM or " ",1)[2])

                if patcher.variables.DEFTYPE=="str" then
                    patcher.variables[varName] = v
                    printVerbose('Variable: %s = "%s"', varName, util.ltrim(v))
                elseif patcher.variables.DEFTYPE=="num" then
                    patcher.variables[varName] = util.toNumber(v)
                    printVerbose('Variable: %s = 0x%x (%s)', varName, patcher.variables[varName], patcher.variables[varName])
                elseif patcher.variables.DEFTYPE=="dec" then
                    patcher.variables[varName] = util.toNumber(v, 10)
                    printVerbose('Variable: %s = 0x%x (%s)', varName, patcher.variables[varName], patcher.variables[varName])
                end
            end
        elseif keyword == "coalesce" then
            patcher.variables["RET"] = nil
            for k,v in ipairs(util.split(data, patcher.variables.DELIM or " ")) do
                --printf("testing value %s", v)
                
                if util.startsWith(v, "%") and util.endsWith(v, "%") then
                    -- Assume it's an undefined variable because it starts and ends with %
                elseif util.isNull(v)==false then
                    patcher.variables["RET"] = v
                    break
                end
            end
            printf("Coalesce value: %s", patcher.variables["RET"])
        elseif keyword == "eval" then
            local f=util.sandbox:loadCode("return "..data)
            patcher.variables["RESULT"] = f()
            print(patcher.variables["RESULT"])
        elseif keyword == "code" then
            local f=util.sandbox:loadCode(data)
            f()
        elseif keyword == "plugin" then
            if allowPlugins ~= true then
                err('allowPlugins = false.')
            end
            data=util.trim(data)
            local plugin = require(data)
            plugins[data] = plugin
            printf("loading plugin: %s.", data)
            if plugin.init then plugin.init() end
            --local f=util.sandbox:loadCode(data)
            --f()
        elseif keyword == "text" then
            local address = data:sub(1,(data:find(" ")))
            address = util.toAddress(address)
            
            txt=data:sub((data:find(" ")+1))
            print(string.format("Setting text: 0x%08x: %s",address,txt))
            txt=string.gsub(txt, "|", string.char(0))
            
            txt=mapText(txt)
            
            patcher.write(address+patcher.offset,txt)
            
            patcher.variables["ADDRESS"] = string.format("%x",address + #txt)
        elseif keyword == "textmap" then
            local data1 = util.split(data, patcher.variables.DELIM or " ")[1]
            if data1 == "set" then
                patcher.textMaps.current = util.split(data, patcher.variables.DELIM or " ")[2]
                patcher.textMaps[patcher.textMaps.current] = patcher.textMaps[patcher.textMaps.current] or {}
                textMap = patcher.textMaps[patcher.textMaps.current]
            elseif data == "clear" then
                textMap = {}
                printVerbose("clearing textmap")
                patcher.textMaps[patcher.textMaps.current] = textMap
            elseif util.split(data, " ")[1]:find("...", nil, true) then
                local s1, s2 = table.unpack(util.split(util.split(data, " ")[1], "..."))
                local mapOld = ""
                local n = tonumber(util.split(data, " ")[2], 16)
                local mapNew = ""
                for i=string.byte(s1), string.byte(s2) do
                    mapOld=mapOld..string.char(i)
                    mapNew=mapNew..string.format("%02x", n+i-string.byte(s1))
                end
                textMap=textMap or {}
                mapNew=hex2bin(mapNew)
                for i=1,#mapOld do
                    textMap[mapOld:sub(i,i)]=mapNew:sub(i,i)
                end
                patcher.textMaps[patcher.textMaps.current] = textMap
            else
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
                patcher.textMaps[patcher.textMaps.current] = textMap
            end
        elseif keyword == "put" then
            local address = data:sub(1,(data:find(" ")))
            address = util.toAddress(address)
            
            local newData=data:sub((data:find(" ")+1))
            newData = util.stripSpaces(newData)
            if hex2bin(newData)==nil then
                err('Bad parameter "%s"\nLine: "%s"',newData, line)
            end
            if #newData == 1 then newData = "0"..newData end
            
            
            old=patcher.fileData:sub(address+1+patcher.offset,address+patcher.offset+#newData/2)
            old=bin2hex(old)
            --printf("Setting bytes: 0x%08x: %s --> %s",address,old, newData)
            patcher.write(address+patcher.offset,hex2bin(newData))
            printf("Setting bytes: 0x%08x: %s --> %s",address, util.limitString(patcher.variables["OLDDATA"]), util.limitString(patcher.variables["NEWDATA"]))
            
            patcher.variables["ADDRESS"] = string.format("%x",address + #newData/2)
        elseif keyword == "fill" then
            address = util.split(data, " ", 1)[1]
            address = util.toAddress(address)
            
            data = util.split(data, " ", 1)[2]
            fillCount = util.toNumber(util.split(data, " ", 1)[1])
            fillString = util.stripSpaces(util.split(data, " ", 1)[2])
            printf("fill: 0x%x 0x%02x [%s]",address, fillCount, util.limitString(fillString))
            
            local newData = string.rep(fillString, fillCount)
            --printVerbose("Fill data: 0x%08x: %s",address, newData)
            patcher.write(address+patcher.offset,hex2bin(newData))
            printVerbose("Fill data: 0x%08x: %s",address, util.limitString(patcher.variables["NEWDATA"]))
            patcher.variables["ADDRESS"] = string.format("%x",address + #newData/2)
        elseif keyword == "md5" then
            local md5
            if data then
                -- md5 of given file
                md5=util.md5.sumhexa(util.getFileContents(data))
                printf("MD5 (%s): %s",data, md5)
            else
                -- md5 of current file data
                md5=util.md5.sumhexa(patcher.fileData)
                printf("MD5 (Current file data): %s", md5)
            end
            patcher.variables["RET"] = md5
        elseif keyword == "gg" then
            local gg=data:upper()
            gg=util.split(gg," ",1)[1] -- Let's allow stuff after the code for descriptions, etc.  figure out a better comment system later.
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
                    end
                    --printf("%04x %02x %02x",address+patcher.offset,b,c)
                else
                    printf("    %04x",address)
                    patcher.write(address+patcher.offset,string.char(v))
                end
                address=address+ 0x2000
                if address > #patcher.fileData or address>=0x20000 then break end
            end
            
        elseif util.startsWith(line, "copy hex ") then
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
        elseif util.startsWith(line, "copy ") then
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
        elseif keyword == "pause" then
            print("Press enter to continue.")
            if patcher.launcher then
                print("*pause skipped*")
            else
                io.stdin:read("*l")
            end
        elseif keyword == "getinput" then
            --print(data)
            io.write(data)
            local inp=io.stdin:read("*l")
            patcher.variables["INPUT"] = util.trim(inp)
        elseif line=="break" or line == "quit" or line == "exit" then
            print("[break]")
            --break
            patcher.breakLoop=true
            patcher.breakType = keyword
        elseif keyword=="error" then
            -- line numbers aren't useful yet due to the way include works
            --printf("Error!: %s %s\n", patch.index-1, data)
--            if data then
--                printf("Error!: %s\n", data)
--            else
--                printf("Error!\n")
--            end
            
            err(data or "")
            patcher.breakLoop=true
            patcher.breakType = "break"
        elseif keyword=="refresh" then
            if data == "auto" then
                patcher.autoRefresh = true
            elseif data == "manual" then
                patcher.autoRefresh = false
            else
                if storageMode() then
                    patcher.storage.fileData = patcher.storage.newFileData
                else
                    patcher.fileData = patcher.newFileData
                end
            end
        elseif keyword=="revert" then
            patcher.newFileData = patcher.fileData
        elseif line=="header" then
            local header = patcher.getHeader()
            print(string.format("\niNES header data:\nid: %s\nPRG ROM: %02x x 4000\nCHR ROM: %02x x 2000\n",header.id,header.prg_rom_size,header.chr_rom_size))
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
        elseif keyword=="makeips" then
            local f = util.trim(data)
            printf("Creating IPS patch: %s",f)
            if not util.writeToFile(f, 0, patcher.makeIPS(patcher.originalFileData,patcher.newFileData), true) then err("Could not write to file.") end
        elseif keyword=="file" then
            if util.trim(data:lower())=="none" then data=nil end
            patcher.fileName = data
            file = data
            printf("File: %s",patcher.fileName or "(none)")
            --patcher.fileData=util.getFileContents(patcher.fileName)
        elseif keyword=="unload" then
            patcher.unload()
        elseif keyword=="load" then
            patcher.load(data)
        elseif keyword=="reload" then
            patcher.load()
        elseif keyword=="save" then
            local f = util.trim(data)
            --print("["..f.."]")
            patcher.save(f)
        elseif keyword=="outputfile" then
            if util.trim(data:lower())=="none" then data=nil end
            patcher.outputFileName = data
            printf("Output file: %s",patcher.outputFileName or "(none)")
            --patcher.fileData=util.getFileContents(patcher.fileName)
        elseif keyword == "start" then
            --patcher.startAddress = tonumber(data, 16)
            patcher.startAddress = util.toAddress(data)
            printf("Setting Start Address: %04x", patcher.startAddress)
        elseif keyword == "offset" then
            patcher.offset = tonumber(data, 16)
            patcher.variables.OFFSET = patcher.offset
            print("Setting offset: "..data)
        elseif keyword == "palette" then
            data = util.trim(data)
            if util.startsWith(data, "auto") then
                patcher.autoPalette = true
            elseif util.startsWith(data, "manual") then
                patcher.autoPalette = false
            elseif util.startsWith(data, "file") then
                local fileName = util.split(data, " ", 1)[2]
                local fileData = util.getFileContents(fileName)
                
                patcher.palette = {}
                i=1
                for c=0,63 do
                    patcher.palette[c]={}
                    for i=1,3 do
                        patcher.palette[c][i]=util.rawToNumber(fileData:sub(c*3+i,c*3+i))
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
            local compact = util.isTrue(patcher.variables["DIFFCOMPACT"])
            local diff={}
            
            diff.fileName = data or patcher.fileName
            diff.data = util.getFileContents(diff.fileName)
            diff.count=1
            printf("current file: %s bytes",#patcher.newFileData)
            printf("%s: %s bytes",diff.fileName, #diff.data)
            diff.old2=""
            diff.new2=""
            for i = 0,#patcher.newFileData -1 do
                diff.old =string.byte(patcher.newFileData:sub(i+patcher.offset+1,i+patcher.offset+1))
                diff.new =string.byte(diff.data:sub(i+patcher.offset+1,i+patcher.offset+1))
                if diff.old~=diff.new then
                    diff.lastChange = i
                    if compact then
                    else
                        printf("%02x %06x  %02x | %02x",diff.count, i, diff.old or 0x42,diff.new or 0x42)
                        diff.count=diff.count+1
                    end
                    if diff.count>patcher.diffMax then break end
                else
                    if diff.lastChange == i-1 then
                        --print("*************")
                        --printf("%06x %06x", diff.lastSame+1, diff.lastChange - diff.lastSame)
                        diff.old2 = bin2hex(patcher.newFileData:sub(diff.lastSame+patcher.offset+2,diff.lastSame+patcher.offset+(diff.lastChange - diff.lastSame+1)))
                        diff.new2 = bin2hex(diff.data:sub(diff.lastSame+patcher.offset+2,diff.lastSame+patcher.offset+(diff.lastChange - diff.lastSame+1)))
                        if compact then
                            printf("%02x %06x %s | %s",diff.count, diff.lastSame+1, diff.old2, diff.new2)
                            diff.count=diff.count+1
                        else
                            print("--------------------")
                        end
                    end
                    diff.lastSame = i
                end
            end
        elseif keyword == "ips" then
            local ips = {}
            ips.nRecords = 0
            ips.nRLE = 0
            ips.n=string.sub(line,5)
            
            if not util.fileExists(ips.n) then
                err('The file "%s" does not exist.', ips.n)
            end
            
            print("Applying ips patch: "..ips.n)
            --ips.file = io.open(ips.n,"r")
            ips.data = util.getFileContents(ips.n)
            --print(#ips.data)
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
                    -- IPS format exension "truncate" feature
                    local truncate = ips.data:sub(ips.address+4,ips.address+7)
                    if truncate~="" then
                        truncate = tonumber(bin2hex(truncate),16)
                        if truncate == 0 then
                            -- Doesn't usually make sense to truncate the whole file via ips patch.
                            warning("Bad IPS truncate value (0).")
                        elseif truncate == #patcher.newFileData then
                            -- It's already the right size, do nothing.
                        elseif truncate > #patcher.newFileData then
                            -- Expand file
                            patcher.newFileData = patcher.newFileData .. string.rep(string.char(0), truncate - #patcher.newFileData)
                        else
                            -- Truncate file
                            patcher.newFileData = patcher.newFileData:sub(1,truncate)
                        end
                    end
                    
                    break
                end
                
    --            if ips.address+1 > #ips.data+3 then
    --                err("Early end of file")
    --            end
                --print(#ips.offset)
                ips.offset = util.rawToNumber(ips.offset)
                printVerbose(string.format("offset: 0x%08x",ips.offset))
                ips.address = ips.address + 3
                ips.chunkSize = util.rawToNumber(ips.data:sub(ips.address+1,ips.address+2))
                printVerbose(string.format("chunkSize: 0x%08x",ips.chunkSize))
                ips.address = ips.address + 2
                if ips.chunkSize == 0 then
                    -- RLE
                    printVerbose(string.format("RLE detected at: 0x%08x",ips.address))
                    ips.chunkSize = util.rawToNumber(ips.data:sub(ips.address+1,ips.address+2))
                    ips.address = ips.address + 2
                    if ips.chunkSize == 0 then err("bad RLE size") end
                    printVerbose(string.format("RLE length: 0x%08x",ips.chunkSize))
                    ips.fill = ips.data:sub(ips.address+1,ips.address+1)
                    ips.address = ips.address + 1
                    printVerbose(string.format("RLE fill: %s", bin2hex(ips.fill)))
                    ips.replaceData = string.rep(ips.fill, ips.chunkSize)
                    ips.nRLE = ips.nRLE + 1
                else
                    ips.replaceData = ips.data:sub(ips.address+1,ips.address+ips.chunkSize)
                    ips.address=ips.address+ips.chunkSize
                end
                ips.nRecords = ips.nRecords +1
                printVerbose(string.format("replacing 0x%08x bytes at 0x%08x", #ips.replaceData, ips.offset))
                --printVerbose(string.format("replacing: 0x%08x %s", ips.offset, bin2hex(ips.replaceData))) -- MAKES IT HANG
                printVerbose(string.format("0x%08x",ips.address))
                patcher.write(ips.offset+patcher.offset,ips.replaceData)
                loopCount = loopCount+1
                if loopCount >=loopLimit then
                    quit ("Error: Loop limit reached.")
                end
            end
            printVerbose("%s records (%s RLE)",ips.nRecords, ips.nRLE)
            printVerbose("ips done.")
        elseif keyword == "use" then
            if data:lower() == "gd" then
                graphics:init("gd")
                print("Using gd for graphics operations.")
            elseif data:lower() == "cairo" then
                graphics:init("cairo")
                print("Using cairo for graphics operations.")
            end
        elseif line == "" then
        elseif util.startsWith(line, ":") then
            -- label, pass.
        elseif (assignment == true) and (patcher.strict~=true) then
            if patcher.variables.DEFTYPE=="str" then
                patcher.variables[keyword] = util.ltrim(data)
                printVerbose('Variable: %s = "%s"', keyword, util.ltrim(data))
            elseif patcher.variables.DEFTYPE=="num" then
                local k,v = util.trim(keyword), util.trim(data)
                patcher.variables[k] = util.toNumber(v)
                printVerbose('Variable: %s = 0x%x (%s)', k, patcher.variables[k], patcher.variables[k])
            elseif patcher.variables.DEFTYPE=="dec" then
                local k,v = util.trim(keyword), util.trim(data)
                patcher.variables[k] = util.toNumber(v, 10)
                printVerbose('Variable: %s = 0x%x (%s)', k, patcher.variables[k], patcher.variables[k])
            end
        elseif patcher.asmMode and (keyword == ".db" or keyword == ".dw") then
            printf("%s %s", keyword, data)
            for k,v in pairs(util.split(data, ",")) do
                print(v)
            end
        elseif patcher.asmMode and keyword == ".org" then
            local address = data:gsub("%$","0x")
            address = tonumber(address)
            patcher.asmAddress = address
        elseif false and patcher.asmMode and (util.trim(keyword):match("^([%a_]+[%w_]*):$")) then
            -- match labels with nothing else on the line
            --printf("k=[%s] d=[%s]", keyword, data)
            keyword = util.trim(keyword)
            local m = util.trim(keyword):match("^([%a_]+[%w_]*):$")
            printf("(asm label address=%08x) %s:", patcher.asmAddress, m)
        elseif patcher.asmMode and keyword=="asmlabel" then
            patcher.variables[asmLabel.name]=string.format("$%04x",asmLabel.address)
            printf("*(asm label address=%08x) %s:", asmLabel.address, asmLabel.name)

        elseif patcher.asmMode and patcher.asm.key[keyword:upper()] then
            if asmLabel then
                patcher.variables[asmLabel.name]=string.format("$%04x",asmLabel.address)
                printf("(asm label address=%08x) %s:", asmLabel.address, asmLabel.name)
            end
            local instruction = keyword:lower()
            
            local mode = ""
            
            if data then
                --printf("%s %s", keyword, data)
                -- replace first variable, accounting for a starting "#"
                if data:match("^#?[%a_][%w_]*") then
                    local imm = data:match("^(#?)[%a_][%w_]*") or ""
                    --printf("*data=%s imm=%s m=%s",data, imm, data:match("^#?([%a_][%w_]*)"))
                    --data = data:gsub("^#?([%a_][%w_]*)",imm..(patcher.variables[data:match("^#?([%a_][%w_]*)")] or "0"),1)
                    
                    data = util.replace(data, imm..data:match("^#?([%a_][%w_]*)"), imm..(patcher.variables[data:match("^#?([%a_][%w_]*)")] or "0"),1)
                    
                    --printf("**data=%s",data)
                    --break
                end
                
                -- replace variables, accounting for + or - operators
                while data:match("[+-][%a_][%w_]*") do
                    local operator = data:match("([+-])[%a_][%w_]*") or ""
                    --printf("***operator=%s m=%s data=%s",operator, data:match("[+-]([%a_][%w_]*)"),data)
                    --data = data:gsub("[+-]([%a_][%w_]*)",operator.."__PLACEHOLDER__",1)
                    data = util.replace(data, operator..data:match("[+-]([%a_][%w_]*)"), operator..(patcher.variables[data:match("[+-]([%a_][%w_]*)")] or "0"),1)
                    --printf("***done")
                    --break
                end
                
                -- replace binary with decimal
                while data:match("%%[01]+") do
                    data = data:gsub("%%([01]+)",tonumber(data:match("%%([01]+)"),2),1)
                    --break
                end
                
                -- replace hexidecimal with decimal
                while data:match("%$[%w_]+") do
                    data = data:gsub("%$([%w_]+)",tonumber(data:match("%$([%w_]+)"),16),1)
                    --break
                end
                
                
                -- Calculate
                local imm = ""
                if util.startsWith(data, "#") then imm="#" end
                if data:gsub("#",""):match("^[%d][%d%s%+%-]*$") then
                    local f=util.sandbox:loadCode("return "..data:gsub("#",""))
                    data = tostring(f())
                else
                    data = "0"
                end
                data = imm..data
                
                if util.startsWith(data, "#") then
                    -- immediate
                    mode = "#"
                elseif util.startsWith(data, "$") then
                    -- absolute
                    mode = "a"
                elseif util.startsWith(data, "(") then
                    mode = "indirect"
                else
                    mode = "r"
                end
            else
                -- implied
                mode = "i"
            end
            
            for i=0,0xff do
                local v = patcher.asm.set[i] or {}
                if v.opcode == instruction and v.length==1 then
                        printf("%04x: %02x        ;%s",patcher.asmAddress, i, v.format or patcher.asm.key[instruction:upper()])
                elseif mode == "a" and v.opcode == instruction and v.mode == "r" then
                    --- relative, like beq, bne, etc
                    local operand = data:gsub("#","")
                    operand = operand:gsub("%$","0x0")
                    operand = tonumber(operand) or 0
                    
                    operand = operand-patcher.asmAddress-v.length
                    --operand = 0
                    
                    local fmt = v.format or patcher.asm.key[instruction:upper()]
                    fmt = fmt:gsub("<1>", string.format("%02x",operand))
                    printf("%04x: %02x %02x     ;%s",patcher.asmAddress, i, operand, fmt)
                    patcher.asmAddress = patcher.asmAddress + v.length
                elseif v.mode==mode and v.opcode == instruction then
                    if v.length==1 then
                        printf("%04x: %02x        ;%s",patcher.asmAddress, i, v.format or patcher.asm.key[instruction:upper()])
                    elseif v.length==2 then
                        --print("**2")
                        local operand = data:gsub("#","")
                        operand = operand:gsub("%$","0x0")
                        operand = tonumber(operand) or 0
                        local fmt = v.format or patcher.asm.key[instruction:upper()]
                        fmt = fmt:gsub("<1>", string.format("%02x",operand))
                        printf("%04x: %02x %02x     ;%s",patcher.asmAddress, i, operand, fmt)
                        --print("**2end")
                    elseif v.length==3 then
                        --print("**3")
                        local operand = data:gsub("#","")
                        operand = operand:gsub("%$","0x0")
                        operand = tonumber(operand) or 0
                        local fmt = v.format or patcher.asm.key[instruction:upper()]
                        fmt = fmt:gsub("<1>", string.format("%02x",operand))
                        printf("%04x: %02x %02x %02x  ;%s",patcher.asmAddress, i, operand % 0x100, math.floor(operand /0x100), fmt)
                    end
                    
                    patcher.asmAddress = patcher.asmAddress + v.length
                end
            end
        else
            if patcher.interactive then
                print(string.format("unknown command: %s",line))
            else
                if (patcher.strict==true) or patcher.verboseLevel >= 2 then
                    warning("Unknown command: %s",line)
                end
            end
        end
        
        if fillVar then
            printVerbose('-->Variable: %s = %s', fillVar, util.limitString(patcher.variables.RET))
            patcher.variables[fillVar] = patcher.variables.RET
        end
        
    end
    end --loopCount
    end)
    
    if status==true then
        -- no errors
    else
        quit(err)
    end
    if patcher.breakLoop==true then
        break
    end
end

if patcher.saved then
    printf('Patching complete.  Output to file "%s"', patcher.outputFileName)
else
    if patcher.strict or patcher.breakType == "break" then
        -- In strict mode, require an explicit save
        -- If break is used, don't save.
        printf("done.")
    else
        if patcher.outputFileName then
            patcher.save()
            -- Save if not in strict mode and quit or exit is used.
            printf('Patching complete.  Output to file "%s"', patcher.outputFileName)
        else
            printf('Patching complete.', patcher.outputFileName)
        end
    end
end

printVerbose(string.format("\nelapsed time: %.2f\n", os.clock() - executionTime))

patcher.addLauncherDirective("outputfile", patcher.outputFileName)

quit()
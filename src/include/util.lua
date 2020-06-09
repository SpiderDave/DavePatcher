local util={}

-- Remove all spaces from a string
util.stripSpaces = function(s)
    return string.gsub(s, "%s", "")
end

util.printf = function(s,...)
    --return io.write(s:format(...))
    --return print(s:format(...))
    return print(s:format(...))
end


function util.fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

-- Check if we're on Windows
function util.isWindows()
    return (package.config:sub(1,1)=="\\")
end

-- Get all keys of a table, sorted
function util.keys(t)
    local keys={}
    local ikeys={}
    for k,v in pairs(t) do
        if type(k)=="string" then
            keys[#keys+1]=k
        elseif type(k)=="number" then
            ikeys[#ikeys+1]=k
        end
    end

    table.sort(keys)
    table.sort(ikeys)
    
    local newTable = {}
    for k,v in pairs(ikeys) do
      newTable[#newTable+1]=v
    end
    for k,v in pairs(keys) do
      newTable[#newTable+1]=v
    end
    return newTable
end

function util.switch(s, default)
    s=util.trim(s)
    if s == "true" or s == "on" then return true end
    if s == "false" or s == "off" then return false end
    if s == "" or s==nil then return default end
    return nil, true
end

function util.startsWith(haystack, needle)
    return string.sub(haystack, 1, string.len(needle)) == needle
end

function util.endsWith(haystack, needle)
   return needle=='' or string.sub(haystack,-string.len(needle))==needle
end

function util.trim(s)
    --if type(s)~="string" then return tostring(s) end
    if not s then return end
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


function util.limitString(s, limit)
    if type(s)~="string" then return s end
    limit = limit or 0x80
    if #s>limit then
        s=s:sub(1,limit).."..."
    end
    return s
end

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

function util.join(a,str)
    local out=""
    for i=1,#a do
        out=out..a[i]
        if i<#a then
            out=out..str
        end
    end
    return out
end

function util.upFolder(path)
    path=util.split(path, "/")
    table.remove(path)
    return util.join(path,"/")
end

function util.writeToFile(file,address, data, wipe)
    if wipe==true or (not util.fileExists(file)) then
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

function util.logToFile(file, data)
    if (not util.fileExists(file)) then
        local f=io.open(file,"w")
        f:close()
    end
    if not data then return nil end
    local f = io.open(file,"a")
    if not f then return nil end
    f:write(data.."\n")
    f:close()
    return true
end

function util.bin2hex(str)
    local output = ""
    for i = 1, #str do
        local c = string.byte(str:sub(i,i))
        output=output..string.format("%02x", c)
    end
    return output
end

function util.hex2bin(str)
    str = util.stripSpaces(str)
    
    local output = ""
    for i = 1, (#str/2) do
        local c = str:sub(i*2-1,i*2)
        
        -- Not a hex digit, return nil
        if not tonumber(c, 16) then return end
        
        output=output..string.char(tonumber(c, 16))
    end
    return output
end

function util.twosCompliment(n)
    if n>=0x80 then
        return n-0x100
    else
        return n
    end
end

function util.sub(s,pattern, replace, n)
    pattern = string.gsub(pattern, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    replace = string.gsub(replace, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    return string.gsub(s, pattern, replace, n)
end

-- return a valid identifier given a string, or nil if it's not valid.
-- To be a valid "identifier" it must follow these rules:
--   * first character must be a letter or _
--   * string must only contain alphanumeric or _
function util.identifier(id)
    if not id then return end
    if type(id)~="string" then return end
    id=util.trim(id)
    if id=="" then return end
    
    if(id:match("^[%a_]+[%w_]?$")) then return id end
    
    return
end

function util.getFileSize(file)
    local current = file:seek()      -- get current position
    local size = file:seek("end")    -- get file size
    file:seek("set", current)        -- restore position
    return size
end

function util.getFileContents(path)
    local file = io.open(path,"rb")
    if file==nil then return nil end
    io.input(file)
    local ret=io.read("*a")
    io.close(file)
    return ret
end

function util.deleteFile(f)
    os.remove(f)
end

-- this is wrong! use below
function util._rawToNumber(d)
    -- msb first
--    local v = 0
--    for i=1,#d do
--        v = v * 256
--        v = v + d:sub(i,i):byte()
--    end
--    return v
    local n=0
    for i=1,#d do
        n =n+ d:byte(-i)*16^(i-1)
    end
    return n
end

function util.rawToNumber(d)
    -- msb first
    local v = 0
    for i=1,#d do
        v = v * 256
        v = v + d:sub(i,i):byte()
    end
    return v
end





util.serialize = function(t)
    return Tserial.pack(t)
end
util.unserialize = function(s)
    return Tserial.unpack(s)
end

util.calc = function(x)
    x="1+1"
    return load("return " .. x)
end


util._calc= function(e)
    e="("..e..")"
    --print("e="..e)
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
            return string.format("%x", f(util.toNumber(m),util.toNumber(m2)))
        else
            return e
        end
    end

    local calc2 = function(e)
        local m = e:match("^.[%w%*%-%+%/]-$")
        if m then
            --print("  matched:"..m)
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
            --print("match:"..m)
            e=e:gsub("%((.[^%(%)]-)%)", "("..calc2(m)..")")
            --print("e="..e)
        end


        local m = e:match("%((%w+)%)")
        if m then
            --print("match():"..m)
            e=e:gsub("%((%w+)%)", m)
            --print("e="..e)
            --print("e="..e)
        end
        
    end
    return e
end

-- Convert a binary number string to a number with an optional base
function util.toNumber_Binary(s, base)
    local n=0
    for i=1,#s do
        n=n+(2^(i-1))*tonumber(s:sub(-i,-i))
    end
    return tonumber(tostring(n), base or 10)
end

function util.replace(text, old, new, n)
    n=n or 1
    for i=1,n do
        local b,e = text:find(old,1,true)
        if b==nil then
        else
            text = text:sub(1,b-1) .. new .. text:sub(e+1)
        end
    end
    return text
end

function util.contains(list, item)
    for k, v in pairs(list) do
        if v == item then return true end
    end
    return false
end

return util
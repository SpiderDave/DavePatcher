local patcher = {
    startAddress=0
}

version='DavePatcher 0.2'
patcher.version = version

function quit(text)
  if text then print(text) end
  os.exit()
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

function showHelp()
    print(version)
    print("\nUsage: davepatcher <patch file> <file to patch>\n  Example: davepatcher patch.txt contra.nes")
    print()
    if arg[1]=="-?" or arg[1]=="/?" or arg[1]=="/help" or arg[1]=="/h" or arg[1]=="-h" then
        print [[
Lines starting with // are comments.
    // This is a comment
Lines starting with # are "annotations"; Annotations are comments that are shown in the output when running the patcher.
    # This is an annotation
Keywords are lowercase, usually followed by a space.  Some "keywords" consist of multiple words.  Possible keywords:
    hex <address> <data>
        Set data at <address> to <data>.  <data> should be hexidecimal, and its length should be a multiple of 2.
        Example:
            hex a010 0001ff
    text <address> <text>
        Set data at <address> to <text>.  Use the textmap command to set a custom format for the text.  If no textmap is set, ASCII is assumed.
        Example:
            hex a010 FOOBAR
    find text <text>
        Find text data.  Use the textmap command to set a custom format for the text.  If no textmap is set, ASCII is assumed.
        Example:
            find text FOOBAR
    find hex <data>
        Find data in hexidecimal.  The length of the data must be a multiple of 2.
        Example:
            find hex 00ff1012
    textmap <characters> <map to>
        Map text characters to specific values.  These will be used in other commands like the "text" command.
        Example:
            textmap ABCD 30313233
    textmap space <map to>
        Use this format to map the space character.
        Example:
            textmap space 00
    break
        Use this to end the patch early.  Handy if you want to add some testing stuff at the bottom.
    start <address>
        Set the starting address for commands
        Example:
            start 10200
            find hex a901
]]
    else
        print("For more information, type davepatcher -?")
    end
end

file=arg[2]
if not arg[1] or not arg[2] or arg[3] then
    showHelp()
    quit()
end

file_dumptext = nil
filedata=getfilecontents(file)

local patchfile = io.open(arg[1] or "patch.txt","r")
while true do
    local line = patchfile:read("*l")
    if line == nil then break end
    if startsWith(line, '#') then
        print(string.sub(line,1))
    elseif startsWith(line, 'find hex ') then
        local data=string.sub(line,10)
        address=0
        print(string.format("Find hex: %s",data))
        for i=1,50 do
            address = filedata:find(hex2bin(data),address+1, true)
            if address then
                if address>patcher.startAddress then
                    print(string.format("    %s Found at 0x%08x",data,address-1))
                end
            else
                break
            end
        end
    elseif startsWith(line, 'find text') then
        local txt=string.sub(line,11)
        address=0
        print(string.format("Find text: %s",txt))
        for i=1,10 do
            address = filedata:find(mapText(txt),address+1)
            if address then
                if address>patcher.startAddress then
                    print(string.format("    %s Found at 0x%08x",txt,address-1))
                end
            else
                if i==1 then
                    print "    Not found."
                end
                break
            end
        end
    elseif startsWith(line, 'text ') then
        local data=string.sub(line,6)
        local address = data:sub(1,(data:find(' ')))
        address = tonumber(address, 16)
        txt=data:sub((data:find(' ')+1))
        print(string.format("Setting ascii text: 0x%08x: %s",address,txt))
        txt=string.gsub(txt, "|", string.char(0))
        
        txt=mapText(txt)
        
        if not writeToFile(file, address,txt) then quit("Error: Could not write to file.") end
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
        old=filedata:sub(address+1,address+#txt/2)
        old=bin2hex(old)
        print(string.format("Setting hex bytes: 0x%08x: %s --> %s",address,old, txt))
        if not writeToFile(file, address,hex2bin(txt)) then quit("Error: Could not write to file.") end
    elseif line=="break" then
        print("[break]")
        break
    elseif startsWith(line, 'start ') then
        local data=string.sub(line,7)
        patcher.startAddress = tonumber(data, 16)
        print("Setting Start Address: "..data)
    end
end
patchfile:close()
print('done.')



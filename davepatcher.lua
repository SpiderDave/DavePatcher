local patcher = {
    name = "DavePatcher",
    version = "0.5.2",
    released = "2015",
    author = "SpiderDave",
    startAddress=0,
    offset = 0,
    verbose = false,
    interactive = false
}

if patcher.verbose then
    printVerbose = print
else
    printVerbose = function() end
end


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

function showHelp(quick)
    print(string.format("%s version %s - %s %s",patcher.name,patcher.version,patcher.released,patcher.author))
    print()
    if not patcher.interactive then
        print [[
Usage: davepatcher [options...] <patch file> <file to patch>
       davepatcher [options...] -i <file to patch>

Options:
  -h          show help
  -i          interactive mode
        ]]
    end
    print()
    if not quick then
        print [[
Lines starting with // are comments.

    // This is a comment
    
Lines starting with # are "annotations"; Annotations are comments that are
shown in the output when running the patcher.
    
    # This is an annotation
    
Keywords are lowercase, usually followed by a space.  Some "keywords" consist
of multiple words.  Possible keywords:

    help
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
    
    refresh
        refreshes the data so that keywords like "find text" will use the new
        altered data.
]]
    else
        print("For more information, type davepatcher -?")
    end
end

if arg[1]=="-?" or arg[1]=="/?" or arg[1]=="/help" or arg[1]=="/h" or arg[1]=="-h" then
    showHelp()
    quit()
end

file=arg[2]
if not arg[1] or not arg[2] or arg[3] then
    showHelp(true)
    quit()
end

if arg[1] == "-i" then
    patcher.interactive = true
end

printVerbose(string.format("file: %s",file))

file_dumptext = nil
filedata=getfilecontents(file)

local patchfile
if not patcher.interactive==true then
    patchfile = io.open(arg[1] or "patch.txt","r")
end
local breakLoop = false
while true do
    local line
    if patcher.interactive==true then
        io.write(">")
        line = io.stdin:read("*l")
    else
        line = patchfile:read("*l")
    end
    if line == nil then break end
    
    local status, err = pcall(function()
    
    if startsWith(line, '#') then
        print(string.sub(line,1))
    elseif startsWith(line, '//') then
        -- comment
    elseif startsWith(line, 'help') then
        showHelp()
    elseif startsWith(line, 'find hex ') then
        local data=string.sub(line,10)
        address=0
        print(string.format("Find hex: %s",data))
        for i=1,50 do
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
    elseif startsWith(line, 'text ') then
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



function love.load(arg)
--function love.run()
    io.stdout:setvbuf("no")
    local arg= love.arg.parseGameArguments(arg)
    --os.exit = love.event.quit
    
    --local arg = arg or {"dummy", "patch.txt"}
    --local path = table.remove(arg, 1)
    local status, err = pcall(function () 
        require "version"
        require "davepatcher"
    end)
    if status then
    else
        print(err)
    end
    return
end

function love.quit()
    io.write("test\ntest")
    --print("quitting")
end
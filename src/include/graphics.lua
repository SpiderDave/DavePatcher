--Wrap either cairo (recommended) or gd

local gd
local cairo
local CAIRO

local graphics = {
    default = "cairo",
    modes = {"cairo", "gd"},
}

function graphics:init(m)
    m=m or self.mode or self.default
    self["mode"] = m --if I write this as self.mode then it breaks syntax highlighting of Notepad3.
    if m=="gd" then
        if self.use_gd then
            self.use_cairo = false
            return
        else
            if gd then self.use_gd = true return end
            if not pcall(function()
                gd = require("gd")
                self.use_gd = true
                self.use_cairo = false
            end) then
                gd = false
            end
        end
    elseif m=="cairo" then
        if self.use_cairo then
            self.use_gd = false
            return
        else
            if cairo then self.use_cairo = true return end
            if not pcall(function()
                cairo = require("lcairo")
                CAIRO = cairo
                self.use_cairo = true
                self.use_gd = false
            end) then
                cairo = false
                CAIRO = cairo
            end
        end
    end
    if cairo or gd then
        return true
    else
        err("could not load gd or cairo")
    end
end

function graphics:getPixel(image, x,y)
    self:init()
    if self.use_cairo then
        local data = cairo.image_surface_get_data(image.cs)
        local f = cairo.image_surface_get_format(image.cs)
        local w = cairo.image_surface_get_width(image.cs)
        local h = cairo.image_surface_get_height(image.cs)
        local stride = cairo.image_surface_get_stride(image.cs)
        --local c = bin2hex(data:sub(y*stride+x*4+1,y*stride+x*4+4))
        local b = data:sub(y*stride+x*4+1,y*stride+x*4+1):byte()
        local g = data:sub(y*stride+x*4+2,y*stride+x*4+2):byte()
        local r = data:sub(y*stride+x*4+3,y*stride+x*4+3):byte()
        local a = data:sub(y*stride+x*4+4,y*stride+x*4+4):byte()
        return r,g,b,a
    elseif self.use_gd then
        local c = image:getPixel(x,y)
        local r,g,b=image:red(c),image:green(c),image:blue(c)
        return r,g,b,0xff
    end
end

function graphics:setPixel(image, x,y,r,g,b)
    local cs, cr
    self:init()
    if self.use_cairo then
        cr=image.cr
        cairo.rectangle(cr, x, y, 1, 1)
        cairo.set_source_rgb(cr, r/256,g/256,b/256)
        cairo.fill(cr)
    elseif self.use_gd then
        local c = image:colorResolve(r,g,b)
        image:setPixel(x,y, c)
    end
end

function graphics:createImage(w,h)
    local cs, cr
    self:init()
    local image
    if self.use_cairo then
        cs = cairo.image_surface_create(CAIRO.FORMAT_RGB24, w, h)
        if not cs then
            return false
        end
        cr = cairo.create(cs)
        
        cairo.rectangle(cr, 0,0, w,h)
        cairo.set_source_rgb(cr, 0, 0, 0)
        cairo.fill(cr)
        
        image = {cs=cs,cr=cr}
    elseif self.use_gd then
        image=gd.createTrueColor(w,h)
    end
    return image
end

function graphics:loadPng(fileName, w,h)
    local cs, cr
    self:init()
    
    local image
    if self.use_cairo then
        
       -- make sure the file exists.  the program 
       -- crashes even with pcall below on an empty file.
       local f=io.open(fileName,"r")
       if f~=nil then io.close(f) else return end
        
        if pcall(function()
            cs = cairo.image_surface_create_from_png(fileName)
            cr = cairo.create(cs)
            image = {cs=cs,cr=cr}
        end) then
            return image
        else
            return
        end
        
    elseif self.use_gd then
        image = gd.createFromPng(fileName)
    end
    return image
end

function graphics:savePng(image, fileName)
    self:init()
    
    if self.use_cairo then
        cairo.surface_write_to_png(image.cs, fileName)
    elseif self.use_gd then
        image:png(fileName)
    end
end

function graphics:copy(dest, source, sourceX,sourceY, w, h, destX, destY)
    self:init()
    if self.use_cairo then
--        cairo.rectangle(dest.cr, destX,destY, w,h)
--        cairo.set_source_rgb(dest.cr, 0, 0, 0)
--        cairo.fill(dest.cr)

--        cairo.set_source_surface(dest.cr, source.cs, destX,destY)
--        cairo.rectangle(source.cr, sourceX,sourceY,w,h)
--        cairo.fill(dest.cr)


--        cairo.set_source_surface(dest.cr, source.cs, sourceX,sourceY)
--        cairo.rectangle(source.cr, sourceX,sourceY,w,h)
--        cairo.fill(dest.cr)
        
        local r,g,b,a
        a=0xff;
        
        for y=0,h-1 do
            for x=0,w-1 do
                r,g,b = graphics:getPixel(source,sourceX+x,sourceY+y)
                graphics:setPixel(dest,destX+x,destY+y,r,g,b)
            end
        end
        
        

    elseif self.use_gd then
        gd.copy(dest, source, destX,destY,sourceX,sourceY, w, h)
    end
end

function graphics:getSize(image)
    self:init()
    local w,h
    if self.use_cairo then
        w = cairo.image_surface_get_width(image.cs)
        h = cairo.image_surface_get_height(image.cs)
    elseif self.use_gd then
        w,h = image:sizeXY()
    end
    return w,h
end

return graphics
-- Double-ended queue class (deque)
-- Can be used as a queue or stack
local Deque = {}

-- Constructor
function Deque:new(...)
    local object = {
    }
    setmetatable(object, { __index = Deque})
    return object
end

function Deque:push(...)
    local args = {...}
    for i=1,#args do
        table.insert(self, args[i])
    end
end
Deque.add = Deque.push

function Deque:pop()
    return table.remove(self)
end

function Deque:shift()
    return table.remove(self, 1)
end

function Deque:unShift(item)
    table.insert(self, 1, item)
end

function Deque:last()
    return self[#self]
end
Deque.peek = Deque.last

function Deque:first()
    return self[1]
end

return Deque

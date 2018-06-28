-- SpiderDave's Rand library
--
-- Generates pseudo-random or quasi-random numbers and sequences.
--
-- ToDo: 
--     Describe methods
--     Add more ToDo things.

local bit = {}
local rand = {}
local state
rand.methods = {
    "Xorshift",
    "Halton",
}

-- Default method to use
rand.method = "Xorshift"

function bit.bxor(a,b)
    local p,c=1,0
    while a>0 and b>0 do
        local ra,rb=a%2,b%2
        if ra~=rb then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    if a<b then a=b end
    while a>0 do
        local ra=a%2
        if ra>0 then c=c+p end
        a,p=(a-ra)/2,p*2
    end
    return c
end

function bit.bor(a,b)
    local p,c=1,0
    while a+b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>0 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

function bit.bnot(n)
    local p,c=1,0
    while n>0 do
        local r=n%2
        if r<1 then c=c+p end
        n,p=(n-r)/2,p*2
    end
    return c
end

function bit.band(a,b)
    local p,c=1,0
    while a>0 and b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>1 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

function bit.rshift(a,disp)
    if disp < 0 then return bit.lshift(a,-disp) end
    return math.floor(a % 2^32 / 2^disp)
end

function bit.lshift(a,disp)
    if disp < 0 then return bit.rshift(a,-disp) end 
    return (a * 2^disp) % 2^32
end

rand.seed = 505454

function rand.getMethods()
    return rand.methods
end

function rand.xorshift(state)
    local x = state or rand.lastState or rand.seed
    rand.lastState = x
    x = bit.bxor(x, (bit.lshift(x,13)))
    x = bit.bxor(x, (bit.rshift(x,17)))
    x = bit.bxor(x, (bit.lshift(x,5)))
    rand.nextState = x
    return x / 2^32
end

-- halton sequence
function rand.halton(index, base)
    rand.nextState = index+1
    base = base or 2
    local result = 0
    local f = 1 / base
    repeat
        result = result + f * (index % base)
        index = math.floor(index / base)
        f = f / base
    until index == 0
    rand.lastState = index
    
    return result
end

local randomGenerator={}

-- Constructor
function randomGenerator:new(...)
    local args = {...}
    local object = {
        method = rand.method
    }
    object.seed = args[1] or rand.seed
    if args[1] then object.seed = args[1] end
    setmetatable(object, { __index = randomGenerator})
    return object
end

function randomGenerator:setSeed(seed)
    assert(seed > 0, "seed must be greater than 0")
    self.seed = seed
end

function randomGenerator:getSeed(seed)
    return self.seed
end

function randomGenerator:random(...)
    local args = {...}
    self.state = self.state or self.seed or rand.seed
    local r
    
    if self.method == "Xorshift" then
        r = rand.xorshift(self.state)
        self.state = rand.nextState
        if args[1] then
            if args[2] then
                -- random(min, max) returns uniformly distributed pseudo-random integer number between min and max inclusive. 
                return math.floor(r * (args[2]-args[1]+1))+args[1]
            else
                -- random(max) returns uniformly distributed pseudo-random integer number between 1 and max inclusive.
                return math.floor(r * args[1])+1
            end
        else
            -- random() returns uniformly distributed pseudo-random number between 0 and 1 inclusive. 
            return r
        end
    elseif self.method == "Halton" then
        -- returns a quasi-random number in the halton sequence.
        r = rand.halton(self.state, self.base or 2)
        self.state = rand.nextState
        return r
    else
        -- Create a custom method.
        --
        -- Example:
        --     rng = rand:newRandomGenerator()
        --     function rng:foobar(...) return math.random(...) end
        --     rng.method = "Foobar"
        local method = string.lower(self.method)
        assert(self[method], "Random method unknown.")
        assert(type(self[method]) =="function", "Random method is not callable.")
        return self[string.lower(self.method)](self, ...)
    end
end

function randomGenerator:getState()
    return self.state
end

function randomGenerator:setState(state)
    self.state = state
end

function rand.newRandomGenerator(...)
    return randomGenerator:new(...)
end

rand.bit = bit
return rand
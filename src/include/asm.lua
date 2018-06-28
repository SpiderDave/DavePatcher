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

asm.key={
    ["#"]="immediate",
    ["a"]="absolute",
    ["r"]="relative",
    ["zp"]="zero page",
    ["()"]="indirect",
    ["i"]="implied",
    ["A"]="accumulator",
    ["x"]="x register",
    ["y"]="y register",

    ["ADC"]="add with carry",
    ["AND"]="and (with accumulator)",
    ["ASL"]="arithmetic shift left",
    ["BCC"]="branch on carry clear",
    ["BCS"]="branch on carry set",
    ["BEQ"]="branch on equal (zero set)",
    ["BIT"]="bit test",
    ["BMI"]="branch on minus (negative set)",
    ["BNE"]="branch on not equal (zero clear)",
    ["BPL"]="branch on plus (negative clear)",
    ["BRK"]="interrupt",
    ["BVC"]="branch on overflow clear",
    ["BVS"]="branch on overflow set",
    ["CLC"]="clear carry",
    ["CLD"]="clear decimal",
    ["CLI"]="clear interrupt disable",
    ["CLV"]="clear overflow",
    ["CMP"]="compare (with accumulator)",
    ["CPX"]="compare with X",
    ["CPY"]="compare with Y",
    ["DEC"]="decrement",
    ["DEX"]="decrement X",
    ["DEY"]="decrement Y",
    ["EOR"]="exclusive or (with accumulator)",
    ["INC"]="increment",
    ["INX"]="increment X",
    ["INY"]="increment Y",
    ["JMP"]="jump",
    ["JSR"]="jump subroutine",
    ["LDA"]="load accumulator",
    ["LDY"]="load X",
    ["LDY"]="load Y",
    ["LSR"]="logical shift right",
    ["NOP"]="no operation",
    ["ORA"]="or with accumulator",
    ["PHA"]="push accumulator",
    ["PHP"]="push processor status (SR)",
    ["PLA"]="pull accumulator",
    ["PLP"]="pull processor status (SR)",
    ["ROL"]="rotate left",
    ["ROR"]="rotate right",
    ["RTI"]="return from interrupt",
    ["RTS"]="return from subroutine",
    ["SBC"]="subtract with carry",
    ["SEC"]="set carry",
    ["SED"]="set decimal",
    ["SEI"]="set interrupt disable",
    ["STA"]="store accumulator",
    ["STX"]="store X",
    ["STY"]="store Y",
    ["TAX"]="transfer accumulator to X",
    ["TAY"]="transfer accumulator to Y",
    ["TSX"]="transfer stack pointer to X",
    ["TXA"]="transfer X to accumulator",
    ["TXS"]="transfer X to stack pointer",
    ["TYA"]="transfer Y to accumulator",
}

asm.set={
    [0x00]={opcode="brk", mode="i", length=1, format="BRK"},
    [0x01]={opcode="ora", mode="(zp,x)", length=2},
    [0x05]={opcode="ora", mode="zp", length=2},
    [0x06]={opcode="asl", mode="zp", length=2},
    [0x08]={opcode="php", mode="i", length=1, format="PHP"},
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
    
    [0x20]={opcode="jsr", mode="a", length=3, format = "JSR $<2><1>"},
    
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
    [0x30]={opcode="bmi", mode="r", length=2, format = "BMI $+<1>"},
    [0x31]={opcode="and", mode="(zp),y", length=2},
    [0x35]={opcode="and", mode="zp,x", length=2},
    [0x36]={opcode="rol", mode="zp,x", length=2},
    [0x38]={opcode="sec", mode="i", length=1, format = "SEC"},
    [0x39]={opcode="and", mode="a,y", length=3},
    [0x3c]={opcode="rts", mode="i", length=1},
    [0x3d]={opcode="and", mode="a,x", length=3},
    [0x3e]={opcode="rol", mode="a,x", length=3},
    [0x41]={opcode="eor", mode="(zp,x)", length=2},
    [0x45]={opcode="eor", mode="zp", length=2},
    [0x46]={opcode="lsr", mode="zp", length=2},
    [0x48]={opcode="pha", mode="i", length=1},
    [0x49]={opcode="eor", mode="#", length=2},
    [0x4a]={opcode="lsr", mode="A", length=1, format = "LSR"},
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
    
    [0x60]={opcode="rts", mode="i", length=1, format="RTS ----"},
    
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
    [0x85]={opcode="sta", mode="zp", length=2, format="sta $00<1>"},
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
    [0xa0]={opcode="ldy", mode="#", length=2, format="ldy #$<1>"},
    [0xa1]={opcode="lda", mode="(zp,x)", length=2},
    [0xa2]={opcode="ldx", mode="#", length=2},
    [0xa4]={opcode="ldy", mode="zp", length=2},
    [0xa5]={opcode="lda", mode="zp", length=2, format = "lda $00<1>"},
    [0xa6]={opcode="ldx", mode="zp", length=2},
    [0xa8]={opcode="tay", mode="i", length=1},
    [0xa9]={opcode="lda", mode="#", length=2, format = "lda #$<1>"},
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
    
    [0xc8]={opcode="iny", mode="i", length=1, format = "iny"},
    
    [0xc9]={opcode="cmp", mode="#", length=2},
    [0xca]={opcode="dex", mode="i", length=1, format="dex"},
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
    
    [0xe8]={opcode="inx", mode="i", length=1, format = "inx"},
    
    [0xe9]={opcode="sbc", mode="#", length=2, format = "SBC #$<1>"},
    [0xea]={opcode="nop", mode="i", length=1, format="nop"},
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
    ["default"]={opcode="", mode="", length=1, format="undefined"},
}


asm.print = function(s)
    local data = hex2bin(s)
    local out = ""
    local i = 1
    
    
    while true do
        local n = rawToNumber(data:sub(i,i))
        local s = asm.set[n] or asm.set.default
        
        for j = 1,3 do
            if j<= s.length then
                out = out .. string.format("%02x",rawToNumber(data:sub(i+j-1,i+j-1)))
            else
                out = out .. "  "
            end
        end
        
        --out = out .. string.format(" %s %s",s.opcode, s.mode)
        
        local f = ""
        if s.format then
            out = out .. " ("
            f = s.format
            f=string.gsub(f, "<1>",bin2hex(data:sub(i+1,i+1)))
            f=string.gsub(f, "<2>",bin2hex(data:sub(i+2,i+2)))
            out = out..f..")"
        else
            out = out .. string.format(" %s %s",s.opcode, s.mode)
        end
        out = out .. "\n"
        
        i=i+s.length
        if i>#data then break end
    end
    
    return out
end

return asm
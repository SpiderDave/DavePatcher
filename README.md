```
DavePatcher v2017.05.19 - SpiderDave https://github.com/SpiderDave/DavePatcher
A custom patcher for use with NES romhacking or general use.


Some commands require Lua-GD https://sourceforge.net/projects/lua-gd/


Lines starting with // are comments.
    
    // This is a comment
    
You can also do a comment at the end of a line:
    
    put 1200 a963 // set lives to 99
    
When comments are stripped, it will remove up to one space before the // 
automatically, so if you need whitespace in your command, add an extra 
space before the // like so:
    
    text 3400 FOOBAR  // set name to "FOOBAR "
    
Lines starting with # are "annotations"; Annotations are comments that are
shown in the output when running the patcher.
    
    # This is an annotation
    
Lines starting with : are labels.  See also "goto" keyword.
    
    :myLabel
    
You can use %variable% for variables to make replacements in a line:
    
    var foobar = fox
    var baz = dog
    # the quick brown %foobar% jumps over the lazy %baz%.
    
Keywords are lowercase, usually followed by a space.  Some "keywords" consist
of multiple words.  Possible keywords:

    help
    commands
        Show this help.  May be useful in interactive mode.
        
    get <address> <len>
        display <len> bytes of data at <address>
    get hex <address> <len>
        (depreciated) same as get
    
    get asm <address> <len>
        get <len> bytes of data at <address> and analyze using 6502 opcodes,
        display formatted asm data.
    
    print asm <data>
        analyze hexidecimal data <data> using 6502 opcodes, display formatted
        asm data.
    
    put <address> <data>
        Set data at <address> to <data>.  <data> should be hexidecimal, and
        its length should be a multiple of 2.  You may include spaces in data
        for readability.
        Example:
            put a010 0001ff
    hex <address> <data>
        (depreciated) same as put
    
    fill <address> <count> <data>
        Fill the address at <address> with <data> repeated <count> times.
        
        Example:
            put a010 06 a900
            
        This is the same as:
            put a010 a900a900a900a900a900a900
    
    copy <address1> <address2> <length>
        Copies data from <address1> to <address2>.  The number of bytes is
        specified in hexidecimal by <length>.

        Example:
            copy a010 b010 0a
            
    copy hex <address1> <address2> <length>
        (depreciated) same as copy
        
    text <address> <text>
        Set data at <address> to <text>.  Use the textmap command to set a 
        custom format for the text.  If no textmap is set, ASCII is assumed.
        Example:
            text a010 FOOBAR
            
    find text <text>
        Find text data.  Use the textmap command to set a custom format for
        the text.  If no textmap is set, ASCII is assumed.
        Example:
            find text FOOBAR
            
    find <data>
        Find data in hexidecimal.  The length of the data must be a multiple
        of 2.
        Example:
            find 00ff1012
            
    find hex <data>
        (depreciated) same as find
        
    textmap <characters> <map to>
        Map text characters to specific values.  These will be used in other
        commands like the "text" command.
        Example:
            textmap ABCD 30313233
            
    textmap space <map to>
        Use this format to map the space character.
        Example:
            textmap space 00
            
    skip
    ...
    end skip
        skip this section.  You may put text after skip and end.
        Example:
        skip -------------
        // unstable
        put 10000 55
        end skip ---------
    
    break
        Use this to end the patch early.  Handy if you want to add some
        testing stuff at the bottom.
        
    goto <label>
        Go to the label <label>.
        Example:
            goto foobar
            :foobar
        
    start <address>
        Set the starting address for commands
        Example:
            start 10200
            find a901
            
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
            
    start tilemap <name>
    ...
    end tilemap
        Define a tile map to be used with the export map command.
        valid commands within the block are:
        
        address = <address>
            Set the address for the tile map.
        <tileNum> <x> <y> [h]
            Tile map entry.  "h" in the fourth field is used to optionally flip
            the tile horizontally.  In the future, other flags like "v" for
            vertical flipping will be used here as well.
        
        Example:
            start tilemap batman
            address = 2c000
            81 1 0 h
            82 2 0 h
            90 0 1 h
            91 1 1 h
            92 2 1 h
            a0 0 2 h
            a1 1 2 h
            a2 2 2 h
            b0 0 3 h
            b1 1 3 h
            b2 2 3 h
            end

    export map <tilemap> <file>
        export tile data to png file using a tile map.
        Example:
            export map batman batman_sprite_test.png
    
    import map
        import tile data from png file using a tile map
        Example:
            import map batman batman_sprite_test.png
    
    gg <gg code> [anything]
        decode and apply a NES Game Genie code.  If there is a space after the
        code you may add whatever text you like, as a convenience.
        Example:
            gg SZNZVOVK        Infinite bombs
        
    refresh
        refreshes the data so that keywords like "find text" will use the new
        altered data.
        
    code
        Execute Lua code
        Example:
            code print("Hello World!")
        
    eval
        Evaluate Lua expression and print the result
        Examples:
            eval "Hello World!"
            eval 5+5*2^10
        
    verbose [on | off]
        Turn verbose mode on or off.  This prints more information when using
        various commands.  If verbose is used without a parameter, off is
        assumed.
        
    diff <file>
        Show differences between the current file and <file>
    
    repeat <n>
    ...
    end repeat
        Repeat the lines in the block <n> times.
    
    var <var name> = <string>
        A basic variable assignment.  Currently you can only assign a string
        value.
    
    if <var>==<string>
    ...
    else
    ...
    end if
        A basic if,else,end if block.  "else" is optional, and it's very 
        limited.  Can not be nested currently, only comparison with string
        is supported.

```
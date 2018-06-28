```
DavePatcher v2018.06.28 beta - SpiderDave https://github.com/SpiderDave/DavePatcher
A custom patcher for use with NES romhacking or general use.

Some commands require Lua Cairo (recommended) http://www.dynaset.org/dogusanh/luacairo.html 
--or--
Lua-GD https://sourceforge.net/projects/lua-gd/


Lines starting with // are comments.
    
    // This is a comment
    
You can also do a comment at the end of a line:
    
    put 1200 a963 // set lives to 99
    
When comments are stripped, it will remove up to one space before the // 
automatically, so if you need whitespace in your command, add an extra 
space before the // like so:
    
    text 3400 FOOBAR  // set name to "FOOBAR "
    
You can do a block level comment by enclosing lines in /* */ like this:
    
    /*
    put 1200 a963 // set lives to 99
    */
    
You can't nest comments with /* */ but you can use the /** and **/ instead
to accomplish this.  Nested comments are messy, and should be avoided.
    
Lines starting with # are "annotations"; Annotations are comments that are
shown in the output when running the patcher when annotations are on  See
also "annotations" keyword.
    
    # This is an annotation
    
Lines starting with : are labels.  See also "goto" keyword.
    
    :myLabel
    
You can use %variable% for variables to make replacements in a line:
    
    var foobar = fox
    var baz = dog
    # the quick brown %foobar% jumps over the lazy %baz%.
    
Keywords are lowercase, usually followed by a space.  Some "keywords" consist
of multiple words.  Keywords listed as accepting "on" or "off" as parameters 
also accept "true" or "false".  If left blank, "on" is assumed.
Keywords accepting <address> parameter may also accept "*" in place of an 
address.  This uses the value of special variable "ADDRESS", which is set after
most read or write operations.

Possible keywords:

    help
    commands
        Show this help.  May be useful in interactive mode.
        
    load <file>
        Loads <file> and refreshes the data.
    
    save <file>
        Save data to <file>.  If the file ends in ".ips" it will save the data 
        as an ips patch.  If save isn't used in the patch it will automatically
        save at the end of the patch, unless strict mode is on or break is used.
    
    file <file>
        Changes the file but does not refresh the data.
    
    outputfile <file>
        Sets the output file.  If not set, defaults to output.nes.
        
    get <address> <len>
        Display <len> bytes of data at <address>
    get hex <address> <len>
        (depreciated) same as get
    
    get asm <address> <len>
        Get <len> bytes of data at <address> and analyze using 6502 opcodes,
        display formatted asm data.
    
    print <text>
        Prints a line of text.
    
    start print
    ...
    end print
        Prints everything inside the block.
    
    print asm <data>
        Analyze hexidecimal data <data> using 6502 opcodes, display formatted
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
            
    bitop [<op>]
        Set the bitwise operation for commands to <op>.  Valid operations are
        or, and and xor.  If no operation supplied, then return commands to 
        normal.  This sets the variable BITOPER.
        
    address <address>
        Set the current address without using another command.  This is the 
        same as modifying the variable ADDRESS directly.
        
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
        
    replace <finddata> <replacedata> [<limit>]
        Find and replace data in hexidecimal with an optional limit in hexidecimal.
        Examples:
            replace a9008d35 a9048d35
            replace a9058d30 a9638d30
            
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
        Skip this section.  This is similar to /* */ comments.  For
        readability, it is recommended to use the skip keyword if
        you want to do conditional skip/end skip
        Example:
        skip
            // unstable
            put 10000 55
        end skip
        
    break
        Use this to end the patch early.  Handy if you want to add some
        testing stuff at the bottom.
    
    error [<reason>]
        End the patch early and display an error message.  Optionally 
        provide a reason.
        
    pause (broken at the moment!)
        Pauses script and waits for user input
    
    getinput <text>
        Prompt for user input displaying <text> and store the result in 
        the variable "INPUT".
    
    goto <label>
        Go to the label <label>.
        Example:
            goto foobar
            :foobar
        If there are multiple labels, it will go to the next one, and
        start at the beginning if not found.
        
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
    
    makeips <file>
        create ips file named <file> from the current patch.  Note: RLE is not
        yet supported.
    
    palette file <file>
        set the available NES palette via file
        Example:
            palette file FCEUX.pal
    
    palette <data>
        set the current 4-color palette from a hexidecimal string.
        Example:
            palette 0f182737
            
    palette auto
        use preferred palette defined in tilemap when exporting
    
    palette manual
        ignore preferred palette defined in tilemap when exporting
    
    export <address> <nTiles> <file>
        export tile data to png file.
        Example:
            export 20010 100 tiles.png
        Example:
            # Exporting all tiles.  This will take a long time!
            export %CHRSTART% %CHRSIZE% tiles.png
    
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
        palette = <palette>
            Set the preferred palette for the tile map.
            Example:
                palette = 0030270f
        gridsize = <size>
            Set the grid size to <size>.  This determines what the x and y values
            of each tile map entry is multiplied by (default is 8).
        adjust = <x> <y>
            adjust the placement of the tile by <x>,<y> pixels.
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
            end tilemap

    export map <tilemap> <file>
        export tile data to png file using a tile map.
        Example:
            export map batman batman_sprite_test.png
        
    import map <tilemap> <file>
        import tile data from png file using a tile map
        Example:
            import map batman batman_sprite_test.png
    
    gg <gg code>
        decode and apply a NES Game Genie code.
        Example:
            gg SZNZVOVK        // Infinite bombs
        
    refresh
        refreshes the data so that keywords like "find text" will use the new
        altered data.
    
    refresh auto
        automatically refresh the data after each change.
    
    refresh manual
        do not automatically refresh the data after each change.  Use "refresh"
        command manually.
        
    code
        Execute Lua code
        Example:
            code print("Hello World!")
        
    eval
        Evaluate Lua expression and print the result.  The result will also be
        stored in the variable "RESULT".
        Examples:
            eval "Hello World!"
            eval 5+5*2^10
        
    verbose [on | off]
        Turn verbose mode on or off.  This prints more information when using
        various commands.

    annotations [on | off]
        Turn annotations on or off.
        
    diff <file>
        Show differences between the current file and <file>
    
    repeat <n>
    ...
    end repeat
        Repeat the lines in the block <n> times.
    
    var <var name> = <string>
        A basic variable assignment.  Currently you can only assign a string
        value.  You may also do variable assignment without using "var" if
        not in strict mode, but if the variable name contains a space, you
        must use the var keyword.
    num <var name> = <number>
        variable assignment to a number type
    
    list variables
        Show a list of all variables.  In addition to variables defined using
        the "var" keyword, there are "special variables" that are set
        automatically, so this is handy for finding them.
    
    if <var>[==<variable>]
    ...
    else
    ...
    end if
        A basic if, else, end if block.  "else" is optional.  if..then blocks
        are whitespace-aware and can be nested.  For comparison purposes, 
        numeric strings are equal to numbers, and for truth testing, 0
        or the empty string "" or "false" are considered false (though "" 
        is not equal to 0).
    
    choose <string>
        randomly selects an item in <string> separated by spaces and puts the
        result in the variable "CHOICE".
        Example:
            choose apple banana orange potato
            print %CHOICE%
            
    include <file>
        Dynamically include another patch file as if it were inserted at this
        line.
    
    start function <fname>
    ...
    end function
        Define a function named <fname>.  Functions must be defined before used.
        Example:
            // Define the function
            start function exportchr
                print Warning! About to export entire CHR.  This may take a while.
                getinput Are you sure? (y/n)
                if %INPUT% == y
                    print Exporting CHR...
                    export %CHRSTART% %CHRSIZE% test.png
                else
                    print CHR export aborted.
                end if
            end function
            
            // Call the function
            exportchr()
    
    run <fname>
        Call function named <fname>.
    
    <fname>()
        Call function named <fname>.
    
    use [gd | cairo]
        Initialize graphics to use gd or cairo libraries.
    
    strict [on | off]
        Turn strict mode on or off.  In strict mode:
        * "var" keyword is required for variable assignment.
        * break on all warnings.
        * disable auto save (see "save" keyword).


```
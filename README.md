```
DavePatcher 0.5.5 (2015) - SpiderDave https://github.com/SpiderDave/DavePatcher
A custom patcher for use with NES romhacking or general use.
Lines starting with // are comments.

    // This is a comment
    
Lines starting with # are "annotations"; Annotations are comments that are
shown in the output when running the patcher.
    
    # This is an annotation
    
Keywords are lowercase, usually followed by a space.  Some "keywords" consist
of multiple words.  Possible keywords:

    help
    commands
        Show this help.  May be useful in interactive mode.
        
    hex <address> <data>
        Set data at <address> to <data>.  <data> should be hexidecimal, and
        its length should be a multiple of 2.  You may include spaces in data
        for readability.
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
    end
        Define a tile map to be used with the export map command.
        Example:
            start tilemap batman
            address = 2c000
            81 1 0
            82 2 0
            90 0 1
            91 1 1
            92 2 1
            a0 0 2
            a1 1 2
            a2 2 2
            b0 0 3
            b1 1 3
            b2 2 3
            end

    export map <tilemap> <file>
        export tile data to png file using a tile map.
        Example:
            export map batman batman_sprite_test.png
    
    import map
        (not yet implemented)
    
    gg <gg code>
        WIP
        decode a NES Game Genie code (does not apply it)
        
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

```
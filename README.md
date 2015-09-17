```
DavePatcher version 0.5 - 2015 SpiderDave

Usage: davepatcher [options...] <patch file> <file to patch>
       davepatcher [options...] -i <file to patch>
General options:
  -h          show help
  -i          interactive mode
        

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

```
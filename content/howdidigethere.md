In addition to being a great line from David Byrne and Talking Heads (from "Life
During Wartime"), this is also a question I often ask myself when
looking at log files. Today's tip is worth the price of the whole blog (i.e.,
free), but I predict that you'll be glad you know it.

<!--more-->

It's pretty common to pipe the output of a command, or string of commands, to a
file to have a record of what happened when executing the command, something
like this:

`big_gnarly_command_line_with_options 2>&1 | tee logfile.out`

That works great for capturing the *output* of the command, but what about the
big_gnarly_command_line_with_options itself?

Try this instead:

` bash -x -c "big_gnarly_command_line_with_options" 2>&1 | tee logfile.out`


Now, your output file will look like this:

`+ big_gnarly_command_line_with_options`<br>
`... output of big_gnarly_command_line_with_options ...`

If your gnarly command is actually several gnarly commands, enclose the whole
gnarly list in parentheses and separate with semicolons (or &&), like so:

` bash -x -c "(big_gnarly_command_line_with_options_1;
big_gnarly_command_line_with_options_2)" 2>&1 | tee logfile.out`

Normal quoting rules apply:

-   If you enclose the command(s) in double-quotes ("), variable substitution
    will be done on the command line

-   If you need to include a double-quote within double-quotes, you need to
    escape it (with the backslash (\\) character)

-   If you enclose the command line(s) in single quotes ('), no variable
    substitution is done

-   There is no way to include a single-quote within single-quotes, but there is
    a trick that gives a similar effect, that you can read about here (<http://stackoverflow.com/a/1250279/203044>).

Now you'll never need to ask yourself "How did I get here"?

  
  


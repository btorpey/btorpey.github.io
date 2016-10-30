{% img right /images/customtailor.jpg %}

As developers, we seem to take a special delight in personalizing the virtual worlds in which we work -- from color palettes to keyboards, fonts, macros, you name it.  "Off-the-rack" is never good enough, we want Saville Row tailoring for our environments.

And a lot of the tools we use support and encourage that customization, giving us control over every little option.

But not every tool we use does so -- read on to learn a very simple trick to how to take control even when your tool doesn't make that easy.

<!-- more -->

In Linux, we have a couple of common ways to customize the way our tools work -- by defining environment variables, and by using configuration files.  Sometimes these two mechanisms work well together, and we can include environment variables in configuration files to make them flexible in different situations.

Not every tool can expand environment varaiables in its configuration files, however.  In that case, you can use this simple Perl one-liner to subsitute values from the environment into any plain-text file.

    perl -pe '$_=qx"/bin/echo -n \"$_\"";' < sample.ini


What's happpening here is

The `-p` switch tells Perl to read every line of input and print it.

The `-e` switch tells Perl to execute the supplied Perl code against every line of input.

The code snippet replaces the value of the input line (`$_`) with the results of the shell command specified by the `qx` function.  That shell command simply echos[^echo] the value of the line (`$_`), but it does so inside double quotes (the `\"`), which causes the shell to replace any environment variable with its value.

[^echo]: Note that we use /bin/echo here, instead of just plain echo, to get around an issue with the echo command in BSD (i.e., OSX).

And that's it!  Since the subsitution is being done by the shell itself, you can use either form for the environment variable (either `$VARIABLE` or `${VARIABLE}`), and the replacement is always done using the rules for the current shell.

Here's an example -- let's create a simple .ini type file, like so:

    username=$USER
    host=$HOSTNAME
    home-directory=$HOME
    current-directory=$PWD

When we run this file through our Perl one-liner, we get:

    perl -pe '$_=qx"/bin/echo -n \"$_\"";' < sample.ini
    username=btorpey
    host=btmac
    home-directory=/Users/btorpey
    current-directory=/Users/btorpey/blog/code/tailor

One thing to watch out for is that things can get a little hinky if your input file contains quotes, since the shell will interpret those, and probably not in the way you intend.  At least in my experience, that would be pretty rare -- but if you do get peculiar output that would be something to check.

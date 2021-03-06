{% img left /images/phl.pm.org-camel.png 320 240 %} 

No, not that -- it's Perl day.  (Well, actually it's just Wednesday, but you get the idea).

Sometimes it seems that everybody likes to hate on Perl, but I think their
animus is misdirected. It's not Perl that's the problem, it's those \^\\\$\(\.\#\!\)?$
regular expressions.

Or, as Jamie Zawinski once said 
["Some people, when confronted with a problem, think "I know, I'll use regular expressions." Now they have two problems."](http://en.wikiquote.org/wiki/Jamie_Zawinski).

Well, I'm here to tell you that it's possible to write whole Perl programs that
actually accomplish useful work, **without any regular expressions at all**! And, if you do
that, you can actually *read the code!*

It turns out that Perl is a dandy scripting language, and while some may take issue
with its flexibility ("There's more than one way to do it"), others (including me) find that flexibility very useful.

<!--more-->

One example of that flexibility is how easy it is to create a Perl program that
can read input either from stdin, or from a file specified on the command line.

    local *INFILE;
    if (defined($ARGV[0])) {
        open(INFILE, "<:crlf", "$ARGV[0]") or die "Cant open $ARGV[0]\n";
    }
    else {
        *INFILE = *STDIN;
    }

    while (<INFILE>) {
    }

    close(INFILE);

The above snippet does just that, and also works well with command-line parsers
(e.g., `GetOpt`) that eat their parameters by removing them from the ARGV
array.



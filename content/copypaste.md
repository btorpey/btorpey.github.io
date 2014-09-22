{% img left /images/nun-with-ruler.jpg 240 160 %} 

When I was a kid I went to Catholic school, and back in those days 
the nuns would indeed rap your knuckles with a ruler if you
misbehaved. That doesn't happen so much any more, but when I see someone 
making use of the [copy-paste anti-pattern](http://c2.com/cgi/wiki?CopyAndPasteProgramming), 
I'm tempted to reach for a ruler myself. 
(I know, probably not a good career move ;-)

Short of rapping someone's knuckles with a ruler, though, how do you show some poor sinner the error of his ways?

<!--more-->

Enter [CPD, or copy-paste detector](http://pmd.sourceforge.net/pmd-5.1.3/cpd-usage.html). 
This does pretty much what you would guess from its name -- it
spins through all the code you give it, and analyzes it for repeated sequences.
[^1]

Here's an example of running the GUI version against the code I used 
in an [earlier post](http://btorpey.github.io/blog/2014/02/12/shared-singletons/) on smart pointers.

{% img right /images/cpd.png %}

(Note that the "Ignore literals" and "Ignore identifiers" checkboxes are
disabled if you select C++ as the language - these options [are only implemented for Java currently](http://sourceforge.net/p/pmd/discussion/188193/thread/91553283)).

The site has several more examples, but [this one](http://pmd.sourceforge.net/pmd-5.1.3/cpdresults.txt) just blew my mind -- 
hard to imagine how anyone could write this code in
the first place, much less be so confident that it is correct that they just
copy and paste it in two different files (with nary a comment to tie the two
together)?

<pre>
=====================================================================
Found a 19 line (329 tokens) duplication in the following files: 
Starting at line 685 of /usr/local/java/src/java/util/BitSet.java
Starting at line 2270 of /usr/local/java/src/java/math/BigInteger.java
    static int bitLen(int w) {
        // Binary search - decision tree (5 tests, rarely 6)
        return
         (w < 1<<15 ?
          (w < 1<<7 ?
           (w < 1<<3 ?
            (w < 1<<1 ? (w < 1<<0 ? (w<0 ? 32 : 0) : 1) : (w < 1<<2 ? 2 : 3)) :
            (w < 1<<5 ? (w < 1<<4 ? 4 : 5) : (w < 1<<6 ? 6 : 7))) :
           (w < 1<<11 ?
            (w < 1<<9 ? (w < 1<<8 ? 8 : 9) : (w < 1<<10 ? 10 : 11)) :
            (w < 1<<13 ? (w < 1<<12 ? 12 : 13) : (w < 1<<14 ? 14 : 15)))) :
          (w < 1<<23 ?
           (w < 1<<19 ?
            (w < 1<<17 ? (w < 1<<16 ? 16 : 17) : (w < 1<<18 ? 18 : 19)) :
            (w < 1<<21 ? (w < 1<<20 ? 20 : 21) : (w < 1<<22 ? 22 : 23))) :
           (w < 1<<27 ?
            (w < 1<<25 ? (w < 1<<24 ? 24 : 25) : (w < 1<<26 ? 26 : 27)) :
            (w < 1<<29 ? (w < 1<<28 ? 28 : 29) : (w < 1<<30 ? 30 : 31)))));
    }

</pre>

So, if you need to lead someone to the light, try PMD's copy-paste detector.  It
may hurt a bit, but a lot less than a sharp rap on the knuckles!

One last caveat about CPD: it does not like symlinks at all -- you must give it the real path names for any source files, or
you will just get a bunch of "Skipping ... since it appears to be a symlink" messages.


[^1]: CPD is part of the [PMD tool](http://pmd.sourceforge.net/pmd-5.1.3/), which can do a lot of useful things with Java code. But since I'm primarily dealing with C++ code these days (and because duplicate code is such a hot-button issue for me), CPD is the part that I use.

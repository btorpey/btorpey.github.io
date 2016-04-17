{% img left /images/Holloway-Kaa-The-Jungle-Book.jpg 235 192 %}

I remember seeing Disney's original "Jungle Book" when I was a kid, and being blown away.  Not so much with the movie itself, but that music -- wow!  It was probably my first exposure to any kind of jazz, and it was quite an experience.

One of the bad guys in the movie is Kaa the python[^1], who was really sneaky, and hypnotized his victims.

[^1]: Voiced by Sterling Holloway, who was also the voice of Winnie the Pooh.  Go figure.

Recently I was installing a new version of gdb, but no matter what I did I couldn't get pretty-printing to work.

As it happens, Python was the sneaky bad guy here too.  Read on to see how to thwart him and get pretty-printing in your version of gdb.

<!-- more -->

First off, this whole ordeal was caused by the fact that I do almost all of my work on RedHat Linux (or its cousin, CentOS).  For better or worse, RedHat is the Linux of choice for many companies because of the stability of the OS, and the extended support from RedHat.

That stability comes at a price, though.  One way that RedHat tries to provide stability is by freezing so-called "upstream" packages when they create a new major version.  So, the version of gdb installed with RH6 is gdb 7.2 (which was originally released back in 2010).  The latest gdb version at the time of this writing is 7.11, so there's obviously been a fair amount of water over the dam by now.  Plus, gdb 7.2 can't debug code compiled with gcc 5, and that's a show-stopper.

So, it was time to update gdb.  How hard could that be?

## Building gdb `--with-python`

I had a relatively new-ish version of python (2.7.11) installed as my default, so I figured I could just crank up a build and gdb would find it and do the right thing.  When that didn't work ("Scripting in the "Python" language is not supported in this copy of GDB"), I went back to the build and explicitly specified `--with-python` in the `configure` command -- still no luck.  I tried several variations, and when none of them worked, I dug into the configure log, and found the following:

    configure:8458: checking whether to use python
    configure:8460: result: yes
    configure:8509: checking for python
    configure:8527: found /build/share/python/2.7.10/bin/python
    configure:8540: result: /build/share/python/2.7.10/bin/python
    configure:8678: checking for python2.7
    configure:8696: gcc -o conftest -g -O2   -I/build/share/python/2.7.10/include/python2.7 -I/build/share/python/2.7.10/include/python2.7   conftest.c -ldl -lncurses -lm -ldl    -lpthread -ldl -lutil -lm -lpython2.7 -Xlinker -export-dynamic >&5
    /usr/bin/ld: cannot find -lpython2.7
    collect2: ld returned 1 exit status
    ...
    configure:8889: error: python is missing or unusable

Now I knew I had python's library directory on my LD\_LIBRARY\_PATH ([more on that later]()), so what could the problem be?

Next step was to look in gdb's `confiugre.ac` script, where exist 326 (!) lines of code devoted solely to figuring out how to link in the python libraries.  In my case, they end up deciding to call `python-config --ldflags` and use the output of that command to set the linker flags -- on my machine(s), the output is:

    $ python-config --ldflags
    -lpython2.7 -lpthread -ldl -lutil -lm -Xlinker -export-dynamic

So that explains why the test program won't link -- there's no `-L` parameter to specify the location of libpython.  (Since the configure script, apparently, properly disables linking against LD\_LIBRARY\_PATH).

So, the root cause of the problem is python-config's failure to report the location of the python library.  This apparently happens only when python is built with the `--enable-shared` flag -- for what possible reason I can't imagine, but there is discussion of the problem and a patch for it [here](https://sourceware.org/ml/gdb-patches/2010-07/msg00168.html).  I'm guessing that patch may have made it into the 3.x branch, but it sure ain't in 2.7.

I try *really* hard to avoid having to patch software as part of the build process -- it's error-prone, hard to automate, and can cause problems that are extremely difficult to track down.

## Hacking python-config

While searching for a solution, I found a post about [cross-compiling gdb](https://sourceware.org/gdb/wiki/CrossCompilingWithPythonSupport) with python support.  (Thank you, Doug Evans!)

Well, the same approach works even when *not* cross-compiling, so I put together a little wrapper script for python-config that delegates to the real thing, but supplies the missing `-L` parameter.

{% include_code gdb-python/python-hack.sh  %}

The we build gdb using the hack script instead of the installed python-config:

{% include_code gdb-python/build-gdb.sh  %}

## Running gdb

Let's create a little test program and see how we did:

{% include_code gdb-python/test.cpp  %}

When we debug the test program, we see that printing an stl object gives much more readable output:

    $ g++ -g test.cpp
    $ gdb a.out
    ...
    (gdb) p hello
    $1 = "Hello, world!"

But, you can still get to the underlying data structure if you need to:

    (gdb) p /r hello
    $2 = {static npos = 18446744073709551615,
      _M_dataplus = {<std::allocator<char>> = {<__gnu_cxx::new_allocator<char>> = {<No data fields>}, <No data fields>}, _M_p = 0x601028 "Hello, world!"}}

One last thing -- don't confuse the gdb `set print pretty on` command with python pretty-printing.  All that `set print pretty` does is indent structure members, rather than printing the whole thing on a single line, like so:

    (gdb) set print pretty on
    (gdb) p /r hello
    $3 = {
      static npos = 18446744073709551615,
      _M_dataplus = {
        <std::allocator<char>> = {
          <__gnu_cxx::new_allocator<char>> = {<No data fields>}, <No data fields>},
        members of std::basic_string<char, std::char_traits<char>, std::allocator<char> >::_Alloc_hider:
        _M_p = 0x601028 "Hello, world!"
      }
    }

## A note on building python
The default python on RH6 is version 2.6, and a lot of packages don't support anything older than 2.7.  So, I built a recent 2.7 version from source, but when I tried to run it I would get:

    python: error while loading shared libraries: libpython2.7.so.1.0: cannot open shared object file: No such file or directory

So, I added the python lib directory to LD\_LIBRARY\_PATH, but I didn't feel right about it -- most commands don't require that.

Thanks to [this post](http://stackoverflow.com/a/32558660/203044), I modified the build script to include an [RPATH](https://gcc.gnu.org/ml/gcc-help/2005-12/msg00017.html) in the python executable that eliminated the need to put the python lib directory on LD\_LIBRARY\_PATH.  Here's the python build script:

{% include_code gdb-python/build-python.sh  %}

Conclusion
----------

It seems that quite a few people have had the same problem that I did -- hope this helps.  And many thanks to all the people who took the trouble to share their own problems and solutions getting python pretty-printing to work with gdb.

---

### Footnotes

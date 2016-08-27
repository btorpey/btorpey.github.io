{% img left /images/Holloway-Kaa-The-Jungle-Book.jpg 235 192 %}

I remember seeing Disney's original "Jungle Book" when I was a kid, and being blown away.  Not so much with the movie itself, but that music -- wow!  It was probably my first exposure to any kind of jazz, and it was quite an experience.

One of the bad guys in the movie is Kaa the python[^1], who was really sneaky, and hypnotized his victims.

[^1]: Voiced by Sterling Holloway, who was also the voice of Winnie the Pooh.  Go figure.

Recently I was installing a new version of gdb, but no matter what I did I couldn't get pretty-printing to work.

As it happens, Python was the villain here too.  Read on to see how to thwart him and get pretty-printing in your version of gdb.

<!-- more -->

First off, this whole ordeal was caused by the fact that I do almost all of my work on RedHat Linux (or its cousin, CentOS).  For better or worse, RedHat is the Linux of choice for many companies because of the stability of the OS, and the extended support from RedHat.

That stability comes at a price, though.  One way that RedHat tries to provide stability is by freezing so-called "upstream" packages when they create a new major version.  So, the version of gdb installed with RH6 is gdb 7.2 (which was originally released back in 2010).  The latest gdb version at the time of this writing is 7.11, so there's obviously been a fair amount of water over the dam by now.  Plus, gdb 7.2 can't debug code compiled with gcc 5, and that's a show-stopper.

So, it was time to update gdb.  How hard could that be?  Well, it looked pretty straight-forward, and the build completed successfully.  But when I ran gdb, I noticed that it was no longer "pretty-printing" variables.

## Pretty-printing in gdb with python

Since about version 7, gdb has had the ability to "pretty-print" stl objects.  What that means is that when examining an stl object, gdb will display something more like what you would see in source code, as opposed to the internal representation of the stl object.  This is best illustrated with some example code, like the following:

``` cpp
#include <string>
#include <vector>
#include <map>

int main(int argc, char** argv)
{
   std::string hello = "Hello, ";
   std::string there = "there!";

   std::vector<std::string> v;
   v.push_back(hello);
   v.push_back(there);

   std::map<std::string, std::string>  m;
   m[hello] = there;

   return 0;
}
```

We build the program, open it in the debugger, set a breakpoint on the `return` statement, and examine the variables.

    g++ -g test.cpp
    gdb a.out
    b 17
    r

Without pretty printing, the output looks like this:

    (gdb) p hello
    $1 = {static npos = <optimized out>,
      _M_dataplus = {<std::allocator<char>> = {<__gnu_cxx::new_allocator<char>> = {<No data fields>}, <No data fields>},
        _M_p = 0x605028 "Hello, "}}
    (gdb) p v
    $2 = {<std::_Vector_base<std::basic_string<char, std::char_traits<char>, std::allocator<char> >, std::allocator<std::basic_string<char, std::char_traits<char>, std::allocator<char> > > >> = {
        _M_impl = {<std::allocator<std::basic_string<char, std::char_traits<char>, std::allocator<char> > >> = {<__gnu_cxx::new_allocator<std::basic_string<char, std::char_traits<char>, std::allocator<char> > >> = {<No data fields>}, <No data fields>},
          _M_start = 0x605090, _M_finish = 0x6050a0, _M_end_of_storage = 0x6050a0}}, <No data fields>}
    (gdb) p m
    $3 = {_M_t = {
        _M_impl = {<std::allocator<std::_Rb_tree_node<std::pair<std::basic_string<char, std::char_traits<char>, std::allocator<char> > const, std::basic_string<char, std::char_traits<char>, std::allocator<char> > > > >> = {<__gnu_cxx::new_allocator<std::_Rb_tree_node<std::pair<std::basic_string<char, std::char_traits<char>, std::allocator<char> > const, std::basic_string<char, std::char_traits<char>, std::allocator<char> > > > >> = {<No data fields>}, <No data fields>},
          _M_key_compare = {<std::binary_function<std::basic_string<char, std::char_traits<char>, std::allocator<char> >, std::basic_string<char, std::char_traits<char>, std::allocator<char> >, bool>> = {<No data fields>}, <No data fields>}, _M_header = {
            _M_color = std::_S_red, _M_parent = 0x6050b0, _M_left = 0x6050b0, _M_right = 0x6050b0}, _M_node_count = 1}}}

But with pretty-printing enabled, the same debug session looks like this:

    (gdb) p hello
    $1 = "Hello, "
    (gdb) p v
    $2 = std::vector of length 2, capacity 2 = {"Hello, ", "there!"}
    (gdb) p m
    $3 = std::map with 1 elements = {
     ["Hello, "] = "there!"
    }

Obviously, it would be nice to get pretty-printing working again.  So, what went wrong?

## Building gdb `--with-python`

Pretty-printing with gdb requires python support enabled in gdb at build time.  I had a relatively new-ish version of python (2.7.11) installed as my default, so I figured I could just crank up a build and gdb would find it and do the right thing.  When that didn't work, I went back to the build and explicitly specified `--with-python` in the `configure` command -- still no luck.  I tried several variations, and when none of them worked, I dug into the configure log, and found the following:

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

Now I knew I had python's library directory on my LD\_LIBRARY\_PATH ([more on that later](#building-python)), so what could the problem be?

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

## Building gdb

The we build gdb using the hack script instead of the installed python-config:

{% include_code gdb-python/build-gdb.sh  %}

Now, we've got pretty-printing back!

    (gdb) p hello
    $1 = "Hello, "
    (gdb) p v
    $3 = std::vector of length 2, capacity 2 = {"Hello, ", "there!"}
    (gdb) p m
    $4 = std::map with 1 elements = {
     ["Hello, "] = "there!"
    }


## Some notes on gdb

Even if pretty-printing is enabled, you can still get to the underlying data structure if you need to:

    (gdb) p /r hello
    $2 = {static npos = 18446744073709551615,
      _M_dataplus = {<std::allocator<char>> = {<__gnu_cxx::new_allocator<char>> = {<No data fields>}, <No data fields>}, _M_p = 0x601028 "Hello, world!"}}

Don't confuse the gdb `set print pretty on` command with python pretty-printing.  All that `set print pretty` does is indent structure members, rather than printing the whole thing on a single line, like so:

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

## Loading pretty printers at gdb startup

You may run across instructions on the intertubes (e.g., [here](https://sourceware.org/gdb/wiki/STLSupport)) that talk about changing your `.gdbinit` to manually import the python drivers needed for pretty-printing.  These instructions are somewhat dated -- while they still work, recent versions of gdb and gcc cooperate to make this all work "automagically", based on a fairly simple convention:

- When gdb loads your executable, it also needs to load any shared libraries that your executable uses.  One of these is libstdc++.so.
- When gdb loads libstdc++.so, if python scripting is enabled it also looks for a file named libstdc++.so.x.y.z-gdb.py (where x, y and z correspond to the version number of libstdc++.so) in the same directory.
- If it finds one, it executes it under control of the python interpreter.

(A snip from) That file is reproduced following -- note that the last two lines actually load and register the pretty printers associated with that version of the libstdc++.so.

{% include_code gdb-python/libstdc++.so.6.0.18-gdb.py  %}

Note that the values of `pythondir` and `libdir` match the location where the compiler and standard library are installed.  In my case, I'm using a version of gcc 4.8.2 that I compiled from source -- see [this recent post]() to find out more about the how's and why's of building from source and installing in a non-standard location).

This convention assumes that the version of the libstdc++ that gdb finds is the same as the version that was used to compile the executable.  They usually are, but if that is not the case, it's possible that the pretty printers will fail in interesting ways ;-)  See the next section for more on that.

## So, what could possibly go wrong?

Well, a whole bunch of things, as it turns out.  Some of them we've already touched on, but for the sake of completeness I'll mention them all here.

### Bad path in .gdbinit

    $ gdb a.out
    Python Exception <type 'exceptions.ImportError'> No module named gdb:
    /build/share/gdb/7.11/bin/gdb: warning:
    Could not load the Python gdb module from `/build/share/gdb/7.11/share/gdb/python'.
    Limited Python support is available from the _gdb module.
    Suggest passing --data-directory=/path/to/gdb/data-directory.

This is caused if you specify the wrong path in the `sys.path.insert` statement in .gdbinit.  As mentioned [above](#loading-pretty-printers-at-gdb-startup), it's not necessary to include this boilerplate in .gdbinit with more recent versions of gdb -- gdb will load the pretty-printers automatically.


### No python support in gdb

### gdb can't find libpython

    $ gdb a.out
    gdb: error while loading shared libraries: libpython2.7.so.1.0: cannot open shared object file: No such file or directory

If gdb can't find libpython.so, you will get this error from the loader.  To fix this, you can either include the python lib directory in LD\_LIBRARY\_PATH, or you can build gdb with an RPATH entry for libpython.so.  The latter approach is simpler, and if you use the build script [supplied earlier](#building-gdb), it will do that.


### Some variables print garbled


There can be (and are) differences in the internal implementations between different versions of libstdc++.  Application programs aren't affected by these differences, but the pretty-printers depend on those internal implementation details. Which means that the pretty-printer code is tied to a particular implementation, and a particular version (or versions) of libstdc++.

You can get output similar to the above if the python pretty-printers were written against a different version of libstdc++.so than the one that is loaded by gdb.  This can happen if you change your LD\_LIBRARY\_PATH to find another version of libstdc++.so th

to be obsolete, at least with the most recent version of gdb (7.11) -- pretty-printing works automagically, and no special configuration is required.


<a id="building-python"></a>

## A note on building python
The default python on RH6 is version 2.6, and a lot of packages don't support anything older than 2.7.  So, I built a recent 2.7 version from source, but when I tried to run it I would get:

    python: error while loading shared libraries: libpython2.7.so.1.0: cannot open shared object file: No such file or directory

So, I added the python lib directory to LD\_LIBRARY\_PATH, but I didn't feel right about it -- most commands don't require that.

Thanks to [this post](http://stackoverflow.com/a/32558660/203044), I modified the build script to include an [RPATH](https://gcc.gnu.org/ml/gcc-help/2005-12/msg00017.html) in the python executable that eliminated the need to put the python lib directory on LD\_LIBRARY\_PATH.  Here's the python build script:

{% include_code gdb-python/build-python.sh  %}

Conclusion
----------

It seems that quite a few people have had similar difficulties getting pretty-printing working as I did, so I hope this longish explanation is helpful.  And many thanks to all the people who took the trouble to share their own problems and solutions getting python pretty-printing to work with gdb.

As always, please leave a comment below (preferred), or  [contact me](<mailto:wallstprog@gmail.com>)
directly with comments, suggestions, corrections, etc.


Footnotes
---------

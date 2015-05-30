{% img left /images/timallen.jpg 230 240  %}

clang is a great compiler, with a boatload of extremely helpful tools, including static analysis, run-time memory and data race analysis, and many others.  And it's apparently pretty easy to get those benefits on one of the supported platforms -- basically Ubuntu and Mac (via XCode).

That's fine, but if you get paid to write software, there's a good chance it's going to be deployed on RedHat, or one of its variants.  And, getting clang working on RedHat is a huge pain in the neck.  The good news is that I did the dirty work for you (ouch!), so you don't have to.
<!--more-->
<br>

Bootstrapping the compiler
--------------------------

Like almost all compilers, clang is written in a high-level language (in this case C++), so building clang requires a host compiler to do the actual compilation.  On Linux this is almost always gcc, since it is ubiquitous on Linux machines.  

There's a hitch, though -- as of version 3.3 some parts of clang are written in C++11, so the compiler used to compile clang needs to support the C++11 standard.

This is a real problem with RedHat, since the system compiler supplied with
RedHat 6 (the most recent version that is in wide use), is gcc 4.4.7.  That
compiler does not support C++11, and so is not able to compile clang.  So, the
first step is getting a C++11-compliant compiler so we can compile clang.  For
this example, we're going to choose gcc 4.8.2, for a variety of reasons[^5].  The
good news is that gcc 4.8.2 is written in C++ 98, so we can build it using the
system compiler (gcc 4.4.7).  

The next thing we have to decide is where to install gcc 4.8.2, and we basically have these choices:

-   We could install in /usr, where the new compiler would replace the system compiler.  Once we do that, though, we've effectively created a custom OS that will be required on all our development/QA/production machines going forward.  If "all our development/QA/production machines" == 1, this may not be a problem, but as the number increases things can get out of hand quickly. This approach also does not lend itself to being able to have more than one version of a particular package on a single machine, which is often helpful.

-   We could install in /usr/local (the default for gcc, and many other packages when built from source), so the new compiler would coexist with the system compiler.  The problem with this approach is that /usr/local can (and in practice often does) rapidly turn into a dumping-ground for miscellaneous executables and libraries.  Which wouldn't be so bad if we were diligent about keeping track of what they were and where they came from, but if we're going to do that we might as well ...

-   Install somewhere else -- it doesn't really matter where, as long as there's a convention. In this case, we're going to use the convention that any software that is not bundled with the OS gets installed in /build/share/\<package\>/\<version\>.  This approach makes it easy to know exactly what versions of what software we're running, since we need to specify its install directory explicitly in PATH and/or LD\_LIBRARY\_PATH.  It also makes it much easier to keep track of what everything is and where it came from.

Here's a script that will download gcc 4.8.2 along with its prerequisites, build it and install it as per the convention we just discussed:

{% include_code clang/build-gcc.sh  %}

To run the script, change to an empty directory and then simply invoke the
script.  If you want to keep track of all the commands and output related to the
build, you can invoke the script using the trick I wrote about in an 
[earlier post](<http://btorpey.github.io/blog/2014/02/13/how-did-i-get-here/>).

Preparing to build
------------------

Now that we've built gcc, we can get started building clang[^1].  By default,
clang is built to use the C++ standard library (libstdc++) that is included with
gcc. That's the good news, since that means code generated using clang can be
intermixed freely with code generated with gcc -- which is almost all the code
on a typical Linux machine.

Finding the C++ standard library
--------------------------------

The libstdc++.so that is part of gcc is "versioned", which means that different library versions can have different symbols defined. Since we chose to install gcc 4.8.2 in a non-standard location, there are several settings that need to be tweaked to have code find and use that version of libstdc++[^4].

Let's start with a recap of how that works.

### Finding the C++ standard library at build-time

With a default installation of gcc, everything is easy: gcc itself is in /usr/bin, include files are in /usr/include (sort of), and library files are in /usr/lib and/or /usr/lib64. In cases where files are not installed in these locations, gcc itself keeps track of where it should look for dependencies, and the following command will show these locations:

    > g++ -E -x c++ - -v < /dev/null
    ...
    #include "..." search starts here:
    #include <...> search starts here:
     /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7
     /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7/x86_64-redhat-linux
     /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7/backward
     /usr/lib/gcc/x86_64-redhat-linux/4.4.7/include
     /usr/include
    End of search list.
    ...
    LIBRARY_PATH=/usr/lib/gcc/x86_64-redhat-linux/4.4.7/:/usr/lib/gcc/x86_64-redhat-linux/4.4.7/:/usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../lib64/:/lib/../lib64/:/usr/lib/../lib64/:/usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../:/lib/:/usr/lib/

With our non-standard installation of gcc 4.8.2, the same command shows the values appropriate for that version of the compiler:

    > /build/share/gcc/4.8.2/bin/g++ -E -x c++ - -v < /dev/null
    ...
    #include "..." search starts here:
    #include <...> search starts here:
     /shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/../../../../include/c++/4.8.2
     /shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/../../../../include/c++/4.8.2/x86_64-unknown-linux-gnu
     /shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/../../../../include/c++/4.8.2/backward
     /shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/include
     /shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/include-fixed
     /shared/build/share/gcc/4.8.2/bin/../lib/gcc/../../include
     /usr/include
    ...
    LIBRARY_PATH=/shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/:/shared/build/share/gcc/4.8.2/bin/../lib/gcc/:/shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/../../../../lib64/:/lib/../lib64/:/usr/lib/../lib64/:/shared/build/share/gcc/4.8.2/bin/../lib/gcc/x86_64-unknown-linux-gnu/4.8.2/../../../:/lib/:/usr/lib/

The situation with clang is a bit (!) more complicated. Not only does clang need
to be able to find its own include files and libraries, but it also needs to be
able to find the files for the compiler that clang is built with. In order
to successfully build clang with a non-standard compiler, we are going to need
to specify the following parameters to the clang build:

<table>
<col width="35%" />
<col width="60%" />
<tbody>
<tr class="odd">
<td align="left"><p>CMAKE_C_COMPILER</p></td>
<td align="left"><p>The location of the C compiler to use.</p></td>
</tr>
<tr class="even">
<td align="left"><p>CMAKE_CXX_COMPILER</p></td>
<td align="left"><p>The location of the C++ compiler to use.</p></td>
</tr>
<tr class="odd">
<td align="left"><p>CMAKE_INSTALL_PREFIX</p></td>
<td align="left"><p>The location where the compiler should be installed.</p></td>
</tr>
<tr class="even">
<td align="left"><p>CMAKE_CXX_LINK_FLAGS</p></td>
<td align="left"><p>Additional flags to be passed to the linker for C++ programs.  See below for more information.</p></td>
</tr>
<tr class="odd">
<td align="left"><p>GCC_INSTALL_PREFIX</p></td>
<td align="left"><p>Setting this parameter when building clang is equivalent to specifying the <code>--gcc-toolchain</code> parameter when invoking clang. See below for more information.</p></td>
</tr>
</tbody>
</table>

<br> 
While all these settings are documented in one place or another, as far as 
I know there is no single place that mentions them all.  (The clang developers apparently prefer writing code to writing
documentation ;-)  So, these settings have been cobbled together from a number
of sources (listed at the end of this article), and tested by much trial and
error.

The first three settings are plain-vanilla cmake settings, but the last two need some additional discussion:

### CMAKE\_CXX\_LINK\_FLAGS

In the clang build script this is set to `"-L${HOST_GCC}/lib64 -Wl,-rpath,${HOST_GCC}/lib64"`.  What this does is two-fold:

-   The `-L` parameter adds the following directory to the search path for the linker.  This is needed so the linker can locate the libraries installed with gcc 4.8.2.        

-   The `-Wl,-rpath,` parameter installs a ["run path"](<http://en.wikipedia.org/wiki/Rpath>) into any executables (including shared libraries) created during the build.  This is needed so any executables created can find their dependent libraries at run-time. 

    Note that you can display the run path for any executable (including shared libraries) with the following command:

        > objdump -x /build/share/clang/trunk/bin/clang++ | grep RPATH
        RPATH                /build/share/gcc/4.8.2/lib64:$ORIGIN/../lib

### GCC\_INSTALL\_PREFIX

Unfortunately, by default, clang looks for include and library files in the standard system locations (e.g., /usr), regardless of what compiler was used to build clang. (I filed a [bug report](http://llvm.org/bugs/show_bug.cgi?id=20510) for this behavior, but the clang developers apparently feel this is reasonable behavior. Reasonable people may disagree ;-)

The work-around for this is to specify GCC\_INSTALL\_PREFIX when building clang -- this tells the clang build where the gcc that is being used to build clang is located. Among other things, this determines where the clang compiler will look for system include and library files at compile and link time.

Building clang
--------------

Now that we have that out of the way, we can build clang. The following script will download clang source from svn, build and install it.

{% include_code clang/build-clang.sh  %}

Note that you can specify a parameter to the script (e.g., `-r 224019`) to get a specific version of clang from svn.


> Since this article was originally published, there have been some changes to the prerequisites for building clang:
> you will need cmake 2.8.12.2 or later, and python 2.7 or later. 


Building using clang
--------------------

At this point, we should have a working clang compiler that we can use to build and run our own code. But once again, because the "host" gcc (and libstdc++) are installed in a non-standard location, we need to tweak a couple of build settings to get a successful build.

### Specifying the compiler to use

There are a bunch of ways to specify the compiler, depending on what build system you're using -- I'll mention a couple of them here.

If you're using make, you can prefix the make command as follows:

    CC=clang CXX=clang++ make ... 

If you're using cmake you can [specify the compiler to use](http://www.cmake.org/Wiki/CMake_FAQ#How_do_I_use_a_different_compiler.3F) on the cmake command line, as follows:

    cmake -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ ... 

Personally, I find that ridiculously inconvenient, so in my CMakeLists.txt file I specify the compiler directly:

    # cmake doc says this is naughty, but their suggestions are even worse...
    if("$ENV{COMPILER}" STREQUAL "gcc")
      set(CMAKE_C_COMPILER      gcc)
      set(CMAKE_CXX_COMPILER    g++)
    elseif("$ENV{COMPILER}" STREQUAL "clang")
      set(CMAKE_C_COMPILER      clang)
      set(CMAKE_CXX_COMPILER    clang++)
    endif()

In any of the above, you can either specify the full path to the compiler, or just specify the name of the compiler executable (as above), and make sure that the executable is on your PATH.

Last but not least, if you're using GNU autotools -- you're on your own, good luck! The only thing I want to say about autotools is that [I agree with this guy](https://twitter.com/timmartin2/status/23365017839599616).

### Finding the C++ standard library at run-time

Any code genrated using clang is also going to need to be able to find the libraries that clang was built with at run-time. There are a couple of ways of doing that:

-   Similar to what we did above when building clang, you can specify the `-Wl,-rpath,` parameter to the linker to set a run path for your executables.
     Note that if you're using cmake, it will [automatically strip the rpath](<http://www.cmake.org/Wiki/CMake_RPATH_handling>) from all files when running `make install`, so you may need to disable that by setting `CMAKE_SKIP_INSTALL_RPATH` to false in your build.

-   Alternatively, you will need to make sure that the proper library directory is on your `LD_LIBRARY_PATH` at run-time[^3].

##So, What Could Possibly Go Wrong?

If you've followed the directions above, you should be good to go, but be warned that, just like in "Harry Potter", messing up any part of the spell can cause things to go spectacularly wrong. Here are a few examples:

-   If you try to use the system compiler (gcc 4.4.7) to build clang, you'll get an error like the following:

<!-- -->

    CMake Error at cmake/modules/HandleLLVMOptions.cmake:17 (message):
      Host GCC version must be at least 4.7!

-   The clang build executes code, that was built with clang, as part of the build step. If clang can't find the correct (i.e., gcc 4.8.2) version of libstdc++ at build time, you will see an error similar to the following:

<!-- -->

    Linking CXX static library ../../../../lib/libclangAnalysis.a
    [ 51%] Built target clangAnalysis
    [ 51%] Building CXX object tools/clang/lib/Sema/CMakeFiles/clangSema.dir/SemaConsumer.cpp.o
    [ 51%] Building CXX object tools/clang/lib/ARCMigrate/CMakeFiles/clangARCMigrate.dir/TransAutoreleasePool.cpp.o
    [ 51%] Building CXX object tools/clang/lib/AST/CMakeFiles/clangAST.dir/ExprConstant.cpp.o
    Scanning dependencies of target ClangDriverOptions
    [ 51%] Building Options.inc...
    ../../../../../bin/llvm-tblgen: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.15' not found (required by ../../../../../bin/llvm-tblgen)

-   If you build clang without specifying the `-Wl,-rpath` parameter, clang won't be able to find the libraries it needs at compile-time:

<!-- -->

    > clang++ $* hello.cpp && ./a.out
    clang++: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.14' not found (required by clang++)
    clang++: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.18' not found (required by clang++)
    clang++: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.15' not found (required by clang++)

-   If the GCC\_INSTALL\_PREFIX setting isn't specified when you build with clang, it will look for system files in /usr, rather than the proper directory, and you will see something like this:

<!-- -->

    > clang++ $* hello.cpp && ./a.out
    In file included from hello.cpp:1:
    In file included from /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7/iostream:40:
    In file included from /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7/ostream:40:
    In file included from /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7/ios:40:
    In file included from /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7/exception:148:
    /usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../include/c++/4.4.7/exception_ptr.h:143:13: error: unknown type name 'type_info'
          const type_info*
                ^
    1 error generated.

I've probably missed a couple, but you get the idea.

Conclusion
----------

There may be another way to build clang successfully on a RH-based system, but
if there is I've yet to discover it. As mentioned earlier, bits and pieces of
this information have been found in other sources, including the following:

<http://llvm.org/docs/GettingStarted.html#getting-a-modern-host-c-toolchain>

<http://clang-developers.42468.n3.nabble.com/getting-clang-to-find-non-default-libstdc-td3945163.html>

<https://code.google.com/p/memory-sanitizer/wiki/BuildingClangOnOlderSystems>

<http://llvm.org/docs/CMake.html>
 

[^1]: You will need at least version 2.8.12.2 of cmake to do the build, which is not native on RH/CentOS 6.  That version can be installed using "Add/Remove Software" or yum.  (Or, of course, you can build it from source). You will also need python 2.7 or later, which is probably better built from source, since the RH repos use the non-standard name "python27" for the executable.

[^3]: This is the approach we use in my shop -- we have a hard-and-fast rule that application code cannot contain a run path, and we deliberately strip any existing RPATH entries from code that is being deployed to QA and production as a security measure.

[^4]: I may go into more detail on this in a later post, but in the meantime if you're interested you should consult Ulrich Drepper's "How to Write Shared Libraries" at <http://www.akkadia.org/drepper/dsohowto.pdf>.

[^5]: One reason is that gcc 4.9.0 can't compile libc++, the llvm version of the C++ standard library -- see <http://lists.cs.uiuc.edu/pipermail/cfe-dev/2014-April/036669.html> for more detail.  While we're not going to discuss using libc++ in this post, we may get into that later on.
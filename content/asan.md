Valgrind has been an indispensable tool for C/C++ programmers for a long
time, and I've used it quite happily -- it's a tremendous tool for doing dynamic
analysis of program behavior at run time. valgrind[^3] can detect reads of
uninitialized memory, heap buffer overruns, memory leaks, and other errors that
can be difficult or impossible to find by eyeballing the code, or by static
analysis tools.  But that comes with a price, which in some cases can be quite steep, and some new
tools promise to provide some or all of the functionality valgrind provides without the drawbacks.

<!--more-->

For one thing, valgrind can
be *extremely* slow.  That is an unavoidable side-effect of one of valgrind's
strengths, which is that it doesn't require that the program under test be
instrumented beforehand -- it can analyze any executable (including shared
objects) "right out of the box".  That works because valgrind effectively
emulates the hardware the program runs on, but that leads to a potential
problem: valgrind instruments *all* the code, including shared objects --and
that includes third-party code (e.g., libraries, etc.) that you may not have any
control over.

In my case, that ended up being a real problem.  The main reason
being that a significant portion of the application I work with is hosted in a
JVM (because it runs in-proc to a Java-based FIX engine, using a thin JNI
layer).  The valgrind folks say that the slowdown using their tool can be up to
20x, but it seemed like more, because the entire JVM was being emulated.

And, because valgrind emulates *everything*, it also detects and reports
problems in the JVM itself.  Well, it turns out that the JVM plays a lot of
tricks that valgrind doesn't like, and the result is a flood of complaints that
overwhelm any potential issues in the application itself.

So, I was very interested in learning about a similar technology that promised
to address some of these problems.  Address Sanitizer (Asan from here on) was
originally developed as part of the clang project, and largely by folks at Google.
They took a different approach: while valgrind emulates the machine at run-time, Asan works by instrumenting
the code at compile-time.

That helps to solve the two big problems that I was having with valgrind: its
slowness, and the difficulty of excluding third-party libraries from the
analysis.

Asan with clang
---------------

Since I was already building the application using clang for its excellent
diagnostics and static analysis features, I thought it would be relatively
straightforward to introduce the Asan feature into the build.  Turns out there
is a bump in that road: clang's version of Asan is supplied only as a
static library that is linked into the main executable.  And while it should be
possible to re-jigger things to make it work as a shared library, that would
turn into a bit of science project.  That, and the fact that the wiki page discussing it
(http://code.google.com/p/address-sanitizer/wiki/AsanAsDso) didn't sound
particularly encouraging ("however the devil is in the detail" -- uhh, thanks, no).

Rats!  However, the wiki page
did mention that there was a version of Asan that worked with gcc, and that
version apparently did support deployment as a shared object.  So, I decided to give that a try...

Asan with gcc
-------------

It turns out that the gcc developers haven't been sitting still -- in
fact, it looks like there is a bit of a healthy rivalry between the clang and gcc
folks, and that's a good thing for you and me.  Starting with version 4.8 of the
gcc collection, Asan is available with gcc as well.[^2]

Getting the latest gcc version (4.8.2 as of this writing), building and
installing it was relatively straight-forward.  By default, the source build
installs into /usr/local, so it can co-exist nicely with the native gcc for the
platform (in the case of Red Hat/CentOS 6.5, that is the relatively ancient gcc
4.4 branch).

Building with Asan
-------------
Including support for Asan in your build is pretty simple -- just include the "-fsanitize=address"
flag in both the compile and build step.  (Note that this means you need to invoke the linker via the compiler
driver, rather than directly.  In practice, this means that the executable you specify for the link step should be 
"g++" (or "gcc"), not "ld").  

While not strictly required, it's also a very good idea to include the "-fno-omit-frame-pointer" flag
in the compile step.  This will prevent the compiler from optimizing away the frame pointer (ebp) register.  While
disabling any optimization might seem like a bad idea, in this case the performance benefit is minimal at best[^5], but the 
inability to get accurate stack frames is a show-stopper.

Running with Asan
-------------
If you're checking an executable that you build yourself, the prior steps are all you need -- libasan.so will get linked
into your executable by virtue of the "-fsanitize=address" flag.

In my case, though, the goal was to be able to instrument code running in the JVM.  In this case, I had to force libasan.so
into the executable at runtime, using LD_PRELOAD like so:

`LD_PRELOAD=libasan.so java ...`

And that's it!

Tailoring Asan
---------------

There are a bunch of options available to tailor the way Asan works: at compile-time you can supply a "blacklist" of functions that
Asan should NOT instrument, and at run-time you can further customize Asan using the ASAN_OPTIONS environment variable, which
is discussed [here](<http://code.google.com/p/address-sanitizer/wiki/Flags>).
 
By default, Asan is silent, so you may not be certain that it's actually working unless it aborts with an error, which would look like 
[this](<http://code.google.com/p/address-sanitizer/wiki/ExampleUseAfterFree>).  You can check that Asan is linked in to your executable
using ldd:

ldd a.out


You can also up the default verbosity level of Asan to get an idea of what is going on at run-time:

`export ASAN_OPTIONS="verbosity=1:..."`


If you're using LD_PRELOAD to inject Asan into an executable that was not built
using Asan, you may see output that looks like the following:

<pre>
==25140== AddressSanitizer: failed to intercept 'memset'
==25140== AddressSanitizer: failed to intercept 'strcat'
==25140== AddressSanitizer: failed to intercept 'strchr'
==25140== AddressSanitizer: failed to intercept 'strcmp'
==25140== AddressSanitizer: failed to intercept 'strcpy'
==25140== AddressSanitizer: failed to intercept 'strlen'
==25140== AddressSanitizer: failed to intercept 'strncmp'
==25140== AddressSanitizer: failed to intercept 'strncpy'
==25140== AddressSanitizer: failed to intercept 'pthread_create'
==25140== AddressSanitizer: libc interceptors initialized
</pre>

Don't worry -- it turns out that is a bogus warning related to running Asan as a shared object.  Unfortunately, the Asan
developers don't seem to want to fix this (http://gcc.gnu.org/bugzilla/show_bug.cgi?id=58680).    

Conclusion
----------

So, how did this all turn out?  Well, it's pretty early in the process, but Asan
has already caught a memory corruption problem that would have been extremely
difficult to track down otherwise.  (Short version is that due to some
unintended name collissions between shared libraries, we were trying to put 10
pounds of bologna in a 5 pound sack.  Or, as one of my colleagues more accurately pointed out, 8 pounds
of bologna in a 4 pund sack :-)

valgrind is still an extremely valuable tool, especially because of its
convenience and versatility; but in certain edge cases Asan can bring things to
the table, like speed and selectivity, that make it the better choice.

Postscript 
-----------

Before closing there are a few more things I want to mention about Asan in
comparison to valgrind:

-   If you look at the processes using Asan with top, etc. you may be a bit
    shocked at first to see they are using 4TB (or more) of memory.  Relax --
    it's not real memory, it's virtual memory (i.e., address space).  The
    algorithm used by Asan to track memory "shadows" actual memory (one bit for
    every byte), so it needs that whole address space.  Actual memory use is
    greater with Asan as well, but not nearly as bad as it appears at first
    glance.  Even so, Asan disables core files by default, at least in 64-bit
    mode.

-   As hoped, Asan is way faster than valgrind, especially in my "worst-case"
    scenario with the JVM, since the only code that's paying the price of
    tracking memory accesses is the code that is deliberately instrumented.
    That also eliminates false positives from the JVM, which is a very good
    thing.

-   As for false positives, the Asan folks apparently don't believe in them,
    because there is no "suppression" mechanism like there is in valgrind.
    Instead, the Asan folks ask that if you find what you think is a false
    positive, you file a bug report with them.  In fact, when Asan finds a
    memory error it immediately aborts -- the rationale being that allowing Asan
    to continue after a memory error would be much more work, and would make
    Asan much slower.  Let's hope they're right about the absence of false
    positives, but even so this "feature" is bound to make the debug cycle
    longer, so there are probably cases where valgrind is a better choice -- at
    least for initial debugging.
    
-   Asan and valgrind have slightly different capabilities, too:

    -   Asan can find stack corruption errors, while valgrind only tracks heap
        allocations.

    -   Both valgrind and Asan can detect memory leaks (although Asan's leak
        checking support is "still experimental" - see
        <http://code.google.com/p/address-sanitizer/wiki/LeakSanitizer>).

    -   valgrind also detects reads of un-initialized memory, which Asan does
        not.

        -   The related [Memory Sanitizer](https://code.google.com/p/memory-sanitizer/wiki/MemorySanitizer)
            tool apparently can do that.  It has an additional restriction that
            the main program must be built with -fpie to enable
            position-independent code, which may make it difficult to use in
            certain cases, e.g. for debugging code hosted in a JVM.

A detailed comparison of Asan, valgrind and other tools can be found [here](<http://code.google.com/p/address-sanitizer/wiki/ComparisonOfMemoryTools>).


Resources
--------------------

<http://en.wikipedia.org/wiki/AddressSanitizer>

<http://gcc.gnu.org/bugzilla/show_bug.cgi?id=58680>



[^3]: In this paper, I use the term valgrind, but I really mean valgrind with the memcheck tool.  valgrind includes a bunch of other tools as well -- see <http://valgrind.org> for details.

[^2]: As is another tool, the Thread Sanitizer, which detects data races between threads at run-time.  More on that in an upcoming post.

[^5]: Omitting the frame pointer makes another register (ebp) available to the compiler, but since there are already at least a dozen other registers for the compiler to use, this extra register is unlikely to be critical.  The compiler can also omit the code that saves and restores the register, but that's a couple of instructions moving data between registers and L1 cache. 

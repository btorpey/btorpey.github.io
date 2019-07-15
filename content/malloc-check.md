{% img right /images/memory-testing.jpg %}

At my day job, I spend a fair amount of time working on software reliability.  One way to make software more reliable is to use memory-checking tools like valgrind's [memcheck](http://www.valgrind.org/info/tools.html#memcheck) and clang's [AddressSanitizer](https://github.com/google/sanitizers/wiki/AddressSanitizer) to detect memory errors at runtime.  

But these tools are typically not appropriate to use all the time -- valgrind causes programs to run much more slowly than normal, and AddressSanitizer needs a special instrumented build of the code to work properly.  So neither tool is typically well-suited for production code.

But there's another memory-checking tool that is "always on".  That tool is plain old `malloc`, and it is the subject of this article.

<!-- more -->

The [GNU C library](https://www.gnu.org/software/libc/) (glibc for short) provides implementations for the C standard library functions (e.g., `strlen` etc.) including functions that interface to the underlying OS (e.g., `open` et al.).  glibc also provides functions to manage memory, including `malloc`, `free` and their cousins, and in most code these memory management functions are among the most heavily used.

It's not possible to be a C programmer and not be reasonably familiar with the memory management functions in glibc.  But what is not so well-known is the memory-checking functionality built into the library.

It turns out that glibc contains two separate sets of memory management functions -- the core functions do minimal checking, and are significantly faster than the "debug" functions, which provide additional runtime checks.

The memory checking in `malloc` is controlled by an environment variable, named appropriately enough `MALLOC_CHECK_` (note the trailing underscore).  You can configure `malloc` to perform additional checking, and whether to print an error message and/or abort with a core file if it detects an error.  You can find full details at <http://man7.org/linux/man-pages/man3/mallopt.3.html>, but here's the short version:

Value | Impl | Checking | Message | Backtrace + mappings (since glibc 2.4+) | Abort w/core
------| ---- | -------- | ------ | ------ | ------
**default (unset)** | **Fast** | **Minimal** | **Detailed** | **Yes** | **Yes**
0 | Fast | Minimal | None |  No | No
1 | Slow | Full | Detailed | No | No
2 | Slow | Full | None | No | Yes
3 | Slow | Full | Detailed | Yes | Yes
5 | Slow | Full | Brief | No | Yes
7 | Slow | Full | Brief | Yes | Yes


What may be surprising is that the default behavior is for `malloc` to do at least minimal checking at runtime, and to **abort the executable with a core file** if those checks fail.  

This may or may not be what you want.  Given that the minimal checks in the fast implementation only detect certain specific errors, and that those errors (e.g., double free) tend not to cause additional problems, you may decide that a "no harm, no foul" approach is more appropriate (for example with production code where aborting with a core file is frowned upon ;-).

The other relevant point here is that setting `MALLOC_CHECK_` to any non-zero value causes `malloc` to use the slower heap functions that perform additional checks.  I've included a [sample benchmark program](https://github.com/WallStProg/malloc-check/blob/master/malloc-bench.cpp) that shows the additional checking adds about 30% to the overhead of the `malloc`/`free` calls.  (And while the benchmark program is dumb as dirt, its results are similar to results on "real-world" tests).

It would be nice if one could get a fast implementation with the option to output an error message and continue execution, but with the current[^rh7] implementation of glibc that doesn't appear to be possible.  If you want the fast implementation but you don't want to abort on errors, the only option is to turn off checking entirely (by explicitly setting `MALLOC_CHECK_` to 0).  

[^rh7]: Current for RedHat/CentOS 7 in any case, which is glibc 2.17.

Note also that the [documentation](http://man7.org/linux/man-pages/man3/mallopt.3.html) is a bit misleading:

> Since glibc 2.3.4, the default value for the M_CHECK_ACTION              parameter is 3.

While it's true that with no value specified for `MALLOC_CHECK_` an error will cause a detailed error message with backtrace and mappings to be output, along with an abort with core file, that is **NOT** the same as explicitly setting `MALLOC_CHECK_=3` -- that setting also causes `malloc` to use the slower functions that perform additional checks.

### "Minimal" vs. "Full" Checking

- In the table above, the "checking" setting for `MALLOC_CHECK_=0` is "minimal" -- the checks are still performed, but errors are simply not reported.
  - Note that it is not possible to completely disable checking -- minimal checking is *always* performed, even if the results are ignored. 
- The errors that can be detected with "minimal" checking are limited to a small subset of those detected with "full" checking -- sometimes even for the same error.  For instance, with minimal checking a double-free can be detected *only* if the second free occurs immediately after the first.  With full checking the double-free is detected even if there are intervening calls to `malloc` and `free`.

And, of course, the built-in checking in glibc can't detect a *lot* of errors that can be found with more robust tools, like [valgrind](http://www.valgrind.org/) and [AddressSanitizer](https://github.com/google/sanitizers/wiki/AddressSanitizer).  Nevertheless, `MALLOC_CHECK_` can be a useful adjunct to those tools for everyday use in development.

## Conclusions
- For typical development, it's probably best to explicitly set `MALLOC_CHECK_=3`.  This provides additional checking over and above the default setting, at the cost of somewhat poorer performance.
- For production use, you may want to decide whether the benefit of minimal checking is worth the possibility of having programs abort with errors that may be benign.  If the default is not appropriate, you basically have two choices:
  - Setting `MALLOC_CHECK_=1` will allow execution to continue after an error, but will at least provide a message that can be logged[^log] to provide a warning that things are not quite right, and trigger additional troubleshooting, but at the cost of somewhat poorer performance.
  - If you can't afford to give up any performance at all, you can set `MALLOC_CHECK=0`, but any errors detected will be silently ignored.

[^log]: The error message from glibc is written directly to the console (tty device), not to `stderr`, which means that it will not be redirected.  If you need the message to appear on stderr, you will need to [set another environment variable](https://bugzilla.redhat.com/show_bug.cgi?id=1519182):
    `export LIBC_FATAL_STDERR_=1`
    
## Code
The code for this article is available [here](https://github.com/WallStProg/malloc-check.git).  There's a benchmark program, which requires [Google Benchmark](https://github.com/google/benchmark).  There are also sample programs which demonstrate a double-free error that can be caught even with minimal checking (`double-free.c`), and which cannot (`double-free2.c`), and a simple script that ties everything together.  

## Footnotes






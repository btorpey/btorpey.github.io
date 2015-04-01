{% img right /images/TheShadowComic01.jpg  222 333 %}

Pity the poor Shadow!  Even with the recent glut of super-heroes in movies, games and TV, the Shadow is nowhere to be seen.  

But I guess that's the whole point of being the Shadow.  

According to [this](http://en.wikipedia.org/wiki/The_Shadow), the Shadow had "the mysterious power to cloud men's minds, so they could not see him".  Hmmm, that sounds like more than a few bugs I've known.

Read on to learn how to get your compiler to help you find and eliminate these "shadow bugs" from your code.

<!-- more -->

Recently I was cleaning up the code for one of our test programs, and I
suddenly started getting a crash at shutdown that I hadn’t seen before. The
stack trace looked more or less like I expected (except for the SEGV, of
course), and I spent several minutes staring at the code before the light bulb
came on.

As is often the case, once the light bulb did come on, my first reaction was
“Duh!”. It was a dumb mistake, but then I started to think: if it’s such a dumb
mistake, why didn’t the compiler warn me about it? Answering that question got
me looking into the state of compiler diagnostics, and taught me a few things I
hadn’t known (or had forgotten).

First, let’s take a look at the bug that was a bit of a head-scratcher, and that
prompted this post. I’ve distilled it down to just a few lines of code — take a
look and see if you can spot the bug:

{% include_code shadow/shadow.cpp %}

The bug is in C's constructor, where instead of initializing the member variable (_pD), the
code instead creates a local variable with the same name. The local variable goes
out of scope on return and gets deleted (although the allocation
persists), but the member variable of the same name remains uninitialized. The
problem comes when we delete c, since C’s dtor deletes a pointer that is just a
bunch of random bits[^4]. The fix, of course, is to omit the type declaration on the
assignment, which causes the compiler to assign to the member variable, rather
than creating and then assigning to a local (stack) variable.

(I can already hear the howls of outrage at this code -- see [^1], [^2] and [^3] for a discussion if you're so inclined).

Granted that there are ways to avoid this problem by writing the code "correctly" (perfectly?) in the
first place. But still, if it’s such a dumb mistake, why didn’t the
compiler warn about it?

That was what puzzled me, especially since I thought our “diagnostic hygiene”
was pretty good. All our code is built with “-Wall -Wextra”, which is not quite
“everything but the kitchen sink”, but close.

But when we build with those flags, the compiler is perfectly happy:
<pre>
$ clang++ -g -Wall -Wextra shadow.cpp
$
</pre>

But running -- that's another story:
<pre>
$ ./a.out
*** glibc detected *** ./a.out: free(): invalid pointer: 0x0000000000400600 ***
...
Aborted (core dumped)
$ 
</pre>

When we load the core file into the debugger, we see that the offending instruction is the delete of _pD in C's destructor:

<pre>
$ gdb a.out core.897
(gdb) bt
#0  0x0000003a86032925 in raise () from /lib64/libc.so.6
#1  0x0000003a86034105 in abort () from /lib64/libc.so.6
#2  0x0000003a86070837 in __libc_message () from /lib64/libc.so.6
#3  0x0000003a86076166 in malloc_printerr () from /lib64/libc.so.6
#4  0x0000000000400720 in C::~C (this=0x7fffe6dbdec8) at shadow.cpp:23
#5  0x00000000004006a9 in main () at shadow.cpp:37
(gdb) 
</pre>

The result above is just one of three possible results. Let's take a look at each of these in turn:

1.  You may get no message at all - the code (appears to) work fine. 

	This is the result we get if we use gcc to compile the code.  With gcc, the allocation is (presumably) being satisfied by the operating system (e.g., by calling [sbrk](http://pubs.opengroup.org/onlinepubs/007908775/xsh/brk.html)).  Typically, the OS will zero-fill any memory that it allocates as a security precaution (see [here](http://stackoverflow.com/questions/8029584/why-does-malloc-initialize-the-values-to-0-in-gcc)  and [here](http://stackoverflow.com/questions/2688466/why-mallocmemset-is-slower-than-calloc) for details).  

	So, in this case, we're deleting a nullptr, and that is perfectly kosher [according to the standard](http://en.cppreference.com/w/c/memory/free). (Why that is may be a cause for debate, but it is).[^non-null]

[^non-null]:	Another possibility is that the bits are non-NULL, but the call to free doesn't immediately crash.  Instead, it may leave the data structures used to manage the heap in an inconsistent state, in such a way that it will cause a crash later.  This is the worst possible scenario, since this problem is almost impossible to debug.  In an upcoming column we're going to look at this situation in more detail, and talk about ways to avoid it.
	

2. You may get a message similar to  `*** glibc detected *** ./a.out: free(): invalid pointer` followed by a stack trace.  
 
	This happens when glibc can detect that the pointer being freed was not previously allocated.

	The memory management functions in glibc contain runtime checks to catch error conditions.  Some of these checks are enabled in all cases (because they are relatively inexpensive), while others must be specifically enabled.[^malloc-check]  In this particular case, the code in `free` is checking to see if the address being passed in has previously been allocated using e.g. `malloc`.  If not, the code signals an error.

	This is the result we get when using clang -- with clang, the  allocation request is being satisfied from memory that was previously allocated and freed, so the bits that make up the member variable _pD have already been scribbled on (i.e., they are non-zero), but glibc can tell the address is not one that was previously allocated.

3. You may get a message similar to `Segmentation fault (core dumped)`.  
	
	In our case, C's destructor is pretty minimal -- it just deletes the \_pD member variable.  In other cases, though, C's destructor may attempt to do more complicated processing before returning, and in those cases it's quite possible that that processing will trigger a crash on its own.  (For instance, if _pD is defined as a shared_ptr as opposed to a raw pointer, you would likely see a segmentation violation in the code that manipulates the shared_ptr).

# ... the Shadow Knows
This all could have been avoided if the compiler recongized that the declaration of _pD in C's constructor
hid the member variable, and with "-Wshadow" enabled in the compile, that is exactly what happens:

<pre>
﻿$ clang++ -Wall -Wextra -Wshadow shadow.cpp
shadow.cpp:17:10: warning: declaration shadows a field of 'C' [-Wshadow]
      D* _pD = new D;
         ^
shadow.cpp:27:7: note: previous declaration is here
   D* _pD;   
      ^
1 warning generated.
$
</pre>

gcc supports the flag also, although the message is slightly different
<pre>
$ g++ -Wall -Wextra -Wshadow shadow.cpp
shadow.cpp: In constructor ‘C::C()’:
shadow.cpp:17: warning: declaration of ‘_pD’ shadows a member of 'this'
$
</pre>

While both gcc and clang support the "-Wshadow" flag, the implementations are very different.  
gcc appears to strive for completeness, and in the process produces so many warnings as to render the use 
of "-Wshadow" pretty much useless.  That was certainly Linus’ opinion when
he wrote [this](<https://lkml.org/lkml/2006/11/28/239>), and it’s hard to
disagree.

The good news is that the clang developers have come up with a much
more useful implementation of "-Wshadow", which avoids a lot of the problems
Linus talks about.  For example, on one legacy-ish code base, gcc reports over 1100 shadow
warnings vs. just three for clang.  There's a terrific explanation  [here](<http://programmers.stackexchange.com/questions/122608/clang-warning-flags-for-objective-c-development/124574#124574>)
about how the clang team decides what category a particular diagnostic should belong to.

## Third-party Libraries

But, what if we use third-party libraries in our programs?  While clang does a very good job
of filtering out "false positive" shadow warnings, they can still crop up in some libraries, including Boost.  One
possible solution is to have wrapper includes that use #pragma's to suppress (or enable) certain warnings, prior to including
the real library headers.  That is in fact the approach suggested by the Boost maintainer when someone posted 
[a bug report](<https://svn.boost.org/trac/boost/ticket/9378#comment:15>) about 
the shadow warnings in Boost.  

But, that's tedious, error-prone, inconvenient and expensive.  Is there a better way?

It turns out that there is -- both gcc and clang provide the `-isystem` compiler flag to include header files, subject to 
[special rules](<https://gcc.gnu.org/onlinedocs/cpp/System-Headers.html>) that effectively eliminate warnings, 
even in macros that are expanded at compile-time.  

Note that if you're using cmake, the way to enable `-isystem` is to use the SYSTEM flag to include_directories, like so: 
`include_directories(SYSTEM ${Boost_INCLUDE_DIRS})`

## Fixing the code
There are three types of shadow warnings, each with a different cause and potential to cause trouble.  The different types are distinguished by what follows after the "warning: declaration shadows a" message:

Type  | Explanation
------------- | -------------
local variable|These are typically the least likely to be real problems, since local variables have limited lifetimes by defintion.  Even if these warnings don't indicate a genuine problem, it is best to eliminate them  by changing one or the other variable name, if only to prevent future confusion.
field of "X"|As in the example above, these shadow warnings often point to a potential problem, given how easy it is to inadvertently include a type prefix in the statement meant to initialize the member variable, thereby declaring (and initializing) a new local variable instead. 
variable in the global namespace|This is perhaps the most dangerous of the three types, since accidentally introducing a new variable into scope can easily go unnoticed.  Everything appears to be working correctly, until at some point the newly introduced variable goes out of scope, exposing the un-initialized global variable.  
<br>

# Conclusion

I originally thought this would be a quick post about a somewhat obscure compiler warning -- maybe a 
"tidbit", but certainly nothing more than that.  But, as Tolkien said about "Lord of the Rings", "the tale grew in the telling".

Let's see what we've covered:

- What "-Wshadow" means, and why you might want to use it.
- How to selectively disable warnings, including "-Wshadow", for third-party libraries when
it creates more noise than value.
- How even seemingly trivial code can behave very differently when compiled with different compilers (e.g., gcc vs. clang).
- How to use value initialization to initialize even POD types to known (zero) values.

And that doesn't even include one of my original goals, which was to talk about compiler warnings
in general, and which ones you want to make sure you use in all your builds.  That will have to wait
for next time.

## TL;DR
- Enable "-Wshadow" in addition to whatever other compiler warnings you're using.  
  * Fix the warnings, even if they don't (appear to) matter.
- But only if you're using [clang](http://clang.llvm.org/)!
  * And if you're not using clang yet, it's time to start.
  * If you need help getting clang up and running on your system, be sure to check out [my earlier post](<http://btorpey.github.io/blog/2015/01/02/building-clang/>).



[^1]: The first point is that we should be initializing the member variable in the ctor, rather than assigning it, which would make this mistake impossible. That’s a valid point, mostly, but there are times when you can make a case for assignment being a simpler approach — for example, when you have multiple member variables, and when the order of assignment matters. Remember that member variables are initialized in the order of their declaration, not the order in which the initializers appear. Given that the order of declaration is often not obvious, it’s easy to see why one might prefer to use assignment to enforce the order of assignment in the body of the constructor.

[^2]: Another mostly valid point is that, if we are going to assign in the body of the ctor, we should at least initialize the members to some value before entering the constructor. The only defense to that is a misguided attempt to optimize out the initialization code, since we know we’re assigning to the member variable anyway. That’s arguably wrong, but not terribly so, and in any event is pretty common, at least in my experience. (OK, smarty-pants, do YOU always initialize ALL your member variables in EVERY constructor you write? Even if you're going to assign to them in the body of the constructor?  Really? Do you want your merit badge now, or at the jamboree?)

[^3]: Last but not least, we could use [value initialization](http://stackoverflow.com/a/2418195/203044) to ensure that even POD types in the class are [zero-initialized](http://en.cppreference.com/w/cpp/language/zero_initialization).

[^malloc-check]: We'll be discusing how to use glibc's error-checking in a future column.

[^4]: At least [according to the standard](http://en.cppreference.com/w/cpp/language/default_initialization).  Different implementations can, and do, behave differently. Or, as the old saying goes: "In theory, there is no difference between theory and practice.  In practice, there is".
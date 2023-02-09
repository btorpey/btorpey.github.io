{% img right /images/robot1.jpg 183 200 %}

I've recently been dipping my toes in the very deep water that is "undefined behavior" in C and C++, and the more I learn about it, the scarier it is.  

This was inspired by a rather tricky crash that I needed to track down as part of moving the code-base at my day job to more modern compilers and language standards.

<!-- more -->
<br clear="all">

Compiler writers have been getting more agressive about taking advantage of optimization opportunities presented by undefined behavior.  And, while there has been some push-back to that, it doesn't appear to have changed things much.

"Why should I care?" you may ask yourself.  "My code compiles without any warnings, so I must not have any UB".

Unfortunately, it's not that simple.  *Some* compilers warn about *some* UB, but it's hit-or-miss.  Strictly speaking, the compiler is under no obligation to warn you about your use of UB -- in fact, the compiler is under no obligation to do anything at all once your code is found to contain UB.

And even if the compiler warns about some construct, it's easy to ignore the warning, especially since any negative consequences won't be apparent until running a release build.  Why is that?  It's because the worst aspects of UB tend to get triggered in conjunction with code optimization. 

In my case, one of my former colleagues had an extreme case of "lazy programmer syndrome" combined with a dose of cleverness, which is a dangerous combination.  He needed to write code to generate C++ classes from a text definition, and one of the things the code needed to do was initialize the class members in the ctor.

Rather than generate initializers for the primitive types (non-primitive types have their ctors called by the compiler), he decided to just nuke everything with a call to `memset` -- after all, zeroes are zeroes, right?

> If it doesn't fit, force it.  If it still doesn't fit, get a bigger hammer. 

Well, not quite -- since the classes being generated were all `virtual`, the `memset` call was also nuking the vtable, causing the app to crash pretty much immediately on launch.  That might have deterred others, but not our intrepid coder, who figured out a really "clever" way to get around the problem, using a dummy ctor and placement `new`.  The code he ended up with looked more or less like this:

```c++
class BadIdea{   BadIdea(int) {}
   std::string name;    int key;   double value;public:   BadIdea();   virtual ~BadIdea() {}};BadIdea::BadIdea(){   memset((void*)this, 0, sizeof(*this));   new (this)  BadIdea(1);}
```

And guess what -- it worked!  

OK, every ctor turned into **two** calls, which caused **two** calls to all the base class ctor's (but only **ONE** call to any base class dtors on the way out -- sure hope those ctors didn't allocate memory).  But hey, the code is clever, so it must be efficient, right?  Anyway, it *worked*.

Until it didn't.  

As part of bringing this codebase up to more modern standards, I started building it with different compilers, starting with the system compiler (gcc 4.8.5) on our production OS (CentOS 7), then on to gcc 5.3.0, and clang 10.  Everything fine -- no worries.  

Then a couple of things happened -- another colleague started working with CentOS 8, whose system compiler is gcc 8.x, and I started using Ubuntu 20.04, where the system compiler is gcc 9.3.0.  All of a sudden, nothing worked, but only when built in release mode -- in debug mode, everything was fine.  No warning messages from the compiler, either[^1].

This was the first clue that UB might be the culprit, which was confirmed by running the code in the debugger and setting a breakpoint at the call to `memset`. 

> Gregory (Scotland Yard detective): “Is there any other point to which you would wish to draw my attention?”
> <br>
> Holmes: “To the curious incident of the dog in the night-time.”
<br>
> Gregory: “The dog did nothing in the night-time.”
<br>
> Holmes: “That was the curious incident.”
> 
>  \- "Silver Blaze", Arthur Conan Doyle

Of course, nothing happened.  The call to `memset` was gone -- the compiler having determined that the code was UB, and simply refused to generate any machine code for it at all.  So, there was no place for the debugger to put the breakpoint.
 
Disassembling the generated code provided additional proof that the compiler simply ignored what it rightly determined was an obviously foolish construct:
 
```
	BadIdea:: BadIdea()=> 0x00007f61b180d010 <+0>:	push   %rbp   0x00007f61b180d011 <+1>:	mov    %rsp,%rbp   0x00007f61b180d014 <+4>:	push   %r15   0x00007f61b180d016 <+6>:	push   %r14   0x00007f61b180d018 <+8>:	push   %r13   0x00007f61b180d01a <+10>:	push   %r12   0x00007f61b180d01c <+12>:	push   %rbx   0x00007f61b180d01d <+13>:	mov    %rdi,%rbx   0x00007f61b180d020 <+16>:	lea    0x28(%rbx),%r13
   ...	{		memset(this, 0, sizeof(FixMessage));		new (this) FixMessage(1);	}
```

## What is Undefined Behavior?

The definition of undefined bahvior (from the C++98 standard, ISO/IEC 14882) is:

> behavior, such as might arise upon use of an erroneous program construct orerroneous data, for which this International Standard imposes no requirements.Undefined behavior may also be expected when this International Standard omitsthe description of any explicit definition of behavior. [Note: permissible undefined behavior ranges from ignoring the situation completely with unpredictableresults, to behaving during translation or program execution in a documentedmanner characteristic of the environment (with or without the issuance of adiagnostic message), to terminating a translation or execution (with theissuance of a diagnostic message). Many erroneous program constructs do notengender undefined behavior; they are required to be diagnosed.

That's quite a mouthful, but unfortunately doesn't say much other than "if the Standard doesn't specify the behavior of a piece of code, then the behavior of that code is undefined".

Searching the standard for the word "undefined" yields 191 hits in 110 sections of the document. Some of these are not a whole lot more helpful:

>  If an argument to a function has an invalid value (such as a value outside the domain of the function, or a pointer invalid for its intended use), the behavior is undefined.

I'm not aware of any definitive, comprehensive list of UB.  

So, what are some useful definitions of UB?  Well, here's a list from the [UBSAN home page](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html):
- Array subscript out of bounds, where the bounds can be statically determined- Bitwise shifts that are out of bounds for their data type- Dereferencing misaligned or null pointers- Signed integer overflow- Conversion to, from, or between floating-point types which would overflow the destination

Some instances of undefined behavior can be rather surprising -- for instance, access to unaligned data (through a pointer), is strictly speaking undefined.  Never mind that the x86 processor is perfectly capable of accessing misaligned data, and in fact [does so with little or no penalty](https://lemire.me/blog/2012/05/31/data-alignment-for-speed-myth-or-reality/) -- according to the Standard it is still UB, and the compiler is free to do pretty much anything it wants with the code (including silently ignoring it).

So, for instance, typical deserialization code like this won't necessarily do what you think:

```c
    char* buf;
    ...
    int value = *((int*) buf);
```

## Why is UB bad?

Most people would consider it A Bad Thing if the compiler took the source code they wrote and just decided to generate machine code that had nothing to do with the source code.  But that is exactly what the Standard allows -- at least according to compiler writers.  And compiler writers take advantage of that to implement optimizations that can completely change the meaning of the original source code -- a good example can be found [here](https://blog.llvm.org/2011/05/what-every-c-programmer-should-know_14.html).

There is starting to be some push-back on the "UB allows anything at all" approach, for instance [this paper](https://www.yodaiken.com/2021/10/06/plos-2021-paper-how-iso-c-became-unusable-for-operating-system-development/) from one of the members of the ISO C Standard Committee.  But, for now at least, compiler writers apparently feel free to get creative in the presence of UB.

Probably the worst thing about UB, though, is the part that I discuss at the beginning of this article -- UB can harmlessly exist in code for years until "something" changes that triggers it.  That "something" could be something "big", like a new compiler, but it could also be something "small", like a minor change to the source code that just happens to trigger an optimization that the compiler wasn't using previously.

## What to do about UB

Interestingly, searching online for the `class-memaccess` compiler warning (sometimes) associated with the `memset` call in the original example returns a bunch of results where project maintainers simple disabled the warning (`-Wno-class-memaccess`).

This is probably not what you want.

Ideally, you would eliminate all instances of potential UB from your code, since whether it "works" today is no guarantee that it will behave similarly in the future.  But first, you have to find them, and that's the tricky bit.

## Detecting Undefined Behavior

Detecting UB would seem to be a real [Catch-22](https://en.wikipedia.org/wiki/Catch-22_(logic)), since the compiler isn't required to tell you about UB, but on the other hand is allowed to do whatever it wants with it.

The other problem with detecting UB is that it is often, but not always, detectable only at runtime.

The good news is that the clang folks have created a ["sanitizer" expressly for UB](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html).  

If you've used [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html) or any of clang's other sanitizers, using UBSAN is basically straightforward.  A couple of points that may be helpful:

- Typical instances of UB are only detectable at runtime, which means the code that triggers UB must be executed.  
- Because compilers can (and do) optimize away UB-triggering code, it is best to compile with optimization disabled (`-O0`).  UBSAN can't detect UB in code that doesn't exist.
- Some helper scripts for UBSAN, ASAN, etc. can be found [here](https://github.com/nyfix/memleaktest/wiki).  These are the scripts that I use to do my testing, and my employer has graciously agreed to release these as open source.   

## More About Undefined Behavior

A lot of really smart people have been writing about UB for a while now -- this article just scratches the surface of the topic:

["What Every C Programmer Should Know About Undefined Behavior"](https://blog.llvm.org/2011/05/what-every-c-programmer-should-know.html) , Chris Lattner

["A Guide to Undefined Behavior in C and C++"](https://blog.regehr.org/archives/213) , John Regehr

["Schrödinger's Code, Undefined behavior in theory and practice"](https://queue.acm.org/detail.cfm?id=3468263) , Terence Kelly

["Undefined behavior can result in time travel"](https://devblogs.microsoft.com/oldnewthing/20140627-00/?p=633) , Raymond Chen


["Garbage In, Garbage Out: Arguing about Undefined Behavior"](https://www.youtube.com/watch?v=yG1OZ69H_-o) , Chandler Carruth

["How ISO C became unusable for operating systems development"](https://www.yodaiken.com/2021/10/06/plos-2021-paper-how-iso-c-became-unusable-for-operating-system-development/) , Victor Yodaiken

## A short digression on disassembling code

There are several ways to get an assembler listing of C++ source code, with varying degrees of usefulness.

- By far the best, in my opinion, is the listing produced by `gdb`, which is the example used above.  `gdb` does a great job of marrying up generated code with source file lines, which makes it much easier for people who are not expert in x86 machine code (me!) to see what is happening.  Just set a breakpoint at or near the code you want to see and enter
 `disas /m`  

- Next best is `objdump`, which does an OK job, but is not nearly as nice as `gdb`. Use it like so:
    `objdump -drwCl -Mintel <file>`

- The least useful format is the intermediate assembler file produced as part of the compilation process.  With gcc, you can generate an assembler listing with the `-S -fverbose-asm` compiler flags.  (If you're using `cmake`, specify `-save-temps` instead of `-S`).  This will create `.s` files with assembler listings alongside the `.o` files in your build directory.

<hr>

[^1]: It turns out that the cast to `void*` disables the warning message that the compiler would otherwise give on this code.
{% img left /images/vandergraaf.jpg 139 122 %}

- Will be replaced with the ToC, excluding the "Contents" header
{:toc}

A while back I wrote [an article](/blog/2016/04/07/mo-static/) that compared cppcheck and clang's static analyzers (clang-check and clang-tidy).  The folks who make [PVS-Studio](http://www.viva64.com/en/pvs-studio/) (the guys with the unicorn mascot that you've probably been seeing a lot of lately) saw the article, and suggested that I take a look at their Linux port, which was then in beta test, and write about it.

So I did.  Read on for an overview of PVS-Studio, and how it compared to [cppcheck](http://cppcheck.sourceforge.net/).

<!-- more -->

In [the earlier article](/blog/2016/04/07/mo-static/), I used a [benchmark suite](https://github.com/regehr/itc-benchmarks) developed by Toyota ITC, and written about by [John Regehr](http://blog.regehr.org/archives/1217), who is a professor of Computer Science at the University of Utah.  The ITC suite consists of code that is specially written to exhibit certain errors that can be detected by static analysis, so that the code can be used to evaluate the performance of different tools.

In this article, I am going to use the same test suite to compare PVS-Studio with cppcheck.  I'll also talk about my experience using both tools to analyze two relatively large real-world codebases that I help maintain as part of my day job.

## TL;DR
Using any static analysis tool is better than using none, and in general the more the merrier.  Each tool has its own design philosophy, and corresponding strengths and weaknesses.

Daniel Marjamäki[^daniel] and the maintainers of [cppcheck](http://cppcheck.sourceforge.net/) have done a terrific job creating a free tool that can go head-to-head with expensive commercial offerings.  You can't go wrong with cppcheck, either as a gentle introduction to static analysis, or as the one-and-only tool for the budget-conscious.  But don't take my word for it -- the Debian project uses cppcheck as part of its [Debian Automated Code Analysis](https://qa.debian.org/daca/) project to check over 100GB of C++ source code.

[^daniel]: Daniel was recently interviewed on [CppCast](http://cppcast.com/2016/11/daniel-marjamaki/). 

[PVS-Studio](http://www.viva64.com/en/pvs-studio/) is also a terrific tool, but it is definitely _not_ free.  (When a product [doesn't have published prices](http://www.viva64.com/en/order/), you know it's going to cost serious money).

Whether PVS-Studio is worth the price is a judgement call, but if it can find just one bug that would have triggered a crash in production it will have paid for itself many times over. 

And while PVS-Studio doesn't appear to have been adopted by a high-profile project like Debian, the folks who make it are certainly not shy about running various open-source projects through their tool and [reporting the results](http://www.viva64.com/en/inspections/).  

So, if your budget can handle it, use both.  If money is a concern, then you may want to start out with cppcheck and use that to help build a case for spending the additional coin that it will take to include commercial tools like PVS-Studio in your toolbox.

Note also that PVS-Studio offers a trial version, so you can give it a go on your own code, which is, after all, the best way to see what the tool can do.  And, if you use the provided [helper scripts](/pages/REAME.md/index.html) ([repo here](https://github.com/btorpey/static)), your results will be in a format that makes it easy to compare the tools.

## Methodology
In comparing cppcheck and PVS-Studio, I used the ITC test suite that I wrote about in an [earlier article](/blog/2016/04/07/mo-static/).  I also used both tools to analyze real-world code bases which I deal with on a day-to-day basis and that I am intimately familiar with.

### ITC test suite
The ITC test suite that I've been using to compare static analyzers is intended to provide a common set of source files that can be used as input to various static analysis tools.  It includes both real errors, as well as "false positives" intended to trick the tools into flagging legitimate code as an error.

So far, so good, and it's certainly very helpful to know where the errors are (and are not) when evaluating a static analysis tool.  

#### Caveats
In my email discussion with Andrey Karpov of PVS, he made the point that not all bugs are equal, and that a "checklist" approach to comparing static analyzers may not be the best.  I agree, but being able to compare analyzers on the same code-base can be very helpful, not least for getting a feel for how the tools work.

Your mileage can, and will, vary, so it makes sense to get comfortable with different tools and learn what each does best.  And there's no substitute for running the tools on your own code.  (The [helper scripts](/pages/REAME.md/index.html) ([repo here](https://github.com/btorpey/static)) may, well, help).

##### Specific issues 
The ITC test suite includes some tests for certain categories of errors that are more likely to manifest themselves at run-time, as opposed to compile-time.    

For instance, the ITC suite includes a relatively large number of test cases designed to expose memory-related problems.  These include problems like leaks, double-free's, dangling pointers, etc.

That's all very nice, but in the real world memory errors are often not that clear-cut, and depend on the dynamic behavior of the program at run-time.  Both valgrind's [memcheck](http://valgrind.org/info/tools.html#memcheck) and clang's [Address Sanitizer](http://clang.llvm.org/docs/AddressSanitizer.html) do an excellent job of detecting memory errors at run-time, and I use both regularly.

But run-time analyzers can only analyze code that actually runs, and memory errors can hide for quite a long time in code that is rarely executed (e.g., error & exception handlers). So, even though not all memory errors can be caught at compile-time, the ability to detect at least some of them can very helpful.  

A similar situation exists with regard to concurrency (threading) errors -- though in this case neither tool detects *any* of the concurrency-related errors seeded in the ITC code.  This is, I think, a reasonable design decision  -- the subset of threading errors that can be detected at compile-time is so small that it's not really worth doing (and could give users of the tool a false sense of security).  For concurrency errors, you again will probably be better off with something like clang's [Thread Sanitizer](http://clang.llvm.org/docs/ThreadSanitizer.html) or valgrind's [Data Race Detector](http://valgrind.org/info/tools.html#drd).

Also, in the interest of full disclosure, I have spot-checked some of the ITC code, but by no means all, to assure myself that its diagnostics were reasonable. 

With those caveats out of the way, though, the ITC test suite does provide at least a good starting point towards a comprehensive set of test cases that can be used to exercise different static analyzers.

## Real-world test results
I also ran both cppcheck and PVS-Studio on the code bases that I maintain as part of my day job, to get an idea of how the tools compare in more of a real-world situation.  While I can't share the detailed comparisons, following are some of the major points.

For the most part, both cppcheck and PVS-Studio reported similar warnings on the same code, with a few exceptions (listed following). 

cppcheck arguably does a better job of flagging "style" issues -- and while some of these warnings are perhaps a bit nit-picky, many are not:

- one-argument ctor's not marked `explicit` 
- functions that can/should be declared `static` or `const`
- use of post-increment on non-primitive types 
- use of obsolete or deprecated functions
- use of C-style casts

PVS-Studio, on the other hand, appears to include more checks for issues that aren't necessarily problems with the use of C++ per se, but things that would be a bug, or at least a "code smell", in any language.

A good example of that is PVS-Studio's warning on similar or identical code sequences (potentially indicating use of the copy-paste anti-pattern -- I've written about that [before](/blog/2014/09/21/repent/)).

Some other PVS-Studio "exclusives" include: 

- classes that define a copy ctor without `operator=`, and vice-versa
- potential floating-point problems[^float], e.g., comparing floating-point values for an exact match using `==`
- empty `catch` clauses
- catching exceptions by value rather than by reference

Both tools did a good job of identifying potentially suspect code, as well as areas where the code could be improved.

[^float]: See [here](http://blog.reverberate.org/2014/09/what-every-computer-programmer-should.html) and [here](http://floating-point-gui.de/) for an explanation of how floating-point arithmetic can produce unexpected results if you're not careful.

## False positives
False positives (warnings on code that is actually correct) are not really a problem with either cppcheck or PVS-Studio.  The few warnings that could be classified as false positives indicate code that is at the very least suspect -- in most cases you're going to want to change the code anyway, if only to make it clearer.

If you still get more false positives than you can comfortably deal with, or if you want to stick with a particular construct even though it may be suspect, both tools have mechanisms to suppress individual warnings, or whole classes of errors.  Both tools are also able to silence warnings either globally, or down to the individual line of code, based on inline comments.

## Conclusion
If you care about building robust, reliable code in C++ then you would be well-rewarded to include static analysis as part of your development work-flow.  

Both [PVS-Studio](http://www.viva64.com/en/pvs-studio/) and [cppcheck](http://cppcheck.sourceforge.net/) do an excellent job of identifying potential problems in your code.  It's almost like having another set of eyeballs to do code review, but with the patience to trace through all the possible control paths, and with a voluminous knowledge of the language, particularly the edge cases and "tricky bits".

Having said that, I want to be clear that static analysis is not a substitute for the dynamic analsyis provided by tools like valgrind's [memcheck](http://valgrind.org/info/tools.html#memcheck) and [Data Race Detector](http://valgrind.org/info/tools.html#drd), or clang's [Address Sanitizer](http://clang.llvm.org/docs/AddressSanitizer.html) and [Thread Sanitizer](http://clang.llvm.org/docs/ThreadSanitizer.html).  You'll want to use them too, as there are certain classes of bugs that can only be detected at run-time.

I hope you've found this information helpful.  If you have, you may want to check out some of my earlier articles, including:

- [Mo' Static](/blog/2016/04/07/mo-static/)
- [Static Analysis with clang](/blog/2015/04/27/static-analysis-with-clang/)
- [Using clang's Address Sanitizer](/blog/2014/03/27/using-clangs-address-sanitizer/)
- [Who Knows what Evil Lurks...](/blog/2015/03/17/shadow/)

Last but not least, please feel free to [contact me](<mailto:wallstprog@gmail.com>) directly, or post a comment below, if you have questions or something to add to the discussion.

## Appendix: Helper scripts and sample results

I've posted the [helper scripts](/pages/REAME.md/index.html) I used to run PVS-Studio, as well as the results of running those scripts on the ITC code, in the [repo](https://github.com/btorpey/static).

## Appendix: Detailed test results

The following sections describe a subset of the tests in the ITC code and how both tools respond to them.

### Bit Shift errors
{:.no_toc}
For the most part, PVS-Studio and cpphceck both do a good job of detecting errors related to bit shifts. Neither tool detects all the errors seeded in the benchmark code, although they miss different errors.

### Buffer overrun/underrun errors
{:.no_toc}
cppcheck appears to do a more complete job than PVS-Studio of detecting buffer overrrun and underrun errors, although it is sometimes a bit "off" -- reporting errors on lines that are in the vicinity of the actual error, rather than on the actual line.  cppcheck also reports calls to functions that generate buffer errors, which is arguably redundant, but does no harm.

PVS-Studio catches some of the seeded errors, but misses several that cppcheck detects.

While not stricly speaking an overrun error, cppcheck can also detect some errors where code overwrites the last byte in a null-terminated string.

### Conflicting/redundant conditions
{:.no_toc}
Both cppcheck and PVS-Studio do a good job of detecting conditionals that always evaluate to either true or false, with PVS-Studio being a bit better at detecting complicated conditions composed of contstants.

On the other hand, cppcheck flags redundant conditions (e.g., `if (i<5 && i<10)`), which PVS-Studio doesn't do. 

### Loss of integer precision
{:.no_toc}
Surprisingly, neither tool does a particularly good job of detecting loss of integer precision (the proverbial "ten pounds of bologna in a five-pound sack" problem ;-)

#### Assignments
{:.no_toc}
I say surprisingly because these kinds of errors would seem to be relatively easy to detect.  Where both tools seem to fall short is to assume that just because a value fits in the target data type, the assignment is valid -- but they fail to take into account that such an assignment can lose precision.

I wanted to convince myself that the ITC code was correct, so I pasted some of the code into a small test program:

{% include_code static/pvs/test1.c %}

When you run this program, you'll get the following output:

    $ gcc test1.c && ./a.out
    Value of sink=0

What is happening here is that the value 0x80 would fit in an *unsigned* char, but because the high-order bit is dedicated to the sign bit, the maximum value that can be represented in a signed char is 127.  So, the result of the assignment is zero, which is very likely not what would have been intended by the programmer.

#### Arithmetic expressions
{:.no_toc}
cppcheck does do a slightly better job of detecting integer overflow and underflow in arithmetic expressions compared to PVS, but still misses a number of seeded errors.

#### Divide by zero
{:.no_toc}
Both PVS-Studio and cppcheck do a good job of catching potential divide-by-zero errors, with cppcheck having a slight edge. 

### Dead code
{:.no_toc}
PVS-Studio tends to do a somewhat better job than cppcheck at detecting various types of dead code, such as `for` loops and `if` statements where the condition will never be true.

PVS-Studio also very helpfully flags any unconditional `break` statements in a loop -- these are almost always going to be a mistake.

### Concurrency
{:.no_toc}
As mentioned above, neither tool detects *any* of the concurrency-related errors seeded in the ITC code.  Again, I regard that as a reasonable design choice, given the relatively small percentage of such errors that can be detected at compile-time.

### Memory Errors
{:.no_toc}
As discussed earlier, not all memory errors can be detected at compile-time, so the lack of any error output certainly doesn't mean that the code doesn't have memory errors -- it just means that they can't be detected by the tools. But while may memory errors cannot be detected at compile-time, for those that can be, detecting them is a big win.

#### Double free
{:.no_toc}
cppcheck does an excellent job of detecting double-free errors (11 out of 12), while PVS-Studio only flags one of the seeded errors.

#### Free-ing non-allocated memory
{:.no_toc}
On the other hand, PVS-Studio does a better job of detecting attempts to free memory that was not allocated dynamically (e.g., local variables).  

#### Freeing a NULL pointer
{:.no_toc}
Neither tool does a particularly good job of catching these.  Perhaps that is because freeing a NULL pointer is actually not an error, but doing so is certainly a clue that the code may have other problems.

#### Dangling pointers
{:.no_toc}
cppcheck does a somewhat better job of detecting the use of dangling pointers (where the pointed-to object has already been freed).

#### Allocation failures
{:.no_toc}
If you're writing code for an embedded system, then checking for and handling allocation failures can be important, because your application is likely written to expect them, and do something about them.  But more commonly, running out of memory simply means that you're screwed, and attempting to deal with the problem is unlikely to make things better.

Neither tool detects code that doesn't handle allocation failures, but cppcheck does flag some allocation-related problems (as leaks, which is not correct, but it is a clue that there is a problem lurking).

#### Memory Leaks
{:.no_toc}
Typically, memory leaks are only evident at run-time, but there are some cases where they can be detected at compile-time, and in those cases cppcheck does a pretty good job. 

#### Null pointer
{:.no_toc}
Both PVS-Studio and cppcheck do a good job of flagging code that dereferences a NULL pointer, although neither tool catches all the errors in the benchmark code.

#### Returning a pointer to a local variable
{:.no_toc}
Both PVS-Studio and cppcheck detect returning a pointer to a local variable that is allocated on the stack.

#### Accessing un-initialized memory
{:.no_toc}
PVS-Studio does a somewhat better job than cppcheck of flagging accesses to uninitialized memory.

### Infinite loops
{:.no_toc}
Both cppcheck and PVS-Studio detect some infinite loop errors, but miss several others.  It could be that this is by design, since the code that is not flagged tends to resemble some idioms (e.g., ` while (true)`) that are often used deliberately.  

### Ignored return values
{:.no_toc}
PVS-Studio is quite clever here -- it will complain about an unused return value from a function, *if* it can determine that the function has no side effects.  It also knows about some common STL functions that do not have side effects, and will warn if their return values are ignored.

cppcheck doesn't check for return values per se, but it will detect an assignment that is never referenced.  This makes some sense, since warning on ignored return values could result in a large number of false positives.

### Empty/short blocks
{:.no_toc}
Both tools detect certain cases of empty blocks (e.g., `if (...);` -- note the trailing semi-colon).  

What neither tool does is warn about "short" blocks -- where a conditional block is not enclosed in braces, and so it's not 100% clear whether the conditional is meant to cover more than one statement:


    if (...)
       statement1();
       statement2();

If you've adopted a convention that even single-statement blocks need to be enclosed in braces, then this situation may not pertain (and good for you!).  Still, I think this would be a worthwhile addition -- at least in the "style" category.

### Dead stores
{:.no_toc}
cppcheck does a particularly good job of detecting dead stores (where an assignment is never subsequently used).  PVS-Studio, on the other hand, flags two or more consecutive assignments to a variable, without an intervening reference.  PVS-Studio will also flag assignment of a variable to itself (which is unlikely to be what was intended).

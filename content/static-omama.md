{% img left /images/static-cat.jpg 250 188 %}

- Will be replaced with the ToC, excluding the "Contents" header
{:toc}

I've written before about [static analysis](/blog/categories/static-analysis/), but in those earlier posts I wasn't able to give specific examples of real-world code where static analysis is able to discover latent errors.

In the earlier articles I used a synthetic code-base [from ITC Research](https://github.com/regehr/itc-benchmarks) to test clang, cppcheck and PVS-Studio.  I also ran all three tools on the code-bases that I'm responsible for maintaining at my "day job", but I wasn't able to share detailed results from that analysis, given that the code is not public.

In this article, I want to continue the discussion of static analysis by diving into a real-world, open-source code base that I've been working with lately.

<!-- more -->


## OpenMAMA
For this example, I'll be using the [OpenMAMA](http://openmama.org) source code.  OpenMAMA is an open-source messaging middleware framework that provides a high-level API for a bunch of messaging transports, including open-source (Qpid/AMQP, ZeroMQ) and commercial (DataFabric, Rendezvous, Solace, etc).

OpenMAMA is an interesting project -- it started back in 2004 with Wombat Financial Software, which was attempting to sell its market-data software, but found it to be tough sledding.  While Wombat's software performed better and was less expensive than Tibco's Rendezvous (the de-facto standard at the time), no one wanted to rewrite their applications to target an API from a small company that might not be around in a couple of years.

So Wombat developed an open API which could sit on top of any messaging middleware, and they called it MAMA, for Middleware Agnostic Messaging API.  They also developed bindings for Rendezvous, in addition to their own software, so that prospective customers would have a warm and fuzzy feeling that they could write their applications once, and seamlessly switch out the underlying middleware software with little or no changes to their code.

That strategy worked well enough that in 2008 Wombat was acquired by the New York Stock Exchange, which renamed the software "Data Fabric" and used it as the backbone of their market-data network (SuperFeed).
When the company I was working for was also acquired by NYSE in 2009 I was tasked with replacing our existing middleware layer, which used Rendezvous, with the Mama/Wombat middleware.

{% pullquote %}
Well, as the saying goes: {"In theory, there's no difference between theory and practice.  In practice, there is."}  That turned out to be quite a big job, mostly resolving problems related to object lifetimes.  (Transactional messaging is very different from market-data).  But it eventually got done, and in the process I came to appreciate the "pluggable" architecture of MAMA -- it doesn't make the issues related to different messaging systems go away, but it does provide a framework for dealing with them.
{% endpullquote %}

In 2012 NYSE Technologies donated OpenMAMA to the Linux Foundation, again with the idea of using the "one API to rule them all" concept to help promote its proprietary DataFabric middleware, which was built on the MAMA API.  While I was working for NYSE Technologies, I developed the first open-source transport for OpenMAMA[^avis].

[^avis]: Which unfortunately was targeted at a rather feeble middleware solution called [Avis](http://avis.sourceforge.net/why_avis.html), so as not to compete with Data Fabric.  I argued against that decision, but I lost.  Later, Avis was replaced with [Qpid/AMQP](https://qpid.apache.org/), which for all its shortcomings is at least a reasonable choice for some applications.

In 2014, the Wombat business was sold by NYSE to [Vela Trading Technologies](https://www.velatradingtech.com/) (née SR Labs), which provides the proprietary Data Fabric middleware, and is also the primary maintainer for OpenMAMA.

Which brings us to the present day -- I've recently started working with OpenMAMA again, so it seemed like a good idea to use that code as an example of how to use static analysis tools to identify latent bugs.

And, just to be clear, this is not a criticism of OpenMAMA -- it's an impressive piece of work, and has proven itself in demanding real-world situations.  

## Following along

The analysis presented here is based on OpenMAMA release 6.2.1, which can be found [here](https://github.com/OpenMAMA/OpenMAMA/releases/tag/OpenMAMA-6.2.1-release).

I used [cppcheck version 1.80](http://cppcheck.sourceforge.net/) and [clang version 5.0.0](http://releases.llvm.org/download.html#5.0.0).

Check out the [earlier articles in this series](/blog/categories/static-analysis/) for more on building and running the various tools, including a bunch of helper scripts in the [GitHub repo](https://github.com/btorpey/static).

The results from running the tools on OpenMAMA can also be found in [the repo](https://github.com/btorpey/static/tree/master/openmama).

## False Positives
Before we do anything else, let's deal with the elephant in the room -- false positives.  As in, warning messages whining about code that is actually perfectly fine.  Apparently, a lot of people have been burned by "lint"-type programs with terrible signal-to-noise ratios.  I know -- I've been there too.

Well, let me be clear -- these are not your father's lints.  I've been running these tools on a lot of real-world code for a while now, and there are essentially  NO false positives.  If one of these tools complains about some code, there's something wrong with it, and you really want to fix it.

## Style vs. Substance
cppcheck includes a lot of "style" checks, although the term can be misleading  -- there are a number of "style" issues that can have a significant impact on quality.

One of them crops up all over the place in OpenMAMA code, and that is the "The scope of the variable '\<name>' can be reduced" messages.  The reason for these is because of OpenMAMA's insistence on K&R-style variable declarations (i.e., all block-local variables must be declared before any executable statements).  This is apparently a holdover caused by a requirement to support old and broken Microsoft compilers[^vs].

[^vs]: The list of supported platforms for OpenMAMA is [here](https://openmama.github.io/openmama_supported_platforms.html).  You can also find a lot of griping on the intertubes about Microsoft's refusal to support C99, including [this rather weak response](https://visualstudio.uservoice.com/forums/121579-visual-studio-ide/suggestions/2089423-c99-support) from Herb Sutter.  Happily, VS 2013 ended up supporting (most of) C99\. 

The consensus has come to favor declaring variables as close to first use as possible, and that is part of the [C++ Core Guidelines](https://github.com/isocpp/CppCoreGuidelines/blob/master/CppCoreGuidelines.md#es21-dont-introduce-a-variable-or-constant-before-you-need-to-use-it).  The only possible down-side to this approach is that it makes it easier to inadvertently declare "shadow" variables (i.e., variables with the same name in both inner and outer scopes), but modern compilers can flag shadow variables, which mitigates this potential problem (see my earlier article ["Who Knows What Evil Lurks..."](/blog/2015/03/17/shadow/) for more).

Some other "style" warnings produced by cppcheck include:

> \[mama/c_cpp/src/c/bridge/qpid/transport.c:1413]: (style) Consecutive return, break, continue, goto or throw statements are unnecessary.

These are mostly benign, but reflect a lack of understanding of what statements like `continue` and `return` do, and can be confusing.
<br>
<br>

> \[common/c_cpp/src/c/list.c:295 -> common/c_cpp/src/c/list.c:298]: (style) Variable 'rval' is reassigned a value before the old one has been used.

There are a lot of these in OpenMAMA, and most of them are probably caused by the unfortunate decision to standardize on K&R-style local variable declarations, but in other cases this can point to a potential logic problem.  (Another good reason to avoid K&R-style declarations).

<br>
Similar, but potentially more serious is this one:

> \[mama/c_cpp/src/c/bridge/qpid/transport.c:275]: (style) Variable 'next' is assigned a value that is never used.

Maybe the variable was used in an earlier version of the code, but is no longer needed.  Or maybe we ended up using the wrong variable when we mean to use `next`.

## Dead Code

There are also cases where the analyzer can determine that the code as written is meaningless

> \[mama/c_cpp/src/c/bridge/qpid/subscription.c:179]: (style) A pointer can not be negative so it is either pointless or an error to check if it is.

If something cannot happen, there is little point to testing for it -- so testing for impossible conditions is almost always a sign that something is wrong with the code.

Here are a few more of the same ilk:

> \[mama/c_cpp/src/c/dictionary.c:323]: (style) Checking if unsigned variable '*size' is less than zero.

<!-- -->
> \[mama/c_cpp/src/c/statslogger.c:731]: (style) Condition 'status!=MAMA_STATUS_OK' is always false

<!-- -->
> \[mama/c_cpp/src/c/dqstrategy.c:543]: (style) Redundant condition: If 'EXPR == 3', the comparison 'EXPR != 2' is always true.

Whether these warnings represent real bugs is a question that needs to be answered on a case-by-case basis, but I hope we can agree that they at the very least represent a ["code smell"](https://en.wikipedia.org/wiki/Code_smell), and the fewer of these in our code, the better.

## Buffer Overflow
There are bugs, and there are bugs, but bugs that have a "delayed reaction", are arguably the worst, partly because they can be so hard to track down.  Buffer overflows are a major cause of these kinds of bugs -- a buffer overflow can trash return addresses on the stack causing a crash, or worse they can alter the program's flow in ways that seem completely random.

Here's an example of a buffer overflow in OpenMAMA that was detected by cppcheck:

> \[common/c_cpp/src/c/strutils.c:632]: (error) Array 'version.mExtra[16]' accessed at index 16, which is out of bounds.


Here's the offending line of code:

~~~ c
    version->mExtra[VERSION_INFO_EXTRA_MAX] = '\0';

~~~


And here's the declaration:

~~~ c
    char mExtra[VERSION_INFO_EXTRA_MAX];
~~~


It turns out that this particular bug was fixed subsequent to the release -- the bug report is [here](https://github.com/OpenMAMA/OpenMAMA/pull/310).  Interestingly, the bug report mentions that the bug was found using clang's Address Sanitizer,  which means that code must have been executed to expose the bug.     Static analyzers like cppcheck can detect this bug without the need to run the code, which is a big advantage of static analysis.  In this example, cppcheck can tell at compile-time that the access is out-of-bounds, since it knows the size of mExtra.

Of course, a static analyzer like cppcheck can't detect *all* buffer overflows -- just the ones that can be evaluated at compile-time.  So, we still need Address Sanitizer, or valgrind, or some other run-time analyzer, to detect overflows that depend on the run-time behavior of the program.  But I'll take all the help I can get, and detecting at least some of these nasty bugs at compile-time is a win.

## NULL pointer dereference
In contrast to the buffer overflow type of problem, dereferencing a NULL pointer is not mysterious at all -- you're going down hard, right now.

So, reasonable programmers insert checks for NULL pointers, but reasonable is not the same as perfect, and sometimes we get it wrong.

> \[mama/c_cpp/src/c/msg.c:3619] -> [mama/c_cpp/src/c/msg.c:3617]: (warning, inconclusive) Either the condition '!impl' is redundant or there is possible null pointer dereference: impl.

Here's a snip of the code in question -- see if you can spot the problem:

~~~c
3613    mamaMsgField
3614    mamaMsgIterator_next (mamaMsgIterator iterator)
3615    {
3616        mamaMsgIteratorImpl* impl         = (mamaMsgIteratorImpl*)iterator;
3617        mamaMsgFieldImpl*    currentField = (mamaMsgFieldImpl*) impl->mCurrentField;
3618
3619        if (!impl)
3620            return (NULL);
~~~

cppcheck works similarly to other static analyzers when checking for possible NULL pointer dereference -- it looks to see if a pointer is checked for NULL, and if it is, looks for code that dereferences the pointer outside the scope of that check.

In this case, the code checks for `impl` being NULL, but not until it has already dereferenced the pointer.  cppcheck even helpfully ties together the check for NULL and the (earlier) dereference. (Ahem -- yet another reason to avoid K&R-style declarations).

## Leaks
Similarly to checking for NULL pointers, detecting leaks is more of a job for valgrind, Address Sanitizer or some other run-time analysis tool.  However, that doesn't mean that static analysis can't give us a head-start on getting rid of our leaks.

For instance, cppcheck has gotten quite clever about being able to infer run-time behavior at compile-time, as in this example:

> "mama/c_cpp/src/c/transport.c:269","(error) Memory leak: transport"
> "mama/c_cpp/src/c/transport.c:278","(error) Memory leak: transport"
Here's the code:

~~~c
253 mama_status
254 mamaTransport_allocate (mamaTransport* result)
255 {
256     transportImpl*  transport    =   NULL;
257     mama_status     status       =   MAMA_STATUS_OK;
258
259
260     transport = (transportImpl*)calloc (1, sizeof (transportImpl ) );
261     if (transport == NULL)  return MAMA_STATUS_NOMEM;
262
263     /*We need to create the throttle here as properties may be set
264      before the transport is actually created.*/
265     if (MAMA_STATUS_OK!=(status=wombatThrottle_allocate (&self->mThrottle)))
266     {
267         mama_log (MAMA_LOG_LEVEL_ERROR, "mamaTransport_allocate (): Could not"
268                   " create throttle.");
269         return status;
270     }
271
272     wombatThrottle_setRate (self->mThrottle,
273                            MAMA_DEFAULT_THROTTLE_RATE);
274
275     if (MAMA_STATUS_OK !=
276        (status = wombatThrottle_allocate (&self->mRecapThrottle)))
277     {
278         return status;
279     }
280
281     wombatThrottle_setRate (self->mRecapThrottle,
282                             MAMA_DEFAULT_RECAP_THROTTLE_RATE);
283
284     self->mDescription          = NULL;
285     self->mLoadBalanceCb        = NULL;
286     self->mLoadBalanceInitialCb = NULL;
287     self->mLoadBalanceHandle    = NULL;
288     self->mCurTransportIndex    = 0;
289     self->mDeactivateSubscriptionOnError = 1;
290     self->mGroupSizeHint        = DEFAULT_GROUP_SIZE_HINT;
291     *result = (mamaTransport)transport;
292
293     self->mName[0] = '\0';
294
295     return MAMA_STATUS_OK;
296 }
~~~

cppcheck is able to determine that the local variable `transport` is never assigned in the two early returns, and thus can never be freed.
<br>

Not to be outdone, clang-tidy is doing some kind of flow analysis that allows it to catch this one:

> "mama/c_cpp/src/c/queue.c:778","warning: Use of memory after it is freed"Here's a snip of the code that clang-tidy is complaining about:

~~~ c
651 mama_status652 mamaQueue_destroy (mamaQueue queue)653 {654     mamaQueueImpl* impl = (mamaQueueImpl*)queue;655     mama_status    status = MAMA_STATUS_OK;...776         free (impl);777778         mama_log (MAMA_LOG_LEVEL_FINEST, "Leaving mamaQueue_destroy for queue 0x%X.", queue);779         status = MAMA_STATUS_OK;780     }781782    return status;783 }
~~~
clang-tidy understands that `queue` and `impl` are aliases for the same variable, and thus knows that it is illegal to access `queue` after `impl` has been freed.  In this case, the access causes no problems, because we're only printing the address, but clang-tidy can't know that[^interproc].

[^interproc]: Unless it knows what `mama_log` does.  It turns out that clang-tidy can do inter-procedural analysis, but only within a single translation unit.  There is some work ongoing to add support for analysis across translation units by Gábor Horvath et al. -- for more see ["Cross Translational Unit Analysis in Clang Static Analyzer: Prototype and Measurements"](http://llvm.org/devmtg/2017-03//2017/02/20/accepted-sessions.html#7).


## Pointer Errors
I've <del>ranted</del> written [before](/blog/2014/09/23/into-the-void/) on how much I hate `void*`'s.  For better or worse, the core OpenMAMA code is written in C, so there are a whole bunch of casts between `void*`s and "real" pointers that have the purpose of encapsulating the internal workings of the internal objects managed by the code.

In C this is about the best that can be done, but it can be hard to keep things straight, which can be a source of errors (like this one):

> "mama/c_cpp/src/c/fielddesc.c:76","(warning) Assignment of function parameter has no effect outside the function. Did you forget dereferencing it?"And here's the code:

~~~ c
65  mama_status66  mamaFieldDescriptor_destroy (mamaFieldDescriptor descriptor)67  {68      mamaFieldDescriptorImpl* impl = (mamaFieldDescriptorImpl*) descriptor;6970      if (impl == NULL)71          return MAMA_STATUS_OK;7273      free (impl->mName);74      free (impl);7576      descriptor = NULL;77      return MAMA_STATUS_OK;78  }
~~~

Of course `mamaFieldDescriptor` is defined as a `void*`, so it's perfectly OK to set it to NULL, but since it's passed by value, the assignment has no effect other than to zero out the copy of the parameter on the stack.

## But Wait, There's More!
The preceding sections go into detail about specific examples of serious errors detected by cppcheck and clang.  But, these are very much the tip of the iceberg.

Some of the other problems detected include:

- use of non-reentrant system functions (e.g., `strtok`) in multi-threaded code;
- use of obsolete functions (e.g., `gethostbyname`);
- incorrect usage of `printf`-style functions;
- incorrect usage of `strcpy`-style functions (e.g., leaving strings without terminating NULL characters);
- incorrect usage of varargs functions;
- different parameter names in function declarations vs. definitions;

Some of these are nastier than others, but they are all legitimate problems and should be fixed.

The full results for both tools are available in the [GitHub repo](https://github.com/btorpey/static/tree/master/openmama), so it's easy to compare the warnings against the code.

## Conclusion
The state of the art in static analysis keeps advancing, thanks to people like Daniel Marjamäki and the rest of the [cppcheck team](https://github.com/danmar/cppcheck/graphs/contributors), and Gábor Horváth and the [team supporting clang](https://github.com/llvm-mirror/clang/graphs/contributors).

In particular, the latest releases of cppcheck and clang-tidy are detecting errors that previously could only be found by run-time analyzers like valgrind and Address Sanitizer.  This is great stuff, especially given how easy it is to run static analysis on your code.

The benefits of using one (or more) static analysis tools just keep getting more and more compelling -- if you aren't using one of these tools, what are you waiting for?

If you found this article interesting or helpful, you might want to check out the other posts in [this series](/blog/categories/static-analysis/).  And please leave a comment below or [drop me a line](<mailto:wallstprog@gmail.com>) with any questions, suggestions, etc.

<hr>
## Footnotes









{% img right /images/m20.jpg 385 233 %} 

I keep reading talk of the sort “I don’t know why anyone bothers
with C++ — real programmers use C.  C++ is for wussies”, or words to that
effect.

Well, a while ago I had to go back to C from working exclusively in C++ for a while, and
I have to say that I think the C fanboys are just nuts.

<!--more-->

The project I’m referring to involved packaging up NYSE’s (now SR Labs') “Mama” middleware so
it could be released as [open source](http://www.openmama.org/), as well as implementing a new transport
adapter for OpenMama using the open-source [Avis](http://avis.sourceforge.net/why_avis.html) transport[^1].

Mama is a high-level API that provides access to a number of middleware
transports, including Tibco Rendezvous, Informatica/29 West LBM and NYSE’s own
Data Fabric middleware.  Mama and Data Fabric are almost exclusively C code,
written back in the days when people avoided C++ because of issues with the
various compilers.  (Does anyone remember the fun we used to have with gcc 2.95
and templates?)

So, at the time using C may have been the right choice, but it’s far from ideal.

Like a lot of C code, what Mama does is encapsulate functionality by using
pointers to opaque structs.  These ”handles” are created by calling API
functions, and then later passed to other API functions to perform actions on
the underlying objects represented by the handles.

This is a very popular idiom, and with good reason — hiding the inner details of
the implementation insulates applications from changes in the implementation.
It’s called [“Bridge”](http://en.wikipedia.org/wiki/Bridge_pattern) by the GOF, and the more 
colorful [“pImpl”](http://www.gotw.ca/gotw/024.htm) by Herb
Sutter.

Of course, in C the typical way to accomplish this is with 
[void](http://stackoverflow.com/questions/1043034/what-does-void-mean-in-c-c-and-c)
 pointers, so the
implementation spends a lot of time casting back and forth between `void*`’s and
“real” pointers.  With, of course, absolutely no error checking by the compiler.

For example, in the Avis protocol bridge that I implemented for the initial
release of OpenMama, there are a bunch of macros that look like this:

	#define avisPublisher(publisher) ((avisPublisherBridge*) publisher)

Elsewhere, the code that uses the macro:

        mamaMsg_updateString(msg, SUBJECT_FIELD_NAME, 0, avisPublisher(publisher)->mSubject);


Gee, wouldn’t it be nice to be able to define these handles in such a way that
they would be opaque to the applications using the API, but the compiler could
still enforce type-checking?  Not to mention not having to cast back and forth
between `void*`’s and actual types?

Never mind virtual functions, forget streams (please!) and the STL, ditto templates and
operator overloading — if there’s one overriding reason to prefer C++ over C,
it’s the compiler’s support for separating interface from implementation that is
completely lacking in C.

You see this same “handle” pattern everywhere in C, and it’s “good” C code just
because it’s the best that can be done, but if a programmer wrote that code in
C++ he’d be laughed out of the building (and rightly so).

Has C++ become big and complicated?  Sure.  Is the syntax sometimes capricious
and counter-intuitive?  Absolutely.

But, at least for me, if I never see another `void*` as long as I live, that won’t
be too long for me.

[^1]: Don't ask.  Let's just say it wasn't my decision.  If you want to check out OpenMama, I would suggest using [Qpid/AMQP](http://qpid.apache.org/proton/) instead.
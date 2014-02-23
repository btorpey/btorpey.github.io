
Singleton’s are kind of like Rodney Dangerfield – they don’t get no respect. And
yet, there are scenarios where a singleton is just the ticket – for instance,
when a relatively expensive and/or long-lived resource needs to be shared among
a number of independent threads.

shared_ptr's can help make this easier and less error-prone, but even so there are some 
edge cases that need to be considered.

<!--more-->

In our case, we had a need for a singleton object to refer to a middleware
connection which was being shared across a large number of child objects, which
were in turn being manipulated on a number of different threads.

In our case, we also wanted lazy initialization (construct on first use), and to
clean up the singleton properly when the code was done using it. Since the
creation and destruction order of the using objects is not deterministic, the
obvious solution is to use reference counting to manage the singleton’s lifetime,
and the simplest way to do that is to use [shared_ptr’s](<http://www.cplusplus.com/reference/memory/shared_ptr/>).

shared_ptr’s were introduced in Boost, and were subsequently adopted by the C++
standards committee as part of the base language with the tr1 and C++0x
standards. As such, they have been widely supported (think gcc and MS compilers)
for a while now.

One of the “magic” qualities of shared_ptr’s is that all shared_ptr’s that point
to the same thing (what I’m going to refer to as a “target” from here on) share
a single reference count (hence the “shared” part of the name), so as individual
shared_ptr’s go out of scope, the reference counter on the target itself is
automatically decremented, and the target is deleted when its reference count
goes to zero.

However, as we’ll see, there are some fine points that need to be considered
even in this relatively simple case.

Our first attempt looked something like this:

{% include_code lang:cpp smart/smart1.cpp  %}


The implementation constructs the singleton into a class-static shared_ptr on
the first call to getShared(), and then hands out copies of the shared_ptr to
each caller. When run, the following output is produced:

{% include_code lang:console smart/smart1.out %}

This implementation works, but with one major caveat: as you can see from the
output, the shared_ptr’s get an initial reference count of two – one for the
creation of the singleton itself, and one for the copy of the shared_ptr that is
returned from getShared.

This means that the singleton will not actually be deleted until after returning
from main(), which is when static objects get deleted. (For more information on
why this is so, see section 3.6.3 of the C++ standard).[^2] In many cases, that
would not be a problem, but in our case the middleware connection to which the
shared_ptr’s refer gets cleaned up in the main thread prior to returning, and so
the final destructor referred to an object that was no longer valid.

Another issue has to do with RAII [^1] – if you're relying on the destruction
of the target to release resources, the fact that the target is effectively
never deleted is a potential problem.

Last but not least is the issue of overall tidiness – given that the shared
object is allocated within the scope of main(), it just seems wrong to let it go
out of scope after main() exits. Ideally, we’d like to destroy the shared object
prior to returning from main(), but how to do that?

Our next attempt looks like this:

{% include_code smart/smart2.cpp %}

In the destructor for the container class, we first reset() the container’s copy
of the shared_ptr. This reduces its reference count to zero, and also decrements
the reference counter on the static shared_ptr that was initialized when the
singleton was created. (The destructor of the container’s copy of the shared_ptr
will still be executed on return from the container’s destructor, but since the
reference count is already zero, it will do nothing).

Then we test the static shared_ptr to see if it’s reference count is equal to
one (by calling unique()), and if it is we call reset on it to decrement its
reference count once again, which ends up deleting the singleton (since the
reference count is now zero).

When we run this version of the code, we see the following output:

{% include_code lang:console smart/smart2.out %}

We can see that the singleton does in fact get destroyed prior to returning from
main(), which is what we want. We also see that the singleton gets destroyed
when nobody is using it, and automatically gets recreated if needed, which is
all well and good.

But, the code to make this happen does seem a bit messy, and potentially
unclear. Surely, there’s a better way to get the behavior we want without having
to directly manipulate reference counts.

Which brings us to shared_ptr’s cousin, the weak_ptr. A weak_ptr is similar to a
shared_ptr, except that assigning to a weak_ptr does not increment the shared
reference count:

{% include_code smart/smart3.cpp %}

In this version, we change the code to use a weak_ptr instead of a shared_ptr
for the static class member that is initialized on creation of the singleton
object, and we remove the fiddling with reference counts that we had to do make
things come out right in the previous example.

{% include_code lang:console smart/smart3.out %}

Et voila – we can see that the behavior is exactly what we wanted, but without
the need to manipulate reference counts directly. Not to mention, the behavior
is a bit more like what one would expect (e.g., member variables get destroyed
on exit from the destructor, not in the body of the destructor).

### Acknowledgements

Thanks to the folks at cplusplus.com, especially “simeonz” for
[this post](<http://www.cplusplus.com/forum/general/37113/>), which discusses the
general problem and provides a nice code example that I used as the basis for
this discussion.


[^1]: <http://en.wikipedia.org/wiki/Resource_Acquisition_Is_Initialization>

[^2]: A free copy of the most recent working draft can be downloaded [here](<http://isocpp.org/files/papers/N3690.pdf>).

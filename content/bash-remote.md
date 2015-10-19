{% img right /images/multimonitors.jpg 370 245 %}

Nowadays it's pretty common for applications to be distributed across multiple
machines, which can be good for scalability and resilience.

But it does mean that we have more machines to monitor -- sometimes a LOT more!

Read on for a handy tip that will let you do a lot of those tasks from any old
session (and maybe lose some of those screens)!

<!-- more -->

For really simple tasks, remote shell access using ssh is fine.  But oftentimes
the tasks we need to perform on these systems are complicated enough that they
really should be scripted.

And especially when under pressure, (e.g.,  troubleshooting a problem in a
production system) it's good for these tasks to be automated. For one thing,
that means they can be tested ahead of time, so you don't end up doing the
dreaded `rm -rf *` by mistake.  (Don't laugh -- I've actually seen that happen).

Now, I've seen people do this by copying scripts to a known location on the
remote machines so they can be executed.  That works, but has some
disadvantages: it clutters up the remote system(s), and it creates one more
artifact that needs to be distributed and managed (e.g., updated when it
changes).

If you've got a bunch of related scripts, then you're going to have to bite the
bullet and manage them (perhaps with something like Puppet).

But for simple tasks, the following trick can come in very handy:

`
ssh HOST ‘bash –s ‘ < local_script.sh
`

What we're doing here is running bash remotely and telling bash to get its input
from stdin.  We're also redirecting local_script.sh to the stdin of ssh, which
is what the remote bash will end up reading.

As long as local_script.sh is completely self-contained, this works like a
charm.

For instance, to login to a remote machine and see if hyper-threading is enabled
on that machine:

`
ssh HOST 'bash -s' < ht.sh
`

Where ht.sh looks like this:

{% include_code lang:bash bash/ht.sh %}


(The script above was cribbed from http://unix.stackexchange.com/a/33509 --
thanks, Nils!)


Of course, all the normal redirection rules apply -- you just have to keep in
mind that you're redirecting to ssh, which is then redirecting to bash on the
input side.  On the output side, it's reversed.

Give this a try the next time you need to do some quick tasks over ssh and
you'll be able to get rid of a few of those monitors!

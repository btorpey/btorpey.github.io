Here's a handy tip for those who (like me) spend a fair amount of time staring
at FIX logs.

<!--more-->

FIX may be the protocol that everybody loves to hate, but it doesn't look like it's
going anywhere, so I guess we all just need to get over it and learn to live with it.

One of the things that is hard to live with, though -- at least for me -- is the
visual cacophony that results when browsing FIX logs with less.
{% img center /images/less-before.png %} 

It turns out that it's possible to control how less displays the x'01'
delimiters to make this chore a little easier on the eyes.  In my case, I
use the following in my .bash_profile:

`export LESSBINFMT="*u%x"`

This dials down the visual clutter to a level that I find much easier to deal
with.
{% img center /images/less-after.png %} 


(Note that the man page for less mentions that it's possible to display the hex codes in square brackets, but I have not found that to work on any of the systems where I've tried it -- YMMV).

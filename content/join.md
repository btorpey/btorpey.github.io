{% img right /images/Gold_Hat_portrayed_by_Alfonso_Bedoya.jpg 220 162 %}

I've been working on performance analysis recently, and a large part of that is scraping log files to capture interesting events and chart them.

I'm continually surprised by the things that you can do using plain old bash and his friends, but this latest one took the cake for me.

<!-- more -->

Did you know that Linux includes a utility named `join`?  Me neither.  Can you guess what it does?  Yup, that's right -- it does the equivalent of a database join across plain text files.

Let me clarify that with a real-world example -- one of the datasets I've been analyzing counts the number of messages sent and received in a format roughly like this:

|Timestamp| Recv |
|:--------|-----:|
| HH:MM:SS| x |

<br>
Complicating matters is that sent and received messages are parsed out separately, so we also have a separate file that looks like this:

|Timestamp| Send |
|:--------|-----:|
| HH:MM:SS| y |

<br>
But what we really want is something like this:

|Timestamp| Recv | Send |
|:--------|-----:|------:|
| HH:MM:SS| x | y |

<br>
I had stumbled across the `join` command and thought it would be a good way to combine the two files.

Here are snips from the two files:

    $ cat recv.txt
    Timestamp	Recv
    2016/10/25-16:04:58	7
    2016/10/25-16:04:59	1
    2016/10/25-16:05:00	7
    2016/10/25-16:05:01	9
    2016/10/25-16:05:28	3
    2016/10/25-16:05:31	9
    2016/10/25-16:05:58	3
    2016/10/25-16:06:01	9
    2016/10/25-16:06:28	3
<br>

    $ cat send.txt
    Timestamp	Send
    2016/10/25-16:04:58	6
    2016/10/25-16:05:01	18
    2016/10/25-16:05:28	3
    2016/10/25-16:05:31	9
    2016/10/25-16:05:58	3
    2016/10/25-16:06:01	9
    2016/10/25-16:06:28	3
    2016/10/25-16:06:31	9
    2016/10/25-16:06:58	3


Doing a simple join with no parameters gives this:

    $ join recv.txt send.txt
    Timestamp Recv Send
    2016/10/25-16:04:58 7 6
    2016/10/25-16:05:01 9 18
    2016/10/25-16:05:28 3 3
    2016/10/25-16:05:31 9 9
    2016/10/25-16:05:58 3 3
    2016/10/25-16:06:01 9 9
    2016/10/25-16:06:28 3 3

As you can see, we're missing some of the measurements.  This is because by default `join` does an [inner join](https://en.wikipedia.org/wiki/Join_(SQL)#Inner_join) of the two files (the intersection, in set theory).

That's OK, but not really what we want.  We really need to be able to reflect each value from both datasets, and for that we need an [outer join](https://en.wikipedia.org/wiki/Join_(SQL)#Outer_join), or union.

It turns out that `join` can do that too, although the syntax is a bit more complicated:

    $ join -t $'\t' -o 0,1.2,2.2 -a 1 -a 2 recv.txt send.txt
    Timestamp	Recv	Send
    2016/10/25-16:04:58	7	6
    2016/10/25-16:04:59	1
    2016/10/25-16:05:00	7
    2016/10/25-16:05:01	9	18
    2016/10/25-16:05:28	3	3
    2016/10/25-16:05:31	9	9
    2016/10/25-16:05:58	3	3
    2016/10/25-16:06:01	9	9
    2016/10/25-16:06:28	3	3
    2016/10/25-16:06:31		9
    2016/10/25-16:06:58		3


A brief run-down of the parameters is probably in order:

|Parameter | Description
|----------|------------
| `-t $'\t'` | The `-t` parameter tells `join` what to use as the separator between fields.  The tab character is the best choice, as most Unix utilities assume that by default, and both Excel and Numbers can work with tab-delimited files.<br>The leading dollar-sign is a [trick](https://unix.stackexchange.com/a/46931/198530) used to to pass a literal tab character on the command line  .
| `-o&nbsp;0,1.2,2.2` | Specifies which fields to output.  In this case, we want the "join field" (in this case, the first field from both files), then the second field from file #1, then the second field from file #2.
| `-a 1` | Tells `join` that we want **all** the fields from file #1.
| `-a 2` | Ditto for file #2.

As you can probably see, you can also get fancy and do things like left outer joins and right outer joins, depending on the parameters passed.

Of course, you could easily import these text files into a "real" database and generate reports that way.  But, you can accomplish a surprising amount of data manipulation and reporting with Linux's built-in utilities and plain old text files.

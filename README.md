# Key logging on OS X

It isn't very complicated, actually! Not sure why most of the existing loggers out there require shady kernal patches / extensions via kext, etc. I don't want to hide the key logger from myself, I just want it to log my keys!

This implementation doesn't currently log keys as strings, but as key codes, which is what the OS X library uses natively. Here's the alphabet:

| key code | character |
|---------:|-----------|
| 0        | a |
| 11       | b |
| 8        | c |
| 2        | d |
| 14       | e |
| 3        | f |
| 5        | g |
| 4        | h |
| 34       | i |
| 38       | j |
| 40       | k |
| 37       | l |
| 46       | m |
| 45       | n |
| 31       | o |
| 35       | p |
| 12       | q |
| 15       | r |
| 1        | s |
| 17       | t |
| 32       | u |
| 9        | v |
| 13       | w |
| 7        | x |
| 16       | y |
| 6        | z |

The numbers (which are _not_ in order):

| key code | character |
|---------:|-----------|
| 18       | 1 |
| 19       | 2 |
| 20       | 3 |
| 21       | 4 |
| 23       | 5 |
| 22       | 6 |
| 26       | 7 |
| 28       | 8 |
| 25       | 9 |
| 29       | 0 |

And some control characters / whitespace:

| key code | key event |
|---------:|-----------|
| 49       | space |
| 48       | tab |
| 36       | enter |
| 51       | backspace |
| 53       | escape |
| 117      | delete |
| 123      | left |
| 124      | right |
| 125      | down |
| 126      | up |


## Instructions

Build:

    clang key-tap.m -o key-tap -fobjc-arc -Wall \
      -framework Foundation -framework ApplicationServices

Then run:

    sudo ./key-tap &

The log files default to `/var/log/osx-tap/*.log`, where the file name is the epoch ticks when `key-tap` was started.

Each log line has four tab-separated fields:

1. Offset in seconds since log started
2. Key code (see above)
3. Action ("down" or "up")
4. Modifier keys, joined by "+"

Thus, here's the line for clicking Command+C 14 minutes and 2 seconds after the logger was started:

    842    8    down    command

You can easily see the running tally of keystrokes by running:

    tail -f /var/log/osx-tap/*.log


## References

* https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html
* http://danielbeard.wordpress.com/2010/10/29/listening-for-global-keypresses-in-osx/

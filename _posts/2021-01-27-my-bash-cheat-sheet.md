---
layout: post
title: My Bash Cheat Sheet
date: 2021-01-27 16:26 -0400
categories: [Cheat Sheet]
tags: [bash, cheat sheet]
---

I use bash a lot. Say what you will of it, it's a powerful shell. Sure I keep hearing that zsh is so much better, but I come from a system administrator background, so...while I think Zsh is neat to use for your workstation, when I'm connecting to other servers and doing work there, the probability that bash is the default shell is pretty high. Luckily, bash has a ton of neat tricks that can help you out. You can find any number of bash cheat sheets out there, such as [this one](https://github.com/LeCoupa/awesome-cheatsheets/blob/master/languages/bash.sh), but these are the ones I use enough to commit them to muscle memory.

I should also note that a lot of these are also available and working with zsh, though there are some slight differences in some fringe cases. Like `CTRL+U` for example.

## Key Binds

These are some `CTRL-<key>` keybinds that I frequently use:

```text
CTRL+C     # kills the process
CTRL+U     # Deletes everything behind cursor
CTRL+K     # Deletes everything from the cursor to the end of the line
CTRL+Y     # Pastes the last thing removed (used frequently with CTRL+U)
CTRL+Z     # stops the current process, can be restarted though (see later)
CTRL+R     # reverse-search through command line history
```

To that end, I use `CTRL+R` for a *ton* of things. When I first boot up my attack VM and want to connect to [HackTheBox](https://www.hackthebox.eu/), the first thing I need to do is connect to the VPN. I could always alias it, but instead I hit `CTRL+R`, then start typing "sudo openvpn" until the command I want to run appears, and then hit enter. Easy peasy.

Another fun thing I tend to do is something like this:

```text
mkdir -p /usr/local/share/my_new_dir
cd <ALT+.>
```
The `ALT+.` keypress will print the last argument of the last command you executed. Hitting it again will choose the argument before that, and again it will show the last argument of the command *preceeding* that, all the way up your command history.

## Whoops, I messed up that last command

You can do a fairly quick command substitution of the previous command with carats. To run the command you just ran with a text substituion, you use `^replace_from^replace_to`

So for example, see how I can recover from a misspelled `cd` command:

```
agr0@ubuntu:~$ cd /usr/local/din/
bash: cd: /usr/local/din/: No such file or directory
agr0@ubuntu:~$ ^din^bin
cd /usr/local/bin/
agr0@ubuntu:/usr/local/bin$ 
```

I used `^din^bin` to run the command I just ran but replaced the word "din" with "bin". I don't see this documented in too many places.

---

Sometimes when you mess up your previous command, you simply forgot to add a flag or something. Luckily bash (and zsh) has a handy reference to the last command you just ran: `!!`

This can come in handy if you, like most people, forget to prepend `sudo` to a command before you run it, as I do maybe 95% of the time:

```text
agr0@ubuntu:~$ apt update
Reading package lists... Done
E: Could not open lock file /var/lib/apt/lists/lock - open (13: Permission denied)
E: Unable to lock directory /var/lib/apt/lists/
agr0@ubuntu:~$ sudo !!
sudo apt update
Hit:1 http://us.archive.ubuntu.com/ubuntu focal InRelease
Hit:2 http://security.ubuntu.com/ubuntu focal-security InRelease                       
Hit:3 http://us.archive.ubuntu.com/ubuntu focal-updates InRelease 
```

I've seen people alias the word "gah" to `sudo !!`. I've also seen some more vulgar aliases, but you get the idea.

---

Similarly, the `!` prefix is a link to your command history. If you type a `!` and then another letter or few letters, like say "cu", it will search back through your command history and find the most recent command that starts with the letters "cu" that it finds. So if you have that really giant curl command that you don't want to type out again but you know that was the last curl command you ran, you can do something like this:

```text
agr0@ubuntu:~$ !cu<enter>
curl -k -XPOST -d "user=admin&password=12345" http://127.0.0.1:5000
```

---

That's most of the easy ones. There are so many neat things that bash can do that I feel like I'm only scratching the surface. I will make another post about some more advanced uses of bash that I frequently use (or need some means of referring back to) in the near future.
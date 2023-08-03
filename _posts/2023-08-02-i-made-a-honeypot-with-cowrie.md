---
layout: post
title: I made a Honeypot with Cowrie
date: 2023-08-02 16:58 -0400
categories: [Misc]
tags: [cheatsheet, honeypot, cowrie, ssh, malware]
---

To give credit where it is due, I decided to set up a honeypot as inspired by [John Hammond](https://johnhammond.org/). Recently he made a [youtube video](https://www.youtube.com/watch?v=NWytrZVM6WM) that described his setup and the resulting display of hundreds of red teamers or general _curious_ people to break into his server. Unfortunately I missed his twitter post (or X or whatever Elon is naming it now) where he announced it or I would have at least tried, but regardless this video gave me inspiration to set one up myself. I have always been vaguely interested in setting up a honeypot, and now I figured I can finally do it.

However, there are always inherent risks when setting up a honeypot. I mean seriously, just consider the concept here: You are intentionally setting up a vulnerable service for someone to break into. It is intentionally low-hanging fruit, something relatively easy and enticing for a bad actor to fall for. Regardless of how it is set up, you are _still setting up a service that a bad actor is expected to interact with._ What happens if the honeypot itself is vulnerable to a jailed escape? Well then you are full-on compromised if you don't have the proper failsafes put in place.

This was always at the forefront of my mind until I finally just decided to stick the service on a completely isolated throw-away virtual machine somewhere out there in the ether. That way if someone _were_ to compromise the host, then oh well. Whoopsie-daisy, just blow it away and forget it ever existed. I will treat this machine as if it were already infected and never store anything even remotely sensitive on it.

And frankly, you should too.

## How to Install

After you've made up your mind and decided to install cowrie someplace safe (mind you, there is a [docker image](https://hub.docker.com/r/cowrie/cowrie) you can use, but I found interacting with the provided scripts to be clunky and not very straightforward), you generally want to start your honeypot on a blank slate. For the purpose of my setup, I have gone with a Debian box. Mind you the documentation I followed came from a few different sites, but the [cowrie readthedocs site](https://cowrie.readthedocs.io/en/latest/) is probably the most comprehensive. Regardless, I wanted to create a few additional steps to add a little bit of realism here.

### Initial Prep Stages

First, let's prep the OS. After booting into a fresh Debian build...

```sh
apt-get update && apt-get install -y git python3-virtualenv libssl-dev libffi-dev build-essential libpython3-dev python3-minimal authbind virtualenv vim openssh-server python3.11-venv jq
```

Once that's done and all the dependencies are installed, let's create a cowrie user.

```sh
# This creates a new user with a home directory and no password, without prompting for name, phone, etc.
adduser --disabled-password --gecos "" cowrie
```

Now let's name our virtual system. This won't be what an attacker would be presented with, so we can just name it `honeypot`.

```sh
echo honeypot > /etc/hostname
hostname -F /etc/hostname
```

I'm going to configure cowrie to listen on an ssh port, so we need to move the _actual_ ssh service to another port. I'll set it to `9022`. Also I'll get fancy and let `sed` do the work for me. I can restart the service even if I'm currently connected because `sshd` forks all new connections to new processes, so future connections will listen on port `9022`.

```sh
sed -i 's/#Port 22/Port 9022/g' /etc/ssh/sshd_config
systemctl restart ssh
```

Now for the good stuff. I'll set up cowrie.

### Setting Up Cowrie

I'll do this as root and drop privileges later. This will save me the hastle of having to juggle user accounts when messing with `authbind`.

```sh
# I'll set up cowrie in /opt, but change this to wherever. Doesn't really matter. Not in root's home dir though. C'mon now.
pushd /opt

git clone http://github.com/cowrie/cowrie
pushd cowrie

# Create a python virtual environment and enter it
python3 -m venv cowrie-env
source cowrie-env/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade -r requirements.txt
```

Now that cowrie is installed, it's time to configure it to some basic defaults. A lot of these you can play with, and in fact in the near future maybe I'll configure this to upload data to a collector agent of some sort like an ELK stack, Splunk or whatever, but for the time being I'll just go with some simple changes. To configure this, you'll want to edit `/opt/cowrie/etc/cowrie.cfg`, which doesn't exist by default. You can take what you need from `cowrie.cfg.dist` which is already included and has all the cowrie defaults configured, so you can simply copy the `cowrie.cfg.dist` file to the `cowrie.cfg` file and make your edits there. Here are my settings:

```sh
cat > /opt/cowrie/etc/cowrie.cfg <<EOF
[honeypot]

hostname = admin001
timezone = US/Central

[shell]
arch =
kernel_version = 5.4.0-88-generic
hardware_platform = x86_64
operating_system = GNU/Linux

[ssh]
ssh_version = OpenSSH_8.2p1 Ubuntu-4ubuntu0.2, OpenSSL 1.1.1f 31 Mar 2020
version = SSH-2.0-OpenSSH_8.2p1 Ubuntu-4ubuntu0.2
listen_endpoints = tcp:22:interface=0.0.0.0
EOF

chown -R cowrie:cowrie /opt/cowrie
```

The above shows whatever arbitrary data you'd like to present the user with when they run things like `uname` or whatever nmap scans will return when it finds SSH listening on port 22. Additionally, the hostname will display as the above after a shell is presented to the user. More than this config may be a little overkill unless you're offloading data to an external server (again, something I may do in the future), but by and large the above should be more than fine. Also don't forget to let the `cowrie` user own the above files.

### Configure Cowrie to Listen on Port 22

Now cowrie will _not_ run as root, so it won't have access to any ports less than 1024. To get around this, I'll use `authbind`, which will bind on the port and forward to this service without the need for root access. To accomplish that, since `authbind` is installed, I can do this to allow it to listen on port 22:

```sh
touch /etc/authbind/byport/22
chown cowrie:cowrie /etc/authbind/byport/22
chmod 770 /etc/authbind/byport/22
```

There we go. Now for the fun stuff, let's get into how Cowrie works.

### How Cowrie Works

Cowrie does not actually drop an interactive shell. Well, actually it does _technically_, but not like a bash shell. Really it's a separate service altogether that mimics a basic bash shell. Most commands will work kind of, but not really. They will look like they're working, but really they're just interacting with a made-up environment that gets removed at the termination of each session. However it's kind enough to monitor every aspect of the session, including the passwords attempted, every single command entered, heck even a real-time recording of the entire interactive session so you can monitor the whole interaction. Any files that are downloaded with curl, wget, tftp or even ftp I believe will be downloaded and placed aside for the owner of the honeypot to perform some reverse engineering on later if they'd like. In fact, you can even have cowrie upload these files to [VirusTotal](https://www.virustotal.com) automatically, provided you give it your API key that you've purchased from them.

The point here is that cowrie does its best to _seem_ like you obtained a legitimate shell, when really you have entered into a fully-recorded instance of a made-up server, ready and waiting for you to load your tools onto it and wreak havoc. It does not retain state, it does not delete history, it's a brand new seemingly-never-touched-before instance of a server each and every time you log into it.

With that said, it's probably best to change the defaults. You don't want it to be obvious that it's a cowrie server, and the most tell-tale way to determine if you're in a cowrie server is if you are able to log in as the `phil` user with any password I believe. Let's change that, because it's not very straightforward.

The thing to understand about cowrie is that you can basically change every aspect of the session, including the entire filesystem. It's generally better to just change what is provided, but if you want it to mimic something like an IoT device then this is probably where you should first go.

#### The File System

Cowrie's "file system" is actually not a file system, but rather consists of three parts:

1) A python serialized object called a pickle file, which is located in `/opt/cowrie/share/cowrie/fs.pickle`. This file contains the entire OS contents of the instance the bad actor would enter. The entire directory structure appears in this file. You can't open this file in a standard text editor because it contains numerous unprintable characters. I'll explain how to edit this later.
2) A list of files that contain some sort of data to read when the bad actor runs `cat` on it or something similar. These files are in `/opt/cowrie/honeyfs`. Anything you put in this file **as well as the fs.pickle file** will output that data whenever someone tries to read that specific file. There's a whole process to this so you can't just dump a file in there and expect it to be visible from the cowrie shell. Again, I'll explain how to do this later.
3) A list of files that contain mimic binary data. Any file in the `/opt/cowrie/share/cowrie/txtcmds` directory will output whatever text you enter in these files if the attacker simply runs these commands. Again, you do need to do a bit more than just add the file in this directory, so more on that later.

#### The Username System

You can configure cowrie to be as restricted or as unrestricted as you want when it comes to who can access the system. Unfortunately making a change to a user is not _that_ straightforward if you want to change anyone other than root, but it's still not so bad either way.

First of all, you can specify who can log in by copying `/opt/cowrie/etc/userdb.example` to `/opt/cowrie/etc/userdb.txt`, then editing the latter file. Here's what it looks like:

```text
# Example userdb.txt
# This file may be copied to etc/userdb.txt.
# If etc/userdb.txt is not present, built-in defaults will be used.
#
# ':' separated fields, file is processed line for line
# processing will stop on first match
#
# Field #1 contains the username
# Field #2 is currently unused
# Field #3 contains the password
# '*' for any username or password
# '!' at the start of a password will not grant this password access
# '/' can be used to write a regular expression
#
root:x:!root
root:x:!123456
root:x:!/honeypot/i
root:x:*
tomcat:x:*
oracle:x:*
*:x:somepassword
*:x:*
```

It's pretty self explanatory here. You can set it up so everyone can log is as root with `root:x:*`, or just with `root:x:password`. However if you want to create a new user to replace the `phil` user that is already included, you'll have to make a few edits. Specifically to `/opt/cowrie/honeyfs/etc/passwd`, `/opt/cowrie/honeyfs/etc/group`, and `/opt/cowrie/honeyfs/etc/shadow`, which will specify the home directory of your new user. I created the user `admin` in the `userdb.txt` file and changed all instances of `phil` in the assocated `passwd`, `group`, and `shadow` files to `admin`.

### Add Files to the File System

Let's create three exercises for ourselves. First, let's create an SSH banner and a MOTD which will display upon successful connection. Then let's create an ssh priv/pub keypair in the `/home/admin` user directory, and finally let's create the `checksrv` "binary" to return "All Systems Nominal".

#### Create the SSH Banner and MOTD

This is fairly easy. We'll just modify the files that are already included in the `honeyfs/` file system. For the SSH banner, we'll write something concise yet alarming:

```sh
cat > /opt/cowrie/honeyfs/etc/issue <<EOF
ATTENTION: THIS SYSTEM IS MONITORED.

Welcome to the SSH Gateway. Before proceeding, please be aware:

1. All activities will be logged.
2. Unauthorized access is strictly forbidden.
3. Violators will be shot on sight.

Be warned of the above before logging in.
EOF
```

Now let's offer a similar "Thanks for logging in, just remember you're being watched" message.

```sh
cat > /opt/cowrie/honeyfs/etc/motd <<EOF
ATTENTION: THIS SYSTEM IS MONITORED.

Thank you for logging in. Please remember that all actions are recorded for security purposes.
Report any suspicious behavior to the administrator.

EOF
```

There we go, finished.

#### Create the Keypair

Now let's create the directory to host the keypair.

```sh
mkdir -p /opt/cowrie/honeyfs/home/admin/
pushd /opt/cowrie/honeyfs/home/admin/
```

Now let's generate the keypair:

```sh
cowrie@honeypot:/opt/cowrie/honeyfs/home/admin$ ssh-keygen -f id_rsa
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in id_rsa
Your public key has been saved in id_rsa.pub
The key fingerprint is:
SHA256:71oOW+j8M8YNZsSh7Em1rIippgzp2vwUHveKLcCJTUA cowrie@honeypot
The key's randomart image is:
+---[RSA 3072]----+
|.E               |
|.         o      |
| .     . = o     |
|  .     + =      |
| = .oo.+S+       |
|..=.o+..+o+      |
|o  oo   +++o     |
|+oo..o + B= .    |
|+=o.o.o =++o     |
+----[SHA256]-----+
```

No password. Not needed. Just want to create something that's juicy. Now the way that cowrie works is that we have these files ready, but they won't show up on the file system of a running session because they haven't been added to the pickle file that lists the files on the file system. To do that, we need to `touch` these files in the provided `fsctl` script, which is an interactive command prompt that lets you build the file system that cowrie will use. I'll use the provided file system and make changes to it.

```sh
/opt/cowrie/bin/fsctl /opt/cowrie/share/cowrie/fs.pickle
```

This opens a command prompt that acts similar to a bash shell, just seriously watered down:

```sh
Kippo/Cowrie file system interactive editor
Donovan Hubbard, Douglas Hubbard, March 2013
Type 'help' for help

fs.pickle:/$ ls
bin/
boot/
dev/
etc/
home/
initrd.img
lib/
lost+found/
media/
mnt/
opt/
proc/
root/
run/
sbin/
selinux/
srv/
sys/
test2
tmp/
usr/
var/
vmlinuz
fs.pickle:/$ cd /home
fs.pickle:/home$
```

From here we can make new directories with `mkdir` and create new files with `touch`. For this, I'm going to simply change the `/home/phil` directory to `/home/admin`:

```sh
fs.pickle:/home$ mv phil admin
File moved from /home/phil to /home/admin
fs.pickle:/home$ ls
admin/
```

Now I'll just `cd` into the admin directory and create the two new files. Remember these won't actually create the files, but rather let them appear on the file system. Since we already created the files in the `honeyfs/` directory with content, this will now officially let them show up when an attacker runs `ls` on the `/home/admin/` directory:

```sh
fs.pickle:/home$ cd admin
fs.pickle:/home/admin$ touch id_rsa
Added '/home/admin/id_rsa'
fs.pickle:/home/admin$ touch id_rsa.pub
Added '/home/admin/id_rsa.pub'
```

Now type `exit` to save the file. Now not only will someone see the `id_rsa` and `id_rsa.pub` files when they run an `ls` command, but if someone were to `cat` those files it would display its contents. Neato!

#### Create the checksrv Binary

One last thing. Let's create a file called `checksrv` which will output the text "All Systems Nominal". To do that, first let's go back into `fsctl` and create the file under someplace reasonable, like `/usr/local/sbin/`:

First, enter the `fsctl` prompt:

```sh
/opt/cowrie/bin/fsctl /opt/cowrie/share/cowrie/fs.pickle
```

I'll `cd` into the `/usr/local/sbin/` directory and simply `touch` the file:

```sh
fs.pickle:/$ cd /usr/local/sbin
fs.pickle:/usr/local/sbin$ ls
fs.pickle:/usr/local/sbin$ touch checksrv
Added '/usr/local/sbin/checksrv'
fs.pickle:/usr/local/sbin$ ls -l
-rwxrwxr-x 1 root   50 4096 2023-08-03 00:19 checksrv
```

You'll notice that I don't need to change the permissions because they are already set to world-executable. If not, I would run something like `chmod 755 checksrv` to ensure it is executable, but it looks here that it is already done.

Now I'll type `exit` to save the pickle file, and enter `/opt/cowrie/share/cowrie/txtcmds`. This is the directory that cowrie will look in for binary commands that will output a text string. This directory marks the root of the pickled file system, so if you wanted to create a file in `/usr/local/sbin`, we will have to do that from that directory:

```sh
mkdir -p /opt/cowrie/share/cowrie/txtcmds/usr/local/sbin
```

Now let's create that file:

```sh
cat > /opt/cowrie/share/cowrie/txtcmds/usr/local/sbin/checksrv <<EOF
All Systems Nominal
EOF
```

And we're done!

## Starting Cowrie

Now that we're all configured, let's start cowrie. This is plenty easy, and it _will_ complain about deprecated encryption algorithms. This is intentional to serve as a more enticing target.

```sh
/opt/cowrie/bin/cowrie start
```

Now we wait.

### What to Look For

Logs for all connections, successful or otherwise, will appear in `/opt/cowrie/var/log/cowrie/cowrie.[log,json]`. The `cowrie.log` file will output to syslog format, significantly more "grep-able", while the `cowrie.json` log is - you guessed it - in JSON format. You can read that with `jq . cowrie.json | less` for fun colors and pleasant formatting. This will log all of the connection attempts and commands run for each session. Be careful about passwords here, because if you accidentally forget to log into port `9022` and attempt to log in with a password on port `22`, your password WILL be recorded here in plaintext format. Definitely be careful about that one.

What is more interesting (in my opinion) are the session playback files stored in `/opt/cowrie/var/lib/cowrie/tty/`. The filenames are hashes and are unprintable data, but you can play them back as if they were a screen recorded session using the provided `playlog` script.

```sh
/opt/cowrie/bin/playlog /opt/cowrie/var/lib/cowrie/tty/$FILENAME
```

Finally, any files that were downloaded will be stored under `/opt/cowrie/var/lib/cowrie/downloads/`, as SHA256 hashes as the filenames. As always, be careful as these are most likely all malicious files that you definitely do not want to run. You can upload any of these to VirusTotal, or you could even do some reverse engineering of the malware to learn about it if you have the setup for it. Regardless, treat these files with surgical gloves as these are not something you'd want to execute blindly.

## Epilogue

A vast, vast, vast majority of successful connections you will get will come from bots. Scripts created by malicious actors designed to quickly download and execute malware as soon as they get a successful SSH connection. Very rarely will you ever come across an interactive session by an actual human being. But even still, the malware they download can be analyzed if you're careful enough, but generally speaking you should always send it to virustotal to see what is already known about it. You'll definitely find some interesting things.

In fact as of this morning the most recent login was a script that just called me something rude, didn't download anything at all, just echoed an insult at me and severed the connection. That wasn't very nice at all, you'd think these losers would have some manners, wouldn't you?

If you'd like to be included in a honeypot, you can try to ssh to `ssh.einados.com` and attempt to get in. It's not that difficult. I don't know how long I'll keep this honeypot up, but as of this writing is it up and running on it's own host. Knock yourself out I guess.
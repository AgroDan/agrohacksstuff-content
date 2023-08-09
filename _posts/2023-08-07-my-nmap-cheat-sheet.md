---
layout: post
title: My Nmap Cheat Sheet
date: 2023-08-07 09:18 -0400
categories: [Cheat Sheet]
tags: [cheat sheet, hacking, nmap]
---

Nmap is one of the cornerstones of penetration testing. It's one of, if not the first command you run before you even consider what attack surface to focus on on your target. It's the way to find out what the server does, how it listens, how it interacts, etc. This is digital equivalent of walking around the perimeter of the building with a flashlight, shining it in windows and doors, looking for methods of ingress. 

And boy does it have its share of command line arguments to custom-tailor your scans.

I am writing this document to have a quick-and-easy way to refer to commands I want to run with nmap without having to look at [their reference guide](https://nmap.org/book/man.html). I'll run some standard commands I usually run, followed by some parameters I should focus on. For the record however, I will consider the imaginary target of `10.20.30.40`. Also note that the default _type_ of scan that nmap performs with TCP is a SYN scan, which is done because it is the least "aggressive" scan. Send SYN packets and record which ones reply back with a SYN/ACK as opposed to a REJ or FIN, then press on from there (though nmap will generally tell you if it specifically was rejected on a port, which generally means there is a service listening on that port but it is filtered by a local firewall or some other ACL so you can't access it from where you are now). I think the original reason for SYN scans being the default is that it is the most covert comparitively speaking, but don't kid yourselves -- any IDS worth its salt will detect an nmap scan from a mile away, even a SYN scan.

## Typical Usage

### Ippsec Special

```terminal
$ sudo nmap -sC -sV -oN portscan -v 10.20.30.40
```


The above will scan the target (on TCP only) on the default "nmap's most popular 1000 ports". It will attempt to communicate with each open port and obtaining the version of the software listening on it (`-sV`). If it successfully connects to a port and determines the running service, it will attempt to run default scripts against it (`-sC`), which will do some basic enumeration on it. Say if it were to connect to a web server on port `:80`, it will then run simple things like `GET / HTTP/1.1\r\n` and return the title of the page. It will then record all output to a file named `portscan` in the "nmap" format (`-oN portscan`), and finally it will be verbose (`-v`). Running this in verbose will inform you the second it finds an open port, so you can attempt your own enumeration on the port before nmap can finish. This is useful if you are in a rush or something I guess. I should note that Ippsec generally uses `-oA <name of server>` instead of the above, but it's generally not necessary on a challenge on HackTheBox or something. Fairly useful on in-the-wild engagements though I suppose.

Finally, I want to stress the concept of running nmap as root. The `sudo` command is necessary since nmap utilizes packet capture capabilities when performing scans, which is something only root can do. Sure the nmap binary will still work, but without the ability to perform a SYN scan it will default to a TCP scan, which does not do any packet capturing but rather initiates a TCP connection to each port and attempting to negotiate with it on an application level. This capability restricts nmap's ability to detect (as I have certainly witnessed before), so SYN scans are generally considered the best option, especially according to nmap's documentation.

### Scan all TCP ports

```terminal
$ sudo nmap -p- -oN allports -v 10.20.30.40
```
In this scan, I typically run this after the Ippsec Special command. This will check for all open TCP ports ranging from 0-65535. The `-p-` is shorthand for the equivalent `-p 0-65535`. Also note that I save this to a file called `allports`.

### Scan specific TCP ports
```terminal
$ sudo nmap -sC -sV -p 22,25,80,443,5900-5999 -oN portscan 10.20.30.40
```
Sometimes after scanning all tcp ports I'll get a huge list of open ports that I haven't run version and default-script scans on. I can rectify that by specifying what ports to scan. This is usually quick so I don't need a verbose flag.

### Scan UDP ports

```terminal
$ sudo nmap -sU -oN udp-portscan -v 10.20.30.40
```
Note that I am not running version and default-script scans, though I can. This will only scan the first 1000 most popular ports (according to nmap). Note that this will take a long time since it's UDP, and UDP does not have to reply with a response to a port connection if it doesn't want to. So it will attempt to try to connect to the port, send default connection requests to the port, and wait for a response. If it doesn't get one it gives up and moves on, so as the psuedo-name implies, UDP really does stand for Unreliable Damn Protocol.

### Scan ALL UDP ports

```terminal
$ sudo nmap -sU -p- -oN udp-im-running-out-of-options -v 10.20.30.40
```
If I'm ever running this, I am completely out of ideas because this takes _forever_ to finish. This will scan all ports from 0-65535 on UDP, performing the same "connect-and-wait" method as listed above. This takes so long that I usually don't even bother with this.

### Bypass Some IDS and Firewalls

```terminal
$ sudo nmap -Pn --source-port=9090 -f 10.20.30.40
```
YMMV with the above. This will connect from a specific source port (for potential firewall evasion) as well as fragment packets to fool IDS as well.

### RING ALL THE BELLS

```terminal
$ sudo nmap -p- -T5 --max-retries 0 -v -oA allports --script /usr/share/nmap/scripts/ 10.20.30.40
```
This will scan the target with "extreme aggression." Also sets retransmissions to no cap so it will keep banging on the door until someone answers, basically. When they do answer, throw the kitchen sink at them by attempting to run all available scripts against the port, throwing caution to the wind. This is what you run when _you want them to know you're there_.

### Host Discovery: Ping-sweep an Entire Subnet

```terminal
$ sudo nmap -sn 10.20.30.0/24
```
This will perform an ICMP ECHO to all hosts on the 10.20.30.0/24 subnet. It is not uncommon for hosts to block ICMP, so this may not be the definitive

> Note for anyone running on a virtual machine, specifically VMWare
{: .prompt-warning}

If you are running this on VMWare in a NAT'd network, run this to "ping-sweep":

```terminal
$ sudo nmap -sn --unprivileged 10.20.30.0/24
```
It's been brought to my attention that performing a ping sweep in a very specific set of conditions, namely running a virtual machine inside VMWare with your network settings configured to NAT (which is the default), that you may get incorrect output in that _all_ hosts in the subnet will be considered up. The reason for this is because when operating with the `-sn` flag, nmap will check a target host is up using the following methods:

- nmap receives **ICMP** reply to **ICMP ECHO_REQUEST** packet
- nmap receives **ICMP** reply to **ICMP TIMESTAMP_REQUEST** packet
- nmap receives **TCP SYN/ACK** reply to **443/TCP SYN** packet
- nmap receives **TCP RST** reply to **80/TCP ACK** packet

Running nmap from a VMWare machine as stated above, the supplied network can generate a **TCP RST** reply to all of the **80/TCP ACK** packets, which can trick nmap into thinking all hosts are up. Setting the `--unprivileged` flag will run nmap assuming you are not a privileged user with the capability of sniffing the wire, so will resort to checking for port 443 connections _only_. The better answer to this is to run your VM in bridged mode when performing this to achieve more accurate results.

### Host Discovery: List Scan

```terminal
$ sudo nmap -sL 10.20.30.0/24
```
This isn't as reliable because it doesn't send any packets to the target hosts. Just performs nameserver reverse lookups on the IP addresses. Still fairly covert though.

## Useful Flags

### OS Detection

```terminal
$ sudo nmap -O 10.20.30.40
```
This performs some fairly low-level inspection to determine the operating system of the target. A bit more detailed than standard TTL differences between Linux and Windows (TTL of packets on Linux start at 64, where Windows starts at 128), also attempts to perform some negotiation with the target to determine TCP Sequence predictability which can be used to fingerprint certain versions of an operating system. Evidently it is also possible to estimate the target's uptime by viewing the TCP timestamp option, but this is only viewable by adding the `-v` verbose flag.

### Scan Faster

```terminal
$ sudo nmap --min-rate 10000 10.20.30.40
```
Use this one lightly. If you want to just blast packets at the target as fast as possible, set the `--min-rate` value to something high like 10,000. This will send 10,000 packets at the target per second, so doing it this high will increase false positives (or false negatives). Use only if you know the network isn't that congested or otherwise has a fair amount of bandwidth. This is unnecessary unless you're on a time crunch or something.

### Shorten the Above

```terminal
$ sudo nmap -A 10.20.30.40
```
This will perform version checking, default script scanning, OS detection and perform a traceroute while it's at it. Sure you can just use this instead of any of the other stuff I mentioned before, but don't you want to confuse the script kiddies?

### Logging

```terminal
$ sudo nmap -oA portscan 10.20.30.40
```
There are a few formats you can output to. `-oA` outputs to the three major ones, which is normal output (`-oN`), grep-able (`-oG`), and XML (`-oX`). Provide it with a filename and it will create 3 filenames with different extensions. Of course a shoutout goes to `-oS filename` which outputs in `S|<rIpt kIddi3` format.

### DNS Resolution

```terminal
$ sudo nmap -n 10.20.30.40
```
Passing `-n` to a scan will choose NOT to perform DNS resolution. Passing `-R` will always attempt to resolve.

### Skip Host Discovery

```terminal
$ sudo nmap -Pn 10.20.30.40
```
If you know for a fact that the host is online but _isn't_ responding to pings, Pass the `-Pn` flag to it to skip standard host discovery and attempt to scan the standard way.

### Nmap Scan Through Proxy

```terminal
$ sudo nmap -sT --proxy socks4://40.40.50.50:5789 10.20.30.40
```
Assuming here you have a socks4 proxy listening on `40.40.50.50:5789`, this will attempt to funnel all communication through the proxy to hit the remote side. Note that you can only use TCP scans through here as is the nature of proxied traffic. Another option is to use proxychains:

```terminal
$ sudo proxychains nmap 10.20.30.40
```

## Nmap Scripts

Personally, I don't find nmap scripts to be that useful, though occasionally they tend to surprise me. I feel like there are better, more flexible tools to accomplish what nmap can do with scripts, but if you have the capability why not learn?

### Run Safe Scripts and Poke at Vulnerable Services

```terminal
$ sudo nmap -p 22,80,443 --script "vuln and safe" 10.20.30.40
```
Note that I'm specifying ports. You can run all scripts that are categorized as "Safe" (which generally don't raise that many red flags), as well as poke at vulnerable services as well (which generally raise red flags). For example, this will not only attempt to perform a version check on the webserver, but also attempt to see if it is vulnerable to something like the [Slowloris attack](https://en.wikipedia.org/wiki/Slowloris_(computer_security)).

### http-enum

```terminal
$ sudo nmap -p 80 --script http-enum 10.20.30.40
```
This script works similar to [Nikto](https://hackertarget.com/nikto-website-scanner/). Looks for various interesting files that may be on the server. There are better tools out there than this script.

### smb-enum-users

```terminal
$ sudo nmap -p 139,445 --script smb-enum-users --script-args 'smbusername="admin",smbpassword="password"' 10.20.30.40
```
The above is fairly neat, admittedly. You can attempt to log into an SMB service and dump users. There may be better tools out there, but it's a nice one to have. If you leave out the script args it will attempt to log in as a guest user with no password.

### LDAP

Nmap definitely has some halfway-decent ldap enumeration scripts that I've used on more than one occasion.

#### ldap-rootdse

```terminal
$ sudo nmap -p 389 --script ldap-rootdse 10.20.30.40
```
The above will attempt to negotiate with the LDAP server and pull the DSE, which is the DSA-Specific Entry (where DSA stands for Directory System Agent). This is useful for finding the default naming context, computer name, and several other interesting things about an LDAP server (such as an AD server).

#### ldap-search

```terminal
$ sudo nmap -p 389 --script ldap-search --script-args 'ldap.username="<ldap bind string>",ldap.password="<ldap password>", etc' 10.20.30.40
```
This will perform an ldap search against the target. This is neat but honestly you're better using `ldapsearch` for this instead. Regardless, you can read up on how to use it [here](https://nmap.org/nsedoc/scripts/ldap-search.html) if you're curious.

Beyond the above, however, there isn't much reason to use the last one. There is an `ldap-brute` script which - you guessed it - brute forces ldap bind authentication. But there are better, more flexible scripts to do exactly that. [CrackMapExec](https://github.com/mpgn/CrackMapExec) is the first one that comes to mind. It does it well, it does it fast, and it does it easier than the nmap script can.

## Conclusion

The best thing I can mention here is that nmap is a super useful tool. It has a scripting engine that in my opinion is largely fluff. It's useful at first but there are always better tools to accomplish what you need. From boot to root, nmap is typically one of the first steps you'd take, but in most occasions it serves as the determination of _where to focus next_. Super useful at the beginning of an attack, also useful after attempting to move laterally within a network. But the scripts are just meh.
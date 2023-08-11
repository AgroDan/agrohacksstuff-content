---
layout: post
title: Web Penetration Test Enumeration Guide
date: 2023-06-19 00:30 -0400
categories: [Hacking]
tags: [guide, cheat sheet, hacking, web, pentest]
---

Everyone has their own methods they follow, and enumeration in general is a bit of an art form. This page will serve as kind of a reminder for myself for when I take a break from it and forget some of the usual methods I tend to follow. I expect this to be kind of a living document that I will modify as I go, and this guide will only focus on web enumeration. Other protocols have their own separate steps (such as AD enumeration, etc), so this will only focus on what information can be gleaned from a website. Note that I am not in any way attempting to serve as an alternate to [Hacktricks.xyz](https://book.hacktricks.xyz), this is mostly my methods that I use before ultimately following examples on Hacktricks or [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) anyway.

## Scanning

Standard scanning is generally done with `nmap`. To achieve this, I have 3 basic scans I perform when starting out on a target.

```sh
sudo nmap -sC -sV -oN portscan -v <target ip>
```
The above will scan the top 1000 ports known to `nmap`.

Note the use of `sudo` to accomplish this. `nmap` uses a combination of low-level TCP connection requests as well as ICMP, and having the ability to read the response of `ICMP ECHO REPLY`s is something root can do. Without `sudo`, you will typically get false positives out of the scan. Generally speaking, unless you have super control over what your current user can read (or not read) with nmap, it's best to leave the mystery out of it and just run it as root.

The `-v` flag is also verbose, so it will display the open port it discovers as soon as it finds it, so you don't have to wait as long.

The `-sC` and `-sV` flags will perform service checks and run default scripts, so once it finds an open port it attempts to communicate with it as best as it can to determine what service is running on the discovered port, and once it does it will perform a few basic scripts that you can find useful on it. In the case of port 80 and 443, it will attempt to get the webpage title, check for a `robots.txt` file, and attempt to discover the version of web server that is running if it can.

Finally, `-oN` will write to the file `portscan` in "nmap" format, so basically a copy of what it display on the screen, minus the verbose text.

```sh
sudo nmap -p- -oN allports <target ip>
```
The above will run a scan to detect _any_ open ports from 0 to 65535. It will not perform any service checks or default scripts however. This will check for any oddball ports I missed on the previous scan. If any show up, I can list them like so:

```sh
sudo nmap -p 80,443,8080,9001,9090 -sC -sV -oN portscan <target ip>
```
Simply list the open ports I discovered in the previous scan (if any) as a comma-delimited list.

```sh
sudo nmap -sU -oN portscan-udp -v <target ip>
```
Sometimes the host has some UDP ports open as well. This will check the top 1000 of those. UDP is a bit harder to scan, because a port can be open but you'll never know unless the port responds back to you (or if the admin was kind enough to send REJECT packets for closed UDP ports). Regardless, this scan typically takes quite some time to finish.

Finally, you can scan all UDP ports, but this is generally when I hit a brick wall and can't think of anything else.

```sh
sudo nmap -sU -p- -oN allports-udp <target ip>
```
Naturally this scan takes _forever_.

> _Most_ of the above can be made easier with this handy script.
{: .prompt-info}

You can add this to your `.zshrc` or `.bashrc` file to make things a little easier:

```sh
scan() {
	SCANDIR="${PWD}/nmap_scans"
	if [ -z $1 ];
	then
		read "TARGET?Enter a target: "
	else
		TARGET=$1
	fi

	echo "Scanning ${TARGET}..."
	mkdir -p $SCANDIR
	sudo nmap -sS -sV -sC -oN $SCANDIR/initial-scan -v $TARGET
	sudo nmap -sS -p- -oN $SCANDIR/allports -v0 $TARGET &disown
	sudo nmap -sU -oN $SCANDIR/udpports -v0 $TARGET &disown
}
```
Now all you have to do is type `scan` and it will prompt you for a target, running 3 different scans and writing the output to a new directory `./nmap_scans`. Just a handy quality of life tip.

## Website Review

If a website is found, I will simply view it in a browser first. In [Obsidian](https://obsidian.md/), I will take notes on things that I find. Things that I look for and take note of:

- domain leaks, what domains can I discover from the target?
- email addresses
- usernames
- potential end points that lead to processed data. Forms to submit, apis, websocket communication, etc. You can find this out using <F12> to open developer tools in your browser.
- View source, any known frameworks? Wordpress, Joomla, etc.
- What is the page written in? If I check for the existance of `index.php`, it can tell me that the backend is written in PHP. If `index.html`, good chance this is a static site. `index.asp` is ASP, and if only `index` works, then this could be some other sort of MVC web app that has an "index" route.
- Is there a lot of "unique" copy on the page? If so maybe I can build a password list off of this content.
- Are there files served on the page? Anything that might have exif metadata? Use `exiftool` to extract any potential usernames or any other recon.

## Content Discovery

Always check to see if there are unlinked pages we can discover by brute force. There are two programs I use to discover new content, and I alternate between them because they act much different. The two I use are [Feroxbuster](https://github.com/epi052/feroxbuster) and [Gobuster](https://github.com/OJ/gobuster). Named so because of the languages they are written in (Rust and Go, respectively). Feroxbuster is fast, but recursive. Gobuster is also fast, has fewer emojis, and _not_ recursive. Feroxbuster tries to make as many assumptions as it can and sometimes this can lead to false negatives, and Gobuster is not as fast but not recursive, and also has some fancier built-ins that I don't use that often, such as s3 and gcs enumeration. Either way, sometimes it doesn't hurt to run both just in case.

### A Prerequisite: Wordlists

In the end, content discovery and web fuzzing in general is only as good as the wordlist provided. My standard goto for wordlists is the [SecLists](https://github.com/danielmiessler/SecLists) collection, though sometimes it doesn't hurt to try multiple. Regardless, wordlists mean many many requests to the server, so you are really going to rattle the cage with a giant wordlist and you will most likely be noticed by any blueteam worth their salt. Sometimes less is more.

For content discovery, I will generally use `SecLists/Discovery/Web-Content/raft-medium-words.txt` if I am attacking a linux endpoint, or `SecLists/Discovery/Web-Content/raft-medium-words-lowercase.txt` if I am attacking a windows endpoint, since it is case-insensitive, so no need to send more requests than is necessary.

### Feroxbuster

```sh
feroxbuster --url http://example.com/ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -x html,php
```

A note about the above: the `-x html,php` flag should never be used as the first run. This flag will append `.html` and `.php` to every single request, thereby tripling the amount of requests sent. This should only be done if you are sure what backend code is being run, ie. php or html.

With the above running against my site, I ran a feroxbuster scan using `common.txt`, a much smaller wordlist. This is the result of Feroxbuster:

```
 ___  ___  __   __     __      __         __   ___
|__  |__  |__) |__) | /  `    /  \ \_/ | |  \ |__
|    |___ |  \ |  \ | \__,    \__/ / \ | |__/ |___
by Ben "epi" Risher 🤓                 ver: 2.10.0
───────────────────────────┬──────────────────────
 🎯  Target Url            │ http://agrohacksstuff.io/
 🚀  Threads               │ 50
 📖  Wordlist              │ /usr/share/seclists/Discovery/Web-Content/common.txt
 👌  Status Codes          │ All Status Codes!
 💥  Timeout (secs)        │ 7
 🦡  User-Agent            │ feroxbuster/2.10.0
 💉  Config File           │ /etc/feroxbuster/ferox-config.toml
 🔎  Extract Links         │ true
 🏁  HTTP methods          │ [GET]
 🔃  Recursion Depth       │ 4
───────────────────────────┴──────────────────────
 🏁  Press [ENTER] to use the Scan Management Menu™
──────────────────────────────────────────────────
301      GET        7l       11w      169c http://agrohacksstuff.io/norobots => https://agrohacksstuff.io/norobots
301      GET        7l       11w      169c Auto-filtering found 404-like response and created new filter; toggle off with --dont-filter
[####################] - 2s      4717/4717    0s      found:1       errors:0      
[####################] - 1s      4716/4716    3791/s  http://agrohacksstuff.io/    
```

Oddly enough, it didn't return much at all.

### Gobuster

```sh
gobuster dir -u http://example.com/ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -x html,php
```

Gobuster requires you specify which module of Gobuster to use. In this case, we are using the `dir` module which does content discovery of a web server. Each module has their own options. Notice what Gobuster returns when pointing to my site:

```
===============================================================
Gobuster v3.5
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     https://agrohacksstuff.io
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/seclists/Discovery/Web-Content/common.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.5
[+] Timeout:                 10s
===============================================================
2023/06/19 17:45:22 Starting gobuster in directory enumeration mode
===============================================================
/.hta                 (Status: 403) [Size: 153]
/.htaccess            (Status: 403) [Size: 153]
/.htpasswd            (Status: 403) [Size: 153]
/about                (Status: 301) [Size: 169] [--> http://agrohacksstuff.io/about/]
/archives             (Status: 301) [Size: 169] [--> http://agrohacksstuff.io/archives/]
/assets               (Status: 301) [Size: 169] [--> http://agrohacksstuff.io/assets/]
/categories           (Status: 301) [Size: 169] [--> http://agrohacksstuff.io/categories/]
/index.html           (Status: 200) [Size: 39401]
/page2                (Status: 301) [Size: 169] [--> http://agrohacksstuff.io/page2/]
/posts                (Status: 301) [Size: 169] [--> http://agrohacksstuff.io/posts/]
/robots.txt           (Status: 200) [Size: 84]
/sitemap.xml          (Status: 200) [Size: 5427]
/tags                 (Status: 301) [Size: 169] [--> http://agrohacksstuff.io/tags/]
Progress: 4186 / 4716 (88.76%)
===============================================================
2023/06/19 17:45:26 Finished
===============================================================
```

Interesting how much more it is able to find with many of the default settings untouched compared to Feroxbuster. BTW please don't run content discovery on my site. I do not give you permission to do so. This was an example.

## Virtual Host Discovery

If I have a single domain name, I will attempt to discover if the server responds to additional virtual hosts hidden behind a subdomain. If there were potentially more targets, I would use Gobuster's DNS enumeration tool to see if anything resolves to another host, but if I suspect that this particular server hosts multiple sites separated by virtual hosts, I will use [Ffuf (Fuzz Faster U Fool)](https://github.com/ffuf/ffuf) to discover them. Not only is it a lot more intuitive, it's _fast_.

```sh
ffuf -c -u 'http://<target ip>' -H 'Host: FUZZ.example.com' -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt -mc all
```
There are two other similarly-named DNS wordlists, this is the biggest one. The idea here is I am connecting to a server and sending `Host: xyz.example.com` as one of the request headers. It will replace the word `FUZZ` with every word in the provided wordlist. FFUF will then respond with a deluge of responses, and will require further tuning. Quickly `CTRL+C` the output and you should see output similar to this:

```
[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 14ms]
    * FUZZ: ms1

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 14ms]
    * FUZZ: movies

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 15ms]
    * FUZZ: space

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 14ms]
    * FUZZ: ec

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 14ms]
    * FUZZ: forum2

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 15ms]
    * FUZZ: u

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 14ms]
    * FUZZ: money

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 15ms]
    * FUZZ: server5

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 13ms]
    * FUZZ: planet

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 14ms]
    * FUZZ: www.music

[Status: 200, Size: 309, Words: 41, Lines: 13, Duration: 16ms]
    * FUZZ: ns18

[WARN] Caught keyboard interrupt (Ctrl-C)
```

Notice how most of the responses show a size of 309 bytes, 41 words, and 13 lines. Considering how often we see that pattern, we can assume this is the `404 NOT FOUND` error message. We can re-run the command and filter on any of the aforementioned attributes, ignoring any of them if they appear in the list.

- `-fs 309` will filter on a size of 309 bytes.
- `-fw 41` will filter on a response that has 41 words.
- `-fl 13` will filter on a response that has 13 lines.

I will re-run this scan, ignoring any request that has a size of 309 bytes:

```sh
ffuf -u 'http://<target ip>' -H 'Host: FUZZ.example.com' -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt -mc all -fs 309
```

Now it will return anything different from the 404 response, exposing any potential subdomains that will host a website.

## Creating My Own Wordlist

[CeWL](https://github.com/digininja/CeWL) is a super-convenient tool for exactly this purpose. This will crawl through an entire site by discovering links in the HTML and create a wordlist that you can use with any of the above fuzzers/busters. Additionally, this can also be used for brute forcing a password, more on that later.

Basic usage I typically use:

```sh
cewl -w wordlist.txt -d 3 --with-numbers -a -e http://example.com
```
This will create a file `wordlist.txt` with any words it discovers on the site (minimum of 3 characters, _including_ numbers).

## Login Page

If I come across a login page to something, the first thing I do is try "low hanging fruit" usernames and passwords. Generally I will start with a username of `admin`, `administrator`, or `root`, and a password of: `admin`, `password`, `root`, `password123`. If neither of those work, I will try the following:

- Attempt to break the login prompt if it doesn't look like a login prompt I recognize. This involves adding all the special characters. Hold shift and walk down the number row: `~!@#$%^&*()-=_+[]\{}|;':",./<>?`
- I can attempt to see if the login prompt is SQL Injectable. To do this, I generally intercept the POST request in burp suite, then right click on it and choose "Copy to File", and I will choose something like `login.req`. Then I will run `sqlmap -r login.req --risk=3 --level=4 --batch` to kick off SQLMap against the login request.
- Attempt to determine if username emueration is possible. Does it tell me if either the username _or_ the password is incorrect, or does it definitively state which is incorrect? Is there a way to enumerate usernames based on the response template? If so, might be worthwhile to code something in python to do this properly. See my [Python Web Exploit Boilerplate]({% post_url 2023-06-09-python-web-exploit-boilerplate %}) page to start with that.
- Is there a version number mentioned in the login page? Are there any vulnerabilities associated with the app I'm attempting to log into?
  - Note: Sometimes this application is installed directly from the git repo, so there is a possibility that `README.md` or `CHANGELOG.txt` exists, so look for those to obtain a version if possible.
- Can I brute-force the login? I can use `CeWL` to generate passwords or possibly usernames as well from the discovered sites. Generally this should be a last-resort kind of thing.

## File Inclusion GET Parameters?

If it's determined that the site is generated dynamically using PHP, Flask, NodeJS, etc -- then possibly check for special GET parameters. Notably looking for things like a URL specifying `index.php?page=about` or whatever. Presumably the code for this page simply includes whatever is passed to the `page` parameter, relative to the specific directory it is told to look in.

Example PHP code for this vulnerability:

```php
<?php
$page = $_GET["page"];

include("pages/$page");
?>
```

The above is an _extremely_ vulnerable app, which will simply include and execute (if possible) any PHP code it encounters. If not PHP, then it will simply read any old file you pass it. So a request to `index.php?page=/etc/passwd` will dump the `/etc/passwd` file.

Sometimes the `file_get_contents()` function will be used, which will not execute PHP code but rather read the file itself and set the contents to whatever is assigned to it:

```php
<?php
$page = $_GET["page"];
$disallow = '|../|';

if (preg_match($disallow, $page) || substr($page, 0, 1) === "/") {
    echo "Hacking detected!";
    exit;
}

echo file_get_contents($page);
?>
```
This will work in the same way, However a bad developer will have a half-baked deny-list of special characters, such as the above. In this case, you can attempt to issue a PHP filter to bypass this: `index.php?page=php://filter/convert.base64-encode/resource=file:///etc/passwd`

And if you have confirmed a local file inclusion vulnerability, check out things I'll check if I discover this.

## Local File Inclusion

If I have discovered an LFI vulnerability, the next step is to discover exactly what files hold the most information useful for my next step. Here is a list of files (or file concepts) that I should attempt to display (and I expect this list to grow as needed):

- Source code of the running application
- `/etc/passwd`
- `/etc/nginx/nginx.conf`
- `/etc/nginx/sites-enabled/default`
- `/etc/apache2/apache2.conf`
- `/etc/apache2/sites-enabled/000-default.conf`
- `/etc/httpd/conf.d/default.conf`
- `/etc/httpd/httpd.conf`
- `/proc/self/environ`
- `/proc/self/cmdline`
- `/proc/<num>/cmdline` <-- create a script to dump as much as possible
- `/var/log/apache2/access.log` <-- potential to include executable code in `error.log` if `www-data` can read this file.
- `/var/log/apache2/error.log`

## Reflected Content

If I can submit data that will reflect back to me on the following (or some other) page, I will attempt to discover what gets filtered (if anything) before it gets reflected to the page. Can I add HTML? Will `<i>testing</i>` italicize the text? If so, can I get a XSS vulnerability with `<script>alert(1);</script>`, or `<img src="does_not_exist.jpg" onerror="alert(1);">`?

Otherwise, check for a potential Server Side Template Injection:

{% raw %}
```
{{7*7}}
${7*7}
<%= 7*7 %>
${{7*7}}
#{7*7}
*{7*7}
```
{% endraw %}

If any of the above returns `49`, then I know that it is vulnerable to an SSTI.

## API Negotiation

A REST API can sometimes display a help dialogue returned in JSON or similar if you simply crawl back a directory. For example, if you know of a REST endpoint at `/api/v1/display/resource/`, try accessing `/api/v1/display/`, and if nothing returns try accessing `/api/v1/`, etc. Remember to make sure you are setting the request headers' `Content-Type` to `application/json`, and you are attempting other methods like POST and PUT to see if anything changes.

Additionally, some APIs will not want JSON, but will accept XML as well. If you change the `Content-Type: application/xml`, you can then submit the same requests you sent in JSON by changing it to this format:

```xml
<?xml version="1"?>
<root>
    <abc>blah</abc>
</root>
```

Where in JSON, the equivalent would be:

```json
{
    "abc": "blah"
}
```

### XML

Note that if you come across anything that accepts XML as input, you should definitely attempt to perform an XML External Entity (XXE or XEE) attack on it. First to check if this is working, use this test (Taken from HackTricks):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [<!ENTITY toreplace "3"> ]>
<stockCheck>
    <productId>&toreplace;</productId>
    <storeId>1</storeId>
</stockCheck>
```

Obviously modify the above to be what the application is expecting. If `<productId>` resolves to `3`, then this application is vulnerable.

## .git/ Discovery

If you discover that a `.git/` directory is visible, you can run `git-dumper` against it to see if it can pull down what it can of the repository and check older commits.

First, install it with `pip install git-dumper`

Then point it to the site with 

```sh
git_dumper.py http://example.com/.git found-repo
```
to pull what it can into the `found-repo/` directory.

Also, you can use `trufflehog` to determine if there are any high-entropy strings (such as passwords) in any past commits, then trufflehog should find it.

```sh
trufflehog git --repo_path ./found-repo
```

## Werkzeug

If you can force an error on a page and you notice a debug screen that mentions Werkzeug, you can attempt to execute raw python from this page. However in order to execute code you will need the Debug code that is printed to STDOUT when the flask application starts. You can reverse engineer this code if you have access to specific files via an LFI discovered elsewhere. You can learn how to do that [here](https://book.hacktricks.xyz/network-services-pentesting/pentesting-web/werkzeug).
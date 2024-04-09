---
layout: post
title: Working with Bytecode in Python
date: 2024-04-05 09:50 -0400
categories: [Python]
tags: [cheat sheet, python, bytecode, hex, bytes]
---

In my experience and personal opinion, Python is the best language by far for needling around with literal bits and bytes when you need that level of control of your data. To me, it's just an easier environment to work in. If you're doing any sort of binary exploitation, you already have `pwntools` to help you out there. But even if you're not and you'd just like to do some work in simple bytecode (something that tends to happen quite a bit when you're working your way through a CTF), Python is probably one of the best manipulators of datastreams that I can think of. When I first learned about binary exploitation, most of my tutorials explained how to modify bytes using Perl. Thank God we've moved past that into a more _sensible_ language.

Now my goal here is to write a cheat sheet of sorts so I have something to refer back to when I am ultimately up against working with bytecode again, since for some reason this is one of those things where I'll know absolutely everything about it one day, I'll put it away for a few months, then when I need to come back to it I completely forget how to do basic things. I hope to use this as a quick refresher so I can just jump back into it when I need to. Hopefully.

## The Basics - Built-in Functions

Firstly, let's discuss the `bytes()` built-in function.

### bytes()

This function returns an immutable bytestring. Can be useful for returning a result or just dumping a literal representation of a number. Remember, a byte is basically an integer. The `bytes()` function can be used in several ways, but the two ways I've used the most are to return either a series of null bytes as long as you require, or a single byte of the raw value. The difference in how they are used relate to whether you ask for a single integer or a list of integers, where a list of integers will return the bytestring of exactly those numbers in raw binary form, here represented as hexidecimal:

```python
myNullBytes = bytes(5)
# myNullByte = b'\x00\x00\x00\x00\x00'

mySpecificByte = bytes([5])
# mySpecificByte = b'\x05'

bunchaBytes = bytes([5, 10, 15, 20])
# bunchaBytes = b'\x05\n\x0f\x14'
```
> Note: `\x0a` in ascii is LF (Line Feed), or here represented as `\n`. Additionally, for those that aren't as familiar with Python, a string denoted with the `b` prefix is a _bytestring_.
{: .prompt-info}

> Watch out though, if you choose a number greater than `256` it will throw an error. It is a single byte after all.
{: .prompt-warning}

You can also convert bytes to and from hex, but I'll put that in the `Conversions` section.

### bytearray()

A bytearray is pretty self-explanatory. While the `bytes()` function returns an immutable binary number, the `bytesarray()` function will return a mutable object which can be manipulated. Additionally, it can accept a raw string as long as you specify the encoding!

```python
ba = bytearray([5, 10, 15, 20])
# ba = bytearray(b'\x05\n\x0f\x14')

# bytearray will act like a list, and thus can be appended to and modified!
ba[1] = 11
ba[2] += 2
# ba = bytearray(b'\x05\x0b\x11\x14')

ba.append(25)
# ba = bytearray(b'\x05\x0b\x11\x14\x19')

# You can also create a bytearray from a string with an encoding
ba = bytearray("Hello, World!", "utf-8")
# ba = bytearray(b'Hello, World!')

# Then, since each index in the bytearray is technically an integer,
# you can do arithmetic on it!
ba[5] += 10
# ba = bytearray(b'Hello; World!')
```

### zip()

This function isn't necessarily used specifically for working with individual bytes, but you'd be surprised just how often this function comes in handy when combining two bytestrings. `zip()` will take two lists and allow you to iterate over both items at the same index, one by one. This especially comes in handy for `XOR` functions. If you want to `XOR` two bytestrings together, `zip()` to the rescue!

```python
plaintext = bytearray("Super secret password", "utf-8")
encryption_key = b's3cr3ts3cr3ts3cr3ts3cr3t'

ciphertext = bytes([x^y for x,y in zip(plaintext, encryption_key)])

# ciphertext is b' F\x13\x17\x17T\x00V\x00\x00\x00\x00SC\x02\x01\x16\x03\x1cA\x07'

# Now let's decrypt!
decrypted = bytes([x^y for x,y in zip(ciphertext, encryption_key)])
# decrypted = b'Super secret password'
```
> Note: if both lists being zipped are different sizes, `zip()` will stop iterating once the end of the shortest list is reached.
{: .prompt-info}
> Warning: do not use this for encryption. This is bad, bad encryption. But still cool.
{: .prompt-warning}

### ord()

The ordinal of a character is its decimal representation.

```python
ord('b')
# 98
```
> Note: only accepts one character. Will throw an error if multiple characters are referenced.
{: .prompt-info}

### chr()

The `chr()` function accepts an integer less than or equal to `65535` and returns the character that number represents. Note that `utf-8` is only one byte long, so anything greater than 255 will be a unicode character.

```python
chr(10940)
# ⪼

ord('⪼')
# 10940
```

## Conversions

Sometimes conversions are necessary, whether you're converting from binary to hex, to base64, or anything inbetween. Here's how to do them.

### Decode/Encode text from/to bytecode

I always forget which is which, but I'm saying it here: To convert strings to bytestrings, you have to _encode_ them. To convert bytestrings to strings, you have to _decode_ them. So in practice:

```python
byte_string = b'some string'
reg_string = 'another string'

print(byte_string.decode('utf-8'))
# "some string"

print(reg_string.encode('utf-8'))
# b"another string"
```

### Convert to hex

You can convert any byte or bytearray into hex by using the `bytes.hex()` function. This comes in handy pretty often!

```python
x = bytes([90])
x.hex()

# '5a'

y = bytearray("Hello there, young padawan", "utf-8")
y.hex()

# '48656c6c6f20746865726520796f756e67207061646177616e'
```
> Note: This will return a string of hex characters, not a hex number!
{: .prompt-info}

You can also convert a string to hex using the `binascii` library.

```python
import binascii

username = binascii.hexlify(b'admin')
# '61646d696e'
```

### Convert from hex

Converting from hex is just as easy. Note that this accepts a hex string!

```python
msg = "6b656570206861636b696e27"

bytes.fromhex(msg)
# b"keep hackin'"
```

You can _also_ use the built-in `hex()` function, but note that this will prepend the notation of `0x` in front of the number, which can cause some problems for things that aren't expecting it.

```python
hex(99)
# '0x63'

# You can just chop it off, but it is kludgy. Though it does work.
hex(99)[2:]
# '63'
```

### Base64

I have a potentially unhealthy obsession with Base-64. It's a cool idea that you can take any string of bytes, even a full executable file, and convert it into printable characters. You can store those printable characters anywhere, even in your clipboard! Just paste it through a decode method and presto, there's your data. I will show how to do this in Python, but sometimes it's more practical to use the `base64` binary on Linux/MacOS systems, or for the more Microsoft-leaning among us, `[Convert]::ToBase64String($SomeBytestringStoredAsVariable)`. Powershell is a bit more verbose than most.

Of course, you can always just use [CyberChef](https://gchq.github.io/CyberChef/).

#### Convert to Base64

```python
import base64

base64.b64encode(b'some string')

# b'c29tZSBzdHJpbmc='
```

#### Convert from Base64

```python
import base64

my_code = b'c29tZSBzdHJpbmc='

base64.b64decode(my_code)

# b'some string'
```
> Note: `b64encode`/`b64decode` both take byte strings as input. Use the above encode/decode to convert from a string.
{: .prompt-info}

## Endianness

### Python struct

Ah, the good ol' `struct` library. Can be extremely confusing, but also entirely necessary if `pwntools` aren't handy. When you're dealing with endianness, struct is your best friend. Let's say for example that you'd like to print our good friend `0xdeadbeef` in little endian. Sure you can do it manually:

#### Packing

```python
print("\xef\xbe\xad\xde")
```

Or you can let `struct` do it for you!

```python
import struct

my_bytes = struct.pack("<I", 0xdeadbeef)
print(my_bytes)
```

Now let's break down what just happened. the `struct.pack()` function takes (at least) two arguments. The first argument is the _format_, while the second argument is the actual data. The format is kinda funky, but given my general usage, I have only really needed to use two types, and for other formats you can look those up yourself. First of all, `<` is the symbol for **little endian**. Contrarily, `>` is the symbol for **big endian**. The second character is the format character, and in this case, `I` refers to an **unsigned integer**, which means the left-most byte is _not_ a flag for a positive or negative number, but rather just part of the number.

#### Unpacking

Unpacking is useful when you are trying to obtain the raw number stored in the bytestring. This can be useful if you are trying to read CBC padding, as proper padding will end with a series of numbers of how many bytes needed to be padded. If `\x04` shows up, you can use the `struct.unpack()` function to read in the raw digit(s).

```python
result = struct.unpack("B", b'\x04')[0]

print(result)
# 4

beef = struct.unpack("<I", b'\xef\xbe\xad\xde')[0]
print(beef)
# 3735928559
```
> Note: `struct.unpack()` returns a tuple, so most of the time you'd probably want the first result, hence the `[0]`. Additionally, `B` refers to an unsigned char. Since this is clearly a large integer I had to change it to `I`, and noted that it was little endian.
{: .prompt-info}

## Pwntools

Now I want to make something clear here, pwntools is like wheeling out the entire toolchest when all you need is a wrench. But let me tell you, this toolchest has some of the best libraries available to you. Note that [pwntools](https://docs.pwntools.com/en/stable/) is most likely not installed by default wherever you are, so you'll have to do the legwork of actually installing it (see their site). But once it does, it's hard _not_ to use some of their functions. It takes a lot of the guesswork out of things like arguments, endianness, etc. They're all there for you.

I want to also state that this isn't meant to be a tutorial on how to exploit binaries with pwntools, that is way out of scope. But for the sake of utility, I can't write this cheat sheet _without_ mentioning pwntools. And this is taken mostly from their site, so you should probably go there to learn more about it. But for my own edification, here it is.

### Hashing

```python
from pwn import *

md5sumhex('hello')
# '5d41402abc4b2a76b9719d911017c592'

sha1sumhex('hello')
# 'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d'
```

### URL Encoding

```python
from pwn import *

urlencode("Hello, World!")
# '%48%65%6c%6c%6f%2c%20%57%6f%72%6c%64%21'
```

### Convert to/from bits

```python
from pwn import *

bits('A')
# [0, 0, 0, 1, 0, 1, 0, 1]

unbits([0, 0, 0, 1, 0, 1, 0, 1])
# 'A'
```

### Packing and Unpacking

Probably one of the most useful things that pwntools does (and does well) is make it extremely simple to pack and unpack values into a bytestring. In fact, you can even specify the endianness of the environment once and not have to worry about specifying it all the time. For that, you can use specific functions.

```python
from pwn import *
context.endian = "little"

my_bytes = 0xdeadbeef

pack(my_bytes)
# b'\xef\xbe\xad\xde'

# You can even specify the size of the data. It will
# pad the data with null bytes if it doesn't fit!
# For this example, we'll use a 64-bit string
p64(my_bytes)
# b'\xef\xbe\xad\xde\x00\x00\x00\x00'
```

There is also `p8()` and `p16()` for packing 8 and 16 bits, respectively. Though in this instance it would error out because this bytestring is 32 bits long.

## Manipulate Bits with Math

I can't end this without mentioning bitwise arithmetic. Utilizing standard bitwise math can help you modify individual bits within a byte without having to do any weird list breakouts and re-assembling. Sometimes you just want to flip a single bit in a byte, and the easiest way to do that is using some fancy logical operators. I talk about some of this in my [PRNG and why you should tread lightly]({% post_url 2021-03-21-pseudo-random-number-generators-and-why-you-should-tread-lightly %}) page, but I'll just mention some of the easier methods used for bit flipping and such.

And yeah, if you already know about logical arithmetic then you can probably skip this section.

### AND'ing Will Copy or Zero

You can use the AND (&) operator to either copy a portion of a byte, or completely zero out a byte:

```python
myNumber = 0b00110011

# if I only want to copy the left-most 4 digits but return
# zeros for the right-most, I can AND it by 11110000:

leftMost = 0b11110000

copiedLeft = myNumber & leftMost
# copiedLeft = 0b00110000
```

Or you can completely zero out all or a portion of a byte by AND'ing it with all zeroes.

```python
myNumber = 0b00110011

FlipToZero = 0b00000000
# aka FlipToZero = 0b0

myNumber &= FlipToZero
# Remember that the &= is equivalent to saying:
# myNumber = myNumber & FlipToZero
# so myNumber = 0b00000000
```

### OR'ing will Flip to All Ones or Copy

You can use a logical OR to flip something to all ones, or copy similar to the AND function.

```python
myNumber = 0b00110011

# to flip the right-most portion of this byte to all 1's,
# you can OR this number with the following
FlipRightToOnes = 0b00001111

myNumber |= FlipRightToOnes
# Now myNumber = 0b00111111
```

### XOR'ing a Number by Itself Will Return Zero

AKA eXclusive OR. This is generally useful in things like Assembly when you need to zero out a register or something, but hey it works in python in a pinch.

```python
myNumber = 0b00110011

myNumber ^= myNumber
# Now myNumber = 0b00000000
```

And of course, XOR is a fundamental aspect of cryptography, but still it's worth noting that it can flip a value straight to zero.

### Shifting Left and Right

Bit Shifting will move all bits left, padding the right side with zeroes, and shifting right will move all bits to the right. Simple as that.

```python
myNumber = 0b00110011

# Shift everything to the left by 2
myNumber <<= 2
# myNumber = 0b11001100

# Shift it back to the right by 2 again
myNumber >>= 2
# myNumber = 0b00110011

# So for fun, we can now move everything to the left
# and fill in with ones using OR.

myNumber <<= 2
# myNumber = 0b11001100

myNumber |= 0b11
# myNumber = 0b11001111
```

## Conclusion

Hopefully I've managed to shed some light on the mystery of working with bytes in Python. I'll add to this document as much as I can if I find out other neat tricks!
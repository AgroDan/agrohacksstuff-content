---
layout: post
title: Pseudo Random Number Generators (and why you should tread lightly)
date: 2021-03-21 15:54 -0400
categories: [Crypto]
tags: [crypto, psuedorandom, mersenne twister, mersenne]
---

I've always had some sort of weird nerdy interest in pseudo-random number generators. How is it that a computer, an object based solely on a deterministic approach to everything, can generate a number that is supposedly *random*? Well TL;DR, it simply can't. Well, not without relying on external factors that are *unreasonable* to predict. One such example is Linux using things like timing of keystrokes and mouse movements, and other such readings from hard-to-predict motions of the internal mechanisms of the hard drive to generate enough entropy to generate a seed. Well, I hope to clarify this a bit.

## Introductions

First, I'd like to say that I do not have a degree in mathematics, or even cryptography. I have a general interest in it of course as it's essentially the nature of my professional career. So take what I say how you will. I'm an enthusiast, and frankly I just learned this so this is more of a scribbling of my own notes. Still though, a shout out to the [Cryptopals](https://cryptopals.com) challenge for really driving my interest in this home.

So...what is a random number generator? Well it's kind of easy to think of a random number. Just pick any number from one to 100,000,000. Predicting this is impossible without outside interference, and choosing one is simple. Not really the case with a computer. Computers are deterministic by nature: You give it parameters, it generates output based on those inputs. That output will be the same every single time as long as the inputs are the same and there are no outside influences acting to manipulate the data during processing. This is by design. So how can a system generate a random number, and why is this necessary?

### Uses

Random numbers are used in video games, used to control computer-controlled characters to simulate artificial intelligence, simply that you're not supposed to predict a pattern. They're used in cryptography a LOT. In fact, a random key was generated to encrypt the transmission of the page you're reading right now. It's random so that it can't be guessed. If it were sequential...well then if I found out that the key was created with a hash of the number 1000, I know that the next key generated will be a hash of 1001, then 1002, and so on. I can decrypt all traffic the server uses now! So obviously, a random key should be generated such that I can't simply guess it. Hence, RNG's.

So how does a computer generate a random number? Well there are a ton of functions that do it, but to simplify it I wrote a truly terrible pseudo-random number generator in Go. You are free to use it for whatever means you'd like, but...don't. Ever.

```golang
func gen_random(seed int) int {
    rng := seed*3  // mult by 3
    rng *= 42      // mult by 42
    rng >>= 1      // bitshift-right by 1
    rng %= 10      // modulo by 10
    return rng     // send it!
}
```

This is a PRNG that takes a number given to it (known as a seed), does some really dumb calculations on it, and returns a number between 0 and 9, "randomly." Well, more accurately it returns a number between 0 and 9 "reasonably unpredictably." You can probably do some of the calculations on pen and paper if you really cared, but the takeaway from this is that it's meant to obscure the output, given an input. Feed it a number, and it will return a different number. Feed it the same number twice, and it will return the same output twice. The seed is absolutely necessary to call a PRNG.

General usage dictates that if you're calling this random function over and over again, you'd simply use the number it generates as the seed for the next iteration of the function call. This is common practice. Only...it will always return a number between 0 and 9, and eventually it will just loop and repeat. In fact, eventually it generates a complete pattern.

Take, for example, this loop:

```golang
package main
import (
    "fmt",
)

func main() {
    var rnd int = 1
    for i:=0; i<50; i++ {
        rnd = gen_random(rnd)
        fmt.Println("Iteration", i, "result:", rnd)
    }
}
```

And the result:

```text
Iteration 0 result: 3
Iteration 1 result: 9
Iteration 2 result: 7
Iteration 3 result: 1
Iteration 4 result: 3
Iteration 5 result: 9
Iteration 6 result: 7
Iteration 7 result: 1
Iteration 8 result: 3
Iteration 9 result: 9
>>>>>>>>>> snip <<<<<<<<<<
```

Notice how the result starts to repeat. 3, then 9, then 7, then 1, back to 3 and repeating forever. Suddenly not so random anymore. Patterns always emerge. And now we know if we ever generate a 7 for example, the next number will predictably be 1.

So...how do you automatically generate a seed that generates a random number? Typically what's done is to use the current epoch time or something. That way every time the random number generator is initiated, the number cannot possibly be guessed. Or can it?

Let's put a pin in that. First, I want to talk about MT19937, or the Mersenne Twister.

## The Mersenne Twister

I won't go into the whole idea about what the Mersenne Twister is and how it came to be. You can look that up on [Wikipedia](https://en.wikipedia.org/wiki/Mersenne_Twister). Just understand that it was created by two Japanese math geniuses back in 1997 as a means of fixing the flaws of older PRNGs, and that it's actually *really good*. So good that many, many, MANY software systems have adopted it as the de facto PRNG formula. What makes it so good? Well, it wasn't patented, and it's permissively-licensed, so anyone can use it for free! Plus it has a period of `(2**19937)-1`, which is just a gigantic number. It's so big it absolutely dwarfs the scientific estimate of atoms in the *known universe.* Seriously, go into a python prompt and type `10**82` and then `(2**19937)-1` and see how much bigger the period is. It's tremendous.

Anyway, here is my implementation of the MT19937 function, written in python! This was based on the pseudocode posted on wikipedia:

```python
class MT19937():
    # If this is unseeded, I will seed with the C constant
    # of 5489 since you're too lazy to do it yourself you bum
    def __init__(self, seed=5489):
        # HERE BE CONSTANTS
        self.w = 32 # word size, in num of bits. Max length of each number in the array
        self.n = 624 # degree of recurrence
        self.m = 397 # middle word, offset of recurrence relation defining the series
        self.r = 31 # separation point of one word, or num of bits of lower bitmask
        self.a = 0x9908b0df # coefficients of rational normal form twist matrix
        self.u = 11 # additionall MT tempering bit shifts/masks
        self.d = 0xffffffff # additionall MT tempering bit shifts/masks
        self.s = 7 # TGFSR(R) tempering bit shift
        self.b = 0x9d2c5680 # TGRSR(R) tempering bit masks
        self.t = 15 # TGFSR(R) tempering bit shift
        self.c = 0xefc60000 # TGRSR(R) tempering bit masks
        self.l = 18 # additionall MT tempering bit shifts/masks
        self.f = 1812433253 
        # Declare the array of zeroes to start
        self.MT = [0 for _ in range(self.n)]
        self.lower_mask = (1<<self.r)-1
        self.upper_mask = (1<<self.r)
        self.index = self.n+1
        self._seed_mt(seed)

    def _seed_mt(self, seed):
        self.index = self.n
        self.MT[0] = seed
        for i in range(1, self.n):
            t = self.f * (self.MT[i-1] ^ (self.MT[i-1] >> (self.w-2))) + i
            self.MT[i] = t & 0xffffffff

    def _twist(self):
        for i in range(0, self.n):
            x = (self.MT[i] & self.upper_mask) + (self.MT[(i+1)%self.n] & self.lower_mask)
            xA = x >> 1
            if not (x%2) == 0:
                xA = xA ^ self.a
            self.MT[i] = self.MT[(i+self.m) % self.n] ^ xA

        self.index = 0

    # extract a tempered value based on MT[index]
    # calling twist() every n numbers
    def extract_number(self):
        if self.index >= self.n:
            if self.index > self.n:
                # This was never seeded. So seed with
                # the C constant for unseeded gen
                self._seed_mt(5489)
                # Truthfully though, I don't think we
                # will ever hit here without some serious
                # code-mucking but I'll keep it in here
                # just for those people that do this
            self._twist()

        y = self.MT[self.index]
        y ^= ((y >> self.u) & self.d)
        y ^= ((y << self.s) & self.b)
        y ^= ((y << self.t) & self.c)
        y ^= (y >> self.l)
        self.index += 1
        return y & 0xffffffff
```

Admittedly, the above is...a little confusing to just pick up and get. Trust me I scratched my head for quite some time before I finally got it. There is a lot of math, obviously, and more specifically a lot of bitwise operations. There's XORs, and ANDs, and bitshifting left and right, modulos for days and some questionable usage of oddly-chosen constants. But the takeaway here is that the usage is relatively simple:

 - Initialize the object with `rando = MT19937(<some number>)`
 - Get a random number with `rando.extract_number()`

There. Easy peasy. It will spit out a 32-bit (or 10 digit) random number. Or technically a pseudo-random number I guess. Ok cool, this seems pretty secure. So does this solve all of my problems?

Of course not!

## Defeating PRNGs

Remember, that for all it's confusing math, a PRNG is solely reliant on the seed generated from it. To demonstrate, this is an example of two variables I created, two separate objects given the same seed:

```text
In [14]: r = MT19937(123123123)
In [15]: a = MT19937(123123123)

In [16]: r.extract_number()
Out[16]: 3278597328

In [17]: a.extract_number()
Out[17]: 3278597328
```

...and they spit out the same number. In fact if I keep asking them to extract numbers, they will return the same pattern 1 for 1 with 100% accuracy.

So how can this be defeated? Say you're a developer, and you seed your PRNG with the current timestamp, surely nobody can predict the next number generated with something so obscure than that, can they? Well it can be predicted. And don't call me Shirley.

Take the following code:

```python
import random
import datetime
from time import sleep
from math import floor

waittime = random.randrange(40, 1000)
print("Sleeping...zzzzzzz")
sleep(waittime)

# Seeding...
ts = datetime.datetime.now().timestamp()
ts = floor(ts)
r = MT19937(ts)
rand_num = r.extract_number()
waittime = random.randrange(40,100)
sleep(waittime)
print(f"Randomly generated number: {rand_num}")

print("Now attempting to discover the seed...")
curr_timestamp = floor(datetime.datetime.now().timestamp())

outtatime = curr_timestamp - 5000

for i in range(outtatime, curr_timestamp):
    attempt = MT19937(i)
    if attempt.extract_number() == rand_num:
        print(f"We have a match! The discovered seed is {i}!")
        break
```

This was my solution to challenge 22 on Cryptopals (spoiler alert, sorry). The challenge was to generate a random number using MT19937, seeded with a random timestamp between now and about 15 minutes or so, then attempt to discover the seed based on my knowledge (or in a realistic scenario, a guess) of how the seed is generated. It simply generates a range of timestamps from 5000 seconds ago to now, then brute forces every single one by using it as the seed for the PRNG, then comparing each extracted number with the one I was given. Once it starts brute forcing, it takes about 10 seconds or so to finish. If I can brute force it this fast, then...maybe you shouldn't be using just a PRNG result seeded with the current timestamp as the key to whatever encryption method you are using.

But then, this isn't specific to the Mersenne Twister. Really any PRNG will do this. One thing that the MT does is the `extract_number()` function doesn't take any arguments, which is odd because my absolutely terrible `gen_random()` function takes an integer as the seed for every call of the function. So you have to seed it every time. How does MT19937 do it if it only accepts one number? Does it just re-seed itself with the number it last generated?

**NO**

Definitely not. Because if it did, you could simply use the number it last generated to predict the next number out of the function. This does not a good PRNG make. Again, `gen_random()` is a terrible PRNG, because if I feed the number 3 to it, I will always get 9. Then 7, then 1, then 3 again. MT19937 has a built-in safeguard against it, but to understand it I need to explain it more.

### Mersenne Twister Deep Dive

What happens when you execute the Mersenne Twister? Well, first when you initialize it, you must initialize it with a seed. Then what happens?

1. It builds an array of size 624, for the sake of simplicity I will call it MT.
2. It sets MT[0] to the seed you provided.
3. For every index after MT[0], it:
  - Right-shifts `MT[i-1]` with the constant `30`
  - XORs the result with `MT[i-1]`
  - Multiplies the result with the constant `1812433253`
  - Adds the result with `i`
  - ANDs the result with `0xffffffff`, ensuring the result is only 32 bits long

Now it has its state array! This is basically how the Mersenne Twister operates. Whenever you extract a number, you are literally just pulling from this state array.

But that's not where it stops. You'd think it is jumbled up enough, but it gets even crazier.

The first time you extract a number, it performs the `_twist()` function on its state array. This function does pretty much what you'd think it does: it jumbles up the state array even worse than before. I won't get into the specifics of what it does, because it's kind of not worth knowing in this context. Just understand that the `_twist()` function simply runs through the current state array, jumbles up every single number with some pretty heavy bitwise math operations, and leaves you in a state of complete pseudo-randomness. Basically, a "you can't get there from here" scenario.

Now that the state array is all messed up beyond recongition, we still need to extract a number! The `_twist()` function happily sets the internal index to point back to `MT[0]` and lets you extract that number. Man, that's pretty random. But it looks like our job here is done. Since we just called the `extract_number()` function, all it needs to do is simply spit out the number that the internal index is pointing to (in this case, `MT[0]`), then just increment the index by 1. We can run this function indefinitely, because the `extract_number()` function has a built-in safeguard that when the index hits over 624, it re-runs the `_twist()` function, jumbles up the state array all over again, then sets the index back to zero. Since the MT19937 function has a period of...a really *really* long cycle, we don't expect this to repeat its cycle anytime before the cold, cold heat death of the known universe, so we have an indefinite random number generator! Woo!

Except that would be bad. And in case you're a bit fuzzy on the whole good/bad thing, you should try to imagine all life as you know it stopping instantaneously and every molecule in your body exploding at the speed of light.

Well maybe not that bad. But if we just sit back and collect every single number that the `extract_number()` function spits out, we can simply build our own state array ourselves...then run our own `_twist()` function on it when you do. I can then predict with 100% accuracy the result of every single random number you generate from this point forward.

So yeah. That's bad.

Luckily, MT19937 has an ace in its sleeve: Tempering functions!

The `extract_number()` function doesn't just spit out the number it has in its state array at the index. It extracts it internally, runs it through a few calculations, then spits out the result, effectively masking the contents of the state array from the receiver.

These are the actions taken whenever `extract_number()` is called:

```python
y = self.MT[self.index]
y ^= ((y >> self.u) & self.d)
y ^= ((y << self.s) & self.b)
y ^= ((y << self.t) & self.c)
y ^= (y >> self.l)
self.index += 1
return y & 0xffffffff
```

To clarify:

1. set the variable `y` to `MT[index]`
2. `y` is then shifted right 11 bits, AND'd with `0xffffffff`, then XOR'd with `y`
3. `y` is then shifted left 7 bits, AND'd with `0x9d2c5680`, then XOR'd with `y`
4. `y` is then shifted left 15 bits, AND'd with `0xefc60000`, then XOR'd with `y`
5. `y` is then shifted right 18 bits, and XOR'd with `y`
6. index is increased by 1
7. The tempered value of `y` is then AND'd by `0xffffffff`, which simply shortens it to 32 bits long (or 10 digits, thereabouts)

Yikes. Well, there's a lot of steps. And guess what! They are actually reversible! It's not easy, but they are reversible! And in theory, if you reverse these in the reverse order it goes through, then you could technically be able to determine the number it pulled from the state array and *reconstruct the same state array*. And if you do that, you can predict every single number it generates.

### Untempering the Extracted Number

There are basically two types of formulas: left shift AND, and just right shift, and both of these are XOR'd with the result of the previous formula. The formula `y ^= ((y >> self.u) & self.d)` does actually have an AND operation, but it's just ANDing it with `0xffffffff`, which mathematically doesn't do anything significant to the equation. In fact, I'm not even sure why it's even there. That said, we can feasibly ignore the `& self.d` portion. So since I'm looking to work up, I'd first like to start with `y ^= (y >> 18)`.

Bit shifting is basically this:

#### Right Shift
```text
1111 >> 1 = 111
===============

Simply shifting all digits one to the right, and ditching the right-most digit. 
Mathematically, this is the same as dividing it by two and rounding down.

5   >> 1 =  2
101 >> 1 = 10
6   >> 1 =  3
110 >> 1 = 11
```

#### Left Shift
```text
1111 << 1 = 11110
=================

You guessed it, it shifts all the digits one to the left, padding the additional
zero on the right. Mathematically it's the same as multiplying by 2.

5   << 1 = 10
101 << 1 = 1010
6   << 1 = 12
110 << 1 = 1100
```

And since I'm at it, sorry for the math people that know this already but I feel like a quick refresher on bitwise math might be worthwhile to some.

#### XOR
```text
0 ^ 0 = 0
0 ^ 1 = 1
1 ^ 0 = 1
1 ^ 1 = 0

XOR, also called NEQ or Not Equal, also called eXclusive OR, simply returns a 1
when both operands are different. This has the unique quality of operating on
relationships of threes, whereby if you take the result and XOR it with any of
the other operands, you will return the third operand. So:

A ^ B = C

as well as

A ^ C = B
C ^ B = A
B ^ A = C

and so on. XOR is the fundamental building block of all encryption! If you only
have C, then you just have C. But if you ALSO have B, then you can find out A.
```
#### AND
```text
0 & 0 = 0
1 & 0 = 0
0 & 1 = 0
1 & 1 = 1

AND only returns 1 if both operands are 1. This is useful for comparing data,
and also has the unique ability to create a mask. If you only want the first
4 digits of a number, you can simply mask it:

  1111100100101100101
& 0000000000000001111
=====================
  0000000000000000101

By ANDing a value with 0xff (or 1111), you will only return the last 4 bits of
the number. This is called a mask! Network Engineers will see this pretty
clearly. Neato!

Additionally, a quick trick to create a mask of, say, 10 bits long:

(1<<10)-1

Shifts 1 over 10 times, making it 10000000000 then subtracts it by 1 to
create: 1111111111
```
#### OR
```text
0 | 0 = 0
0 | 1 = 1
1 | 0 = 1
1 | 1 = 1

OR returns a 1 if just one operand is a 1. For our purposes, this is useful in
case I want to append a bit to the end of a number. Say I wanted to append a 1
to a number, I would simply left-shift it by 1, then OR it with a 1. So
technically, (x<<1) | 1

   111001
<<      1
=========
  1110010
|       1
=========
  1110011

Just a neat trick.
```

Now, back to the good stuff. Reversing the right shift.

The basic premise is thus: If we right shift a number by a bunch of digits and *then* XOR it with the number, then we can technically recover the bits that have been moved out of the way with the right shift right off the bat because those zeroes are XORd with the original number. So on a smaller scale, let's look at what happens with the aforementioned formula: `y ^= (y >> 18)`, only instead of using a 32 bit integer, I'll use something a lot smaller to work with, only 8 bits long. Let's say for instance, the formula is `y ^= (y >> 4)`

```text
   1100 0101     Technically, we wouldn't know this number
>>         4
============
   0000 1100
^  1100 0101     Notice here, XORing orignal with zeros = original
============
   1100 1001     First 4 bits are original bits
```

So we're halfway there. We can immediately see that the first 4 bits are the original bits. Now all we need to figure out is how to recover the remaining 4 bits. Those 4 bits have been XOR'd with the bits 4 bits to the left of it. If we
XOR each bit with the corresponding bit 4 bits to the left, we get:

```text
  1001
^ 1100
======
  0101

Append this to the recovered bits and...

  1100 0101

We recovered the original number!
```

I've coded the above mechanism in python to accommodate for the different bitshift values, also assuming that the integer we're dealing with will always be a 32-bit integer (which is specified in MT19937).

```python
def undo_right_shift(number, shift_len, max_len=32):
    """
        This function will un-do the right shift function performed in the
        extract_number() function in the Mersenne Twister. This is integral
        in building the state array to re-create the algorithm.
        number := the original number
        shift_len := the shift length stated in this function
        max_len := the size length of the random number stored. 32 bits is default.
    """
    result = number
    for i in range(0, max_len, shift_len):
        mask = ((1<<shift_len)-1)     # Create a mask of size shift_len
        mask <<= (max_len-shift_len)  # shift mask over specified amount of times
        mask >>= i                    # mask moved over more for specificity
        pulled = result & mask        # Pull the number from the result w/ the mask
        pulled >>= shift_len          # shift pulled over shift_len
        result ^= pulled              # XOR result with pulled
    return result
```

So that takes care of the two right shift formulas in the equation. Now about those pesky left-shift-and formulas...which are actually not even that bad. I will work with this formula: `y ^= ((y << 15) & 0xefc60000)`

A lot of stuff to unpack, so I'll simplify it for explanations' sake. My formula will be: `y ^= ((y << 5) & 0xbf)`

```text
            1100 1001         This is the number we're not supposed to know
<<                  5
     ================
     1 1001 0010 0000
&           1011 1111         0xbf, the made-up constant
=====================
            0010 0000
^           1100 1001         XOR to the rescue again
=====================
            1110 1001         The end result.

To reverse the above, it is essentially the opposite. First, mask off the first
5 bits as explained here

        1110 1001
&       0001 1111
=================
        0000 1001
<<              5
=================
      1 0010 0000
&       1011 1111             Now AND it again with the constant
=================
      0 0010 0000             And XOR this against the end result
^       1110 1001
=================
        1100 1001

Although it doesn't seem it, we recovered the right-most 5 bits of the original
number. We just need to repeat it in an iterative process until we hit the end.

So let's sally forth!

Mask off the first 5 bits of the above result:

        1100 1001      The result of the above
&    11 1110 0000      Masking the next 5 bits!
=================
     00 1100 0000
<<              5      Shift it 5 over again
=================
 1 1000 0000 0000
&       1011 1111      AND it again with the made-up constant
=================
   0000 0000 0000
^       1100 1001      XORing with the result of the first iteration
=================
        1100 1001      We have fully recovered the original number!
```

You can see that essentially we are working backwards, incorporating an AND with a constant that can actually be recovered against because after all, we are still XORing against the original number. XOR is fun!

The python code that I wrote for this is as follows:

```python
def undo_left_shift_and(number, and_constant, shift_len, max_len=32):
    """
        This function will un-do the left shift function, which is a little bit
        different from the right shift, mostly because there is also an AND function
        performed with two constants. However, due to some logical magic, this is
        able to be un-done.
    """
    result = number
    for i in range(0, max_len, shift_len):
        mask = (1<<shift_len)-1     # Create a mask of size shift_len
        mask = mask << i            # Shift it over <i> bits
        part = mask & result        # Create a part var, consisting of bits we masked
        part = part << shift_len    # shift it over another shift_len bits
        anded = part & and_constant # AND the part with the supplied and_constant
        result = result ^ anded     # result is XORd with above anded
    return result
```

So we now have two powerful tools in hand...and in theory, we can now "untemper" the values returned from the `extract_number()` function in the Mersenne Twister algorithm! To do that, we simply work backward with what we have. And to explain that, I also have python code written explicitly for that, calling on the functions above:

```python
def untemper(number):
    """
        This function works through the process of "untempering" a number
        to place it back into the array to duplicate the (pseudo) random number
        generation.
    """
    res = number
    res = undo_right_shift(res, 18)
    res = undo_left_shift_and(res, 0xefc60000, 15)
    res = undo_left_shift_and(res, 0x9d2c5680, 7)
    res = undo_right_shift(res, 11)
    return res
```

You didn't think I'd show up unarmed to this fight, did you?

Given any number returned from the MT19937 algorithm, running it through the above functions should return the value *that was stored in the MT object's state array*. This should pave the way for you, the attacker, to re-create the values within the state array, and begin to predict the next "random number" from the generator.

**UPDATE**: To see the above theory in action, I created [a separate post](/crypto/mt-in-action "Mersenne Twister Predictor In Action").

## In Summary

I realize this was kind of a deep dive. I don't expect very many people to care this much about random number generators. Does this mean that computers are not to be trusted? Does this mean we are doomed? No such thing exists as an actual random number generator? Should we all quit our jobs and live in solitude off the land, never interacting with the technology that defines us as a species? No. Well maybe. Or...well no. No! Of COURSE there are better ways to obtain a random number. It's all a matter of finding something that is *reasonably difficult to predict*. There are some fairly expensive computer hardware devices that measures difficult-to-predict sources of randomness, such as atmospheric interference, radioactive decay measurements of an isotope, and Cloudflare even uses [lava lamps](https://blog.cloudflare.com/lavarand-in-production-the-nitty-gritty-technical-details/). That is so freakin cool, man. [Random.org](https://www.random.org/) uses atmospheric interference to return a random number, using cosmic rays that are leftovers of the big bang. Hell, if anyone still has an analog television, tune to an unused channel and watch the static snow. That's atmospheric interference, and a true source of random entropy.

The bottom line is that PRNGs are good for many things. If you're using them to define an enemy's AI in a game you're coding, that's perfectly fine. If you're using it to generate a key for an encryption mode, then that is absolutely unacceptable. No sir. Don't do it! Bad programmer! PRNG's are exactly that: pseudo random. You cannot expect them to be truly un-predictable. That said, there are significantly better cryptographically-secure PRNGs, and in fact you could probably make MT19937 even better by modifying the tempering function to include a one-way hash which should prevent anything like what I just developed. But the bottom line is that it's still deterministic, and thus still *technically possible*. So...keep that in mind I suppose.

And that, *Corey*, is why I choose to roll my own dice during D&D, *thankyouverymuch*.
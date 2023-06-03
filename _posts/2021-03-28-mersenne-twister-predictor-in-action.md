---
layout: post
title: Mersenne Twister Predictor In Action
date: 2021-03-28 15:52 -0400
categories: [Crypto]
tags: [random number generator, psuedorandom, crypto]
---

In a [previous post](/crypto/mt "Pseudo Random Number Generators (and why you should tread lightly)"), I explained the very broad mechanism of what to do to predict the Mersenne Twister pseudo-random number generator. I only posted the functions but never actually showed them in action. That said, I have spun up some proof-of-concept code to explain how it can be used in practice. Given 624 samples of extracted pseudo-random numbers from one seed, I can re-create the state array and predict every single number generated from this extraction.

Before I begin however, I don't want to be the first to claim this, as I mentioned this is hardly ground-breaking. If you want code to do this for a CTF or something, [kmyk's mersenne twister predictor](https://github.com/kmyk/mersenne-twister-predictor) is a lot more of a mature project you can use. In fact it shows how you can use this against Python's own `random` library.

Now, I have a github repository for just this page. Using the code in [this repo](https://github.com/AgroDan/MT_shenanigans), I can first create an MT19937 object, and I will seed it with the value of 31337.

```python
import mersenne

m = mersenne.MT19937(31337)
```

Okay. Now I can obtain a pseudo-random number by using `m.extract_number()`. Using iPython3, I can get the value like so:

```text
In [3]: m.extract_number()
Out[3]: 3100331191
```

Based on my last post about this, I mentioned that this extracted number isn't just pulled from the state array. Rather, it's tempered through a series of formulas that make it difficult (but not impossible!) to revert back to its original state. Remember that if it just spits out the numbers in its state array, the array can simply be re-created and used to predict future numbers generated.

So to refresh, when the `extract_number()` function is called, these are the gauntlet of tempering functions the number in the state array goes through to bring you a brand new number:

```python
y = state_array[index] # assign y to the current number in our state array
y = y ^ ((y >> 11) & 0xffffffff)
y = y ^ ((y << 7) & 0x9d2c5680)
y = y ^ ((y << 15) & 0xefc60000)
y = y ^ (y >> 18)
index = index + 1
return y
```

I wrote a couple of functions that work on undoing the right shift, as well as undoing the left shift as well as the AND'd number. I went into more detail about the specifics in the previous post, but for the sake of preservation, these are the two functions specific to undoing the above:

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
        mask = mask << i                  # Shift it over <i> bits
        part = mask & result        # Create a part var, consisting of bits we masked
        part = part << shift_len          # shift it over another shift_len bits
        anded = part & and_constant # AND the part with the supplied and_constant
        result = result ^ anded             # result is XORd with above anded
    return result
```

Now with these functions in our arsenal, I will go over step-by-step to recreate that number from the state array. Given the extracted number from before, I will use `3100331191`. And the first formula to undo should be: `y = y ^ (y >> 18)`.

```python
# The number the function requires is what we have so far (3100331191), and
# the shift_len refers to how many bits are shifted right. In this case, it
# is 18 bits.

step1 = untwist.undo_right_shift(3100331191, 18)
```

The value of step1 becomes: `3100336773`. Now the next formula in line is: `y = y ^ ((y << 15) & 0xefc60000)`.

```python
# In this case, the 'number' is 3100336773, the and_constant is 0xefc60000,
# and shift_len is 15. I can use the "step1" variable, but for clarity I will
# use the straight up value.

step2 = untwist.undo_left_shift_and(3100336773, 0xefc60000, 15)
```

The value of step1 becomes: `428434053`. Next formula is another left-shift-and: `y = y ^ ((y << 7) & 0x9d2c5680)`.

```python
step3 = untwist.undo_left_shift_and(428434053, 0x9d2c5680, 7)
```

Step3 is now `2376687621`. The final formula is `y = y ^ ((y >> 11) & 0xffffffff)`, which is a right-shift as well as an AND against a 32-bit mask, which doesn't actually do anything of any significance to the result of the right-shift, so we don't need to add anything new to the undo-right-shift code to accommodate it.

```python
step4 = untwist.undo_right_shift(2376687621, 11)
```

And finally, step4 has the value: `2377701151`. This is the final formula, and if we did everything right, step4 should be equal to `m.MT[0]`. Using iPython3, I can show this:

```text
In [1]: import mersenne, untwist

In [2]: m = mersenne.MT19937(31337)

In [3]: m.extract_number()
Out[3]: 3100331191

In [4]: untwist.undo_right_shift(3100331191, 18)
Out[4]: 3100336773

In [5]: untwist.undo_left_shift_and(3100336773, 0xefc60000, 15)
Out[5]: 428434053

In [6]: untwist.undo_left_shift_and(428434053, 0x9d2c5680, 7)
Out[6]: 2376687621

In [7]: untwist.undo_right_shift(2376687621, 11)
Out[7]: 2377701151

In [8]: m.MT[0]
Out[8]: 2377701151
```

Done! So to wrap that all up into one function that performs all those untempering functions, I wrote `untemper()`:

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

Now, all I need to do is write some code to read in the next 623 iterations of the PRNG, untemper them all, and then I can rebuild my own state array!

```python
# Import our untwist module
import untwist

# just for preservation, I will save the result of that first extraction
first_ext = 2377701151

# Now extract the next 623 numbers
e_nums = [m.extract_number() for _ in range(623)]

# Untemper all of these numbers
u_nums = [untwist.untemper(i) for i in e_nums]

# Don't forget to stuff that first number at the top
u_nums = [first_ext] + u_nums

# Our new state array is u_nums! We can create a new MT19937 object
# and mess with some of the internals because python

x = mersenne.MT19937(0)    # doesn't matter what I seed it to
x.MT = [i for i in u_nums] # Rebuild the state array
x.index = 624              # set the correct index

# Our new object, x, is the exact same MT19937 object as m, sharing the
# same state!

x.extract_number()
m.extract_number()
# returns 4157184560 for both
```

I created a function that encapsulates the above as an object. Simply run `untwist.preseed([<state array>])` and it will return a MT19937() object with that new state array as I've done here.
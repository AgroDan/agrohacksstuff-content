---
layout: post
title: Vim Tricks
date: 2021-09-15 16:02 -0400
categories: [Cheat Sheet]
tags: [vim, cheat sheet, nano is for quitters, vi master race]
---

Vim (short for Vi-IMproved) is the greatest editor. Some may try to convince you that Nano is the greatest, some would say Notepad++, some would even say Emacs. These people are wrong. If anyone tells you that Nano is better than Vim, do not trust this person with answering important questions because if they won't state that Vim is the greatest editor, then what else are they hiding?

Kidding. The whole "Vim vs. Emacs vs. Nano" debate has raged on in some of the oldest forums, ruffling the feathers of the Unix graybeards since long before I was even messing around with computers. But I have been hooked on Vim since I was told I *have* to use it at that one class I took in college. I struggled through it like most of us have in the beginning, stuck in "Vim Jail" trying to figure out just how to close out of it cleanly, until I just tried to learn it, and now it's so ingrained in my muscle memory that it's become a part of my daily routine. Going to edit a file? Vim. Create a file? Vim! View a file? VIM!

## Why Vim?

I was a Unix System Administrator before I become a Cyber Security professional. When you're a sysadmin, you jump from server to server, with a new shell environment everywhere you go. Forget your own fancy `.bashrc` file, unless you have some crazy profile mounting/syncing setup, you log into a server and you get the bare-bones environment everywhere. But there was one consistency on every single server I ran: they all came with vim pre-installed. Nano was there too, but if I'm to date myself, nano wasn't even a thing back when I started. It was called Pico, and it only existed when [Pine](https://en.wikipedia.org/wiki/Pine_(email_client)) was installed. Eventually Nano was made in parallel to Pico, and that became the standard text editor most people starting out would use, mostly because it was simpler. But to those of you using Nano, I urge you to give Vim a shot. Use it for a month. Learn how to use it. Honestly, the best way to learn is to use the built-in `vimtutor` command. One of the biggest pluses that vim has to other editors is you never need to leave the 'home' position while typing! Not even to move around the document!

In this cheat sheet, I won't discuss any of the basics, mostly because you can learn it all from that `vimtutor` application, but this will be made to demonstrate some of the more fun tricks you can do with Vim.

## How to quit Vim

Despite this being an "advanced" vim tricks cheat sheet, I have to include this here because this may or may not have been an interview question I have personally asked candidates in the past.

![Join us, user. We can be together forever and ever and ever and ever...](/assets/img/vimtricks/howtoquityou.gif)
_Join us, user. We can be together forever and ever and ever and ever..._


 1. Hit `Esc` to enter `command` or `ed` mode.
 2. Type any of the following:
     * `:q` to quit, though this may error out if you made any changes.
     * `:q!` to force quit. This will not save any changes!
     * `:wq` To Write-Quit. Save and exit.
     * `:wq!` Force Write-Quit. If file only has read permission this will attempt to force write. Doesn't always work.
     * `:x` Similar to Write-Quit. Won't write anything if no changes though.
     * `ZZ` (note no :) -- will also Write-Quit.

Without this knowledge, a common first-time vim user will typically have a command history that looks like this:

```text
exit
q
quit
^C
^C^C^C
^Z
disown
```
*Kill it and let the OS figure it out!*

## How to comment out multiple lines

This is something I use quite often.

 1. First, make sure you are not in edit mode: `Esc`
 2. Enter Visual Block Mode `CTRL-v`
 3. Use up/down arrows to highlight what you want to comment
 4. Enter 'Insert at Beginning of Line': `SHIFT-i (capital I)`
 5. Enter the text you want, like `#`
 6. Press Esc twice: `Esc + Esc`

## How to copy/paste an entire line or block of text

Not so advanced, but something that's worth knowing.

 1. Make sure you are in command mode by hitting `Esc`.
 2. Select content you wish to cut/copy with the arrow keys (or `h,j,k,l` for you connoisseurs).
 3. Hit `Shift-V` to highlight an entire line, or just `v` to highlight characters at a time
 4. Hit `y` to copy or "yank", otherwise hit `d` to cut or "delete".
 5. Move the cursor anywhere else and type `p` to paste what you just copied or cut!

## Auto Completion

Yeah, Vim has auto-complete. Because of course it does.

If you've typed a word before, you can start typing that word again in edit/insert mode, then type `CTRL-n` to auto-complete. It will search back in your document for the most relevant match.

The best part of this is that if you hit `CTRL-n` and it finds multiple possibilities, it will graciously provide you with a pulldown menu of all possibilities.

You can also just use `CTRL-p` to pick the most recently found match without giving you a popup, because odds are you are referring to the most recently typed word.

## Simple Math

Yup. You can even perform simple math in Vim.

While you are in insert/edit mode:

 1. Hit `CTRL-r`. It will insert a `"` character.
 2. Type `=`, your cursor will move to the bottom of the screen.
 3. Type in some math you want performed, like `50*2`.
 4. Hit `Enter`. It will replace the `"` character with `100`.

## Working with Vim Registers

Vim can save copied data to multiple named registers.

### To copy text to a register named "a", highlight it in visual mode and hit:

    `"ay`

That's a double quote, a, and y.

  * `"` -- Tells Vim to work with its registers
  * `a` -- Tells Vim we are working with the named register `a`.
  * `y` -- Yank what is selected.

You can also not enter visual mode and simply type `yy` to yank the entire line. Or capital `Y`. You would simply prepend `"a` to `yy` or `Y`, making it `"ayy` or whatever. Do not append "lmao", that is a meme and would be incompatible with Vim.

### Then, to paste the contents of that register, in insert mode:

`CTRL-r + a`, that's `CTRL-r` followed by simply `a`.

Remember the `CTRL-r` key sequence to begin working with registers. Easy to remember, 'r' for registers.

Forget what's in your registers? Hit `Esc` to enter command mode and type `:reg` and hit `Enter`

## Macros

Macros are one of the most powerful features of Vim that sadly not many people know how to use. Hopefully I can demystify it a bit.

Do you want to perform some action a bunch of times that is fairly complex but otherwise is repetitive? Macros!

For the sake of a real-world example, let's say I want to add a comma to the end of every line. At the beginning of the first line I have to start recording exactly what I want to do, so I type the following:

`qa`

Where:

 - `q` -- Tells Vim to start recording a macro
 - `a` -- Name of the Macro. This can be any character, but `a` is typically what I go for.

Now perform your action. So since I want to add a comma to the end of the line...

 `$a,<ESC>j0q`

Which in Vim:

 - `$` -- Move cursor to the end of the line
 - `a` -- Change to insert mode, insert after word
 - `,` -- insert a literal comma
 - `<ESC>` -- Type `Esc` to changed back to command mode
 - `j` -- move down one line
 - `0` (zero) -- move to the beginning of the line
 - `q` -- Stop recording the macro

Now that your macro is saved to the `a` buffer. To recall that buffer, you type `@a`, and to perform it a bunch of times, type something like `500@a` which will run the `@a` macro 500 times.

## Copy output of shell command to current document

Want to run some arbitrary command and paste the results into your vim document? Just like performing simple math, you can run a shell command and immediately paste the contents of STDOUT to the current document.

 1. In insert mode, type `CTRL-r`
 2. Type `=`, your cursor will move to the bottom of the screen
 3. Type `system("ls")<ENTER>`

It will then print the output of the `ls` command to your current document!

## Split windows

You can split windows in vim. By default, it will split the window in the same document. You can open a new document by hitting `Esc` to enter command mode, then typing `:e <name_of_document>`. All Window-split operations are preceeded by `CTRL-w`. Easy to remember, 'w' for 'windows.'

### Split Vertical

Start a window split vertically with `CTRL-w v`, 'v' for "Vertical."

### Split Horizontal

Start a window split horizontally with `CTRL-w s`, 's' for "sideways" I guess?

### Move between Panes

Understanding that Vim uses `h`, `j`, `k`, and `l` as arrow keys, you can move to other panes with `CTRL-w <direction>`, or you can even use the arrow keys to move as long as you hit `CTRL-w` beforehand.

### Resize a pane 

You can expand a pane to fit [most of] the window horizontally by typing `CTRL-w |` (that's a pipe).

You can expand it vertically by typing `CTRL-w _` (that's an underscore)

You can reset it completely with `CTRL-w =`

You can increase the size of the pane by one character with `CTRL-w +`

You can decrease it with `CTRL-w -`

### Close a pane

You can close a pane like you would any document. Hit `Esc` to enter command mode, then quit using `:wq` or something similar.

### Copy/Paste between windows

This is somewhat assumed but I figured I would mention it anyway. Simply highlight text as stated above, move to another pane with `CTRL-w h/j/k/l`, then paste as normal.

## Conclusion

This is just a small taste of the capabilities of Vim. I've been using it for over 15 years and I am still learning new tricks. [NeoVim](https://neovim.io/) is also a viable alternative for those who really like Vim but want a different approach to it, but I tend to gravitate towards straight-up Vim because of its ubiquity. Again, if you're a sysadmin that spends a lot of time on many other servers and you really like NeoVim, then you'll have to install it on every single server you want to run it from, while Vim is typically just *there*.

I should add a disclaimer though that if I am going to get involved with a larger-scale project I will tend to gravitate towards a GUI-based IDE like Sublime/VSCode/Pycharm, so basically NeoVim would be for people that just don't like any of the aforementioned choices and want an extensible Vim platform to install plugins with. To that end, I suppose NeoVim is mostly for people that like to let you know that they prefer to work on the command line. Hey, how do you know if someone prefers the command line over a GUI?

Don't worry, they'll tell you.

...kidding!
---
layout: post
title: User Account Control Lookup
date: 2021-08-17 16:06 -0400
categories: [Cheat Sheet]
tags: [uac, windows, user account control, python]
---

I created a little web app useful for looking up the User Account Control values displayed in a standard LDAP query from Active Directory. Most of the time this integer is obscured from the viewer because Microsoft does the bitwise translation for you before presenting the values to you from the GUI, in a standard LDAP query this is displayed as just an integer.

The tool I wrote can be accessed here: [uac.agrohacksstuff.io](https://uac.agrohacksstuff.io/).

This is particularly useful if you are on an engagement on a non-windows machine and you are investigating artifacts in AD. While most scripts will perform this translation for you, this serves as just a quick review of an account from LDAP to determine particularly alarming/interesting values such as `DONT_REQ_PREAUTH` or `TRUSTED_FOR_DELEGATION`. I couldn't find any quick wins in a language that I had easy access to (python, that is), so I not only wrote it in python, but also made it a web app that anyone can use.

This value is actually a series of flags as bits, which can more accurately be represented as an integer. Where `10010` in binary is `18` in decimal and can be represented as such, Microsoft treats this value as a series of flags, where the first `1` on the left in the bit-string is the `LOCKOUT` flag, and the second-to-last bit is the `ACCOUNTDISABLE` flag, so a UAC value of `10010` has two flags, `[LOCKOUT, ACCOUNTDISABLE]`. Specifically, the list of values from the script are written as such:

```python
uacTable = { 1: "SCRIPT",
             2: "ACCOUNTDISABLE",
             8: "HOMEDIR_REQUIRED",
             16: "LOCKOUT",
             32: "PASSWD_NOTREQD",
             64: "PASSWD_CANT_CHANGE",
             128: "ENCRYPTED_TEXT_PWD_ALLOWED",
             256: "TEMP_DUPLICATE_ACCOUNT",
             512: "NORMAL_ACCOUNT",
             2048: "INTERDOMAIN_TRUST_ACCOUNT",
             4096: "WORKSTATION_TRUST_ACCOUNT",
             8192: "SERVER_TRUST_ACCOUNT",
             65536: "DONT_EXPIRE_PASSWORD",
             131072: "MNS_LOGON_ACCOUNT",
             262144: "SMARTCARD_REQUIRED",
             524288: "TRUSTED_FOR_DELEGATION",
             1048576: "NOT_DELEGATED",
             2097152: "USE_DES_KEY_ONLY",
             4194304: "DONT_REQ_PREAUTH",
             8388608: "PASSWORD_EXPIRED",
             16777216: "TRUSTED_TO_AUTH_FOR_DELEGATION",
             67108864: "PARTIAL_SECRETS_ACCOUNT",
            }
```

You can access the source code [here](https://github.com/AgroDan/uac_lookup).
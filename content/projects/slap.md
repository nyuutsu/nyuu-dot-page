---
title: "slap"
icon: "🩹"
description: "Multi-format rom patcher"
weight: 1
---

::: {.tip title="context"}
A rom patcher takes a game file and applies a "patch" file to it. The patch is a recipe for turning the original file into some sort of variant of itself, such as a translation, a bugfix, or some other romhack thing. By convention, the way to distribute your game-modding work is to make and distribute a patch meant to be applied to the original.
:::

I made a rom patcher. It's good. It's free/FOSS, multiplatform, supports twenty formats, cute, fast, and makes small patches.

I built it because I couldn't find a CLI tool, available on Linux, that I cared for, that would play nice with applying the patches I needed to prep my [FXPak](https://retrorgb.com/fxpakpro.html). So it is in part built for scripting nicely. But it is also very chatty. It has structured errors/warnings/observations for all sorts of things.

It assumes nothing about a patch. I am fairly confident that it'll handle anything that *isn't invalid* gracefully; if something is malformed, or coherent but about to do something surprising, slap says exactly what and where.

Try it: [cli version](https://github.com/nyuutsu/slap/releases), [web version](https://slap.nyuu.page/). It is written in Haskell and Rust and this made getting it to work nicely in the browser, interesting.

It knows six verbs:

- **apply** — patch + original rom → modified rom

- **create** — two ROMs → patch

- **undo** — patch + modified rom → original rom

- **convert** — patch in one format → patch in another

- **explain** — patch → human-readable statement of what it does

- **info** — patch → its metadata

# appendix

## correctness

For any *realistically likely to actually exist* patch, "we can apply it, correctly" is of course a given. But what are the outer edges of what is acceptable? For each format we had to ask, for "property X":

- is property x a 'spec' thing?

- an idiosyncratic up-to-the-applier kind of thing?

- a wire capability that is nonetheless *not* part of 'the spec'?

some:

> What counts as a well-formed IPS patch? Can the records overlap? Can they be non-monotonic? If the answer to both is "yes" then this makes applying it at least less obvious than it might have at first seemed. What does it mean to honor the truncation marker if it is saying to "truncate" to a size that is larger than the input file?

> IPS can't address past 16MiB, so barring some weird edge case about only modifying the start of a file: IPS can only describe changes in files up to 16MiB. *Ish*. It can't *see* past 16MiB, but it can describe a record that *begins* in-bounds but writes moderately past that point, beyond 16MiB. This is *coherent*, has *predictable results*, and is *super weird*. Is it "in spec"? Of course we'll apply these but do we agree to create them?

> EBP supports JSON metadata, which it uses to store four strings. The expressive power is much greater than what is actually being done with it. Is "the spec" *something is wrong if there is anything present in addition to the strings*? Is it the reverse: arbitrary infinite nesting? Can we at least figure that it *must* be UTF-8?

> NINJA2 has this cool "normalization" thing, where if the input rom is not already in a "normal form" (deinterleaved, no header, z64 byte order if N64, etc), the patcher is supposed to put it in that form. If the patch says to apply normalization procedure foo, and the patcher doesn't know procedure foo (this is actually not contrived), it refuses to apply. The issue is: this format does also store checksums, of the input. The checksum is against the *normalized form* of that input. It seems to me like this is too conservative and we should at least check whether the input file is *already* in the expected shape, before giving up. Can I have my tool *do* that or is that me doing "embrace / extend / extinguish"?

> BPS appears to allow "copying stuff from other parts of the output, before anything has been put there". Is this coherent or no?

> PPF3 doesn't track file sizes, and allows undo. The wire can describe growth, but in a way where if you do so, undoing becomes incoherent. The OG tool looks to me like it intends to block actually doing growth or shrinking, but in a way that I suspect didn't work. What do we *do* if the user creates a size-changing undo-bearing PPF3? What if they want to use the PPF3 undo feature; for format-structural reasons it is impossible to detect that the user is trying to truncate-via-undo.

and so on. On creation we are conservative: emit things any tool could apply just fine. On application we have attempted to support the entire "expressive range" of each format. Doing this means figuring out where "the line" is.

This meant a lot of time spent thinking about how something could go *wrong*: the wire able to represent incoherent instructions, for example. An outsized amount of that time went into making sure every way a patch can be malformed gets called by its name. If curious see [Error.hs](https://github.com/nyuutsu/slap/blob/main/src/Slap/Status/Error.hs), [ApplyError.hs](https://github.com/nyuutsu/slap/blob/main/src/Slap/Status/ApplyError.hs), and [VCDIFF.hs](https://github.com/nyuutsu/slap/blob/main/src/Slap/Status/VCDIFF.hs) for the sorts of things we watch for.

## text encoding stuff

Some formats can store text metadata. I went in expecting to find evidence in favor of some if not all of these being ASCII-only. Not so! We output UTF-8 and feel fairly confident that this is in all cases "not *wrong*". The two things we see a lot of are either "in this format, the rule is use UTF-8" (great!), or "in this format, the rule is use 'system codepage'" (whoa, what?). The latter still permits UTF-8: on a modern system, UTF-8 *is* the system codepage.

On the read/display side it is more involved. We provide a bunch of alternate decoding options in case UTF-8 is *not* how to read the patch.

We guard/sanitize what we decode/read. A few formats have metadata fields for **arbitrary data**. Not arbitrary text; arbitrary data. In practice if these fields are used at all, they are being used to store text. So we don't want to firewall these fields off from the usual display and preservation-during-format-conversion machinery, but we also don't want to read and then act on a bunch of control characters out of a suspicious embedded file. What we actually do: show everything, act on nothing. Unprintable codepoints are displayed escaped (`<U+0007>`, not a beep), and a byte sequence the chosen encoding cannot decode becomes U+FFFD, with a warning saying where.

## benchmarks

::: {.tip title="to be clear"}
Every number in the CLI tables includes process startup, ours included. The smallest races are decided by a 10–25ms exec-and-runtime floor, not by patching.
:::


Have some tables. These are sourced from the [benchmark thing](https://github.com/nyuutsu/slap/tree/main/bench) in the repo, which you can (in principle) run yourself.

We have four before/after pairs: a 4MiB GBC rom, a 16MiB GBA rom, a 64MiB N64 rom, a 520MiB disc image. For each format *where we have a good way to script the reference tool*, each tool creates a patch from the reference pair, and each tool applies. These are timed; times are medians of warm runs. Every output is checked byte-for-byte against the reference pair before its time counts.

- Each cell reads **slap / reference**.

- Anything that ran past fifteen seconds is written as **15s+**.

- A blank cell is a pairing that wasn't benched at that size. IPS and EBP cap out at 16MiB, hence.

- A — means a run happened and produced nothing to measure.

- ppf3 is compared with undo data off on both sides; the reference tool's own mode.

### creating

: Time to make a patch from the pair, **slap / reference**

| format / reference | 4MiB | 16MiB | 64MiB | 520MiB |
|:---|:---:|:---:|:---:|:---:|
| ips / flips | 18ms / 12ms | 9ms / 21ms | | |
| ips32 / sips | 15ms / 8ms | 11ms / 17ms | 38ms / 68ms | 150ms / 413ms |
| ups / goUps | 9ms / 12ms | 11ms / 24ms | 44ms / 99ms | 198ms / 588ms |
| bps / flips | 57ms / 327ms | 103ms / 1.29s | 1.55s / 11.94s | 1.88s / 15s+ |
| ppf3 / makeppf3 | 11ms / 10ms | 19ms / 14ms | 74ms / 57ms | 487ms / 333ms |
| ninja1 / ninjaPhp | 17ms / 41ms | 45ms / 53ms | 130ms / 241ms | |
| ninja2 / ninja2Php | 19ms / 145ms | 50ms / 103ms | 204ms / 685ms | 1.47s / 1.59s |
| gdiff / javaxdelta | 18ms / 136ms | 12ms / 249ms | 239ms / 1.27s | 733ms / 10.76s |
| bsdiff / bsdiff | 74ms / 560ms | 110ms / 2.65s | 682ms / 14.79s | 3.57s / 15s+ |
| xdelta1 / xdelta1 | 44ms / 41ms | 45ms / 49ms | 386ms / 270ms | 1.62s / 1.33s |
| xdelta3 / xdelta3 | 76ms / 47ms | 21ms / 34ms | 398ms / 383ms | 596ms / 326ms |

### the patches themselves

: What those creates wrote, **slap / reference**

| format / reference | 4MiB | 16MiB | 64MiB | 520MiB |
|:---|:---:|:---:|:---:|:---:|
| ips / flips | 655KiB / 654KiB | 16KiB / 16KiB | | |
| ips32 / sips | 672KiB / 899KiB | 18KiB / 23KiB | 4.4MiB / 4.7MiB | 388KiB / 613KiB |
| ups / goUps | 888KiB / 888KiB | 11KiB / 11KiB | 4.5MiB / 4.5MiB | 467KiB / 467KiB |
| bps / flips | 276KiB / 272KiB | 10KiB / 12KiB | 1.9MiB / 1.8MiB | 280KiB / — |
| ppf3 / makeppf3 | 922KiB / 937KiB | 24KiB / 33KiB | 4.6MiB / 4.9MiB | 481KiB / 728KiB |
| ninja1 / ninjaPhp | 888KiB / 899KiB | 18KiB / 23KiB | 4.4MiB / 4.7MiB | |
| ninja2 / ninja2Php | 891KiB / 903KiB | 22KiB / 28KiB | 4.4MiB / 4.7MiB | 467KiB / 679KiB |
| gdiff / javaxdelta | 600KiB / 747KiB | 21KiB / 33KiB | 1.9MiB / 1.9MiB | 367KiB / 425KiB |
| bsdiff / bsdiff | 204KiB / 215KiB | 8KiB / 8KiB | 1.9MiB / 1.8MiB | 287KiB / — |
| xdelta1 / xdelta1 | 239KiB / 239KiB | 13KiB / 17KiB | 1.7MiB / 1.8MiB | 275KiB / 279KiB |
| xdelta3 / xdelta3 | 218KiB / 236KiB | 10KiB / 13KiB | 1.7MiB / 1.7MiB | 263KiB / 272KiB |

### applying

: Applying the patch slap made, **slap / the format's reference applier**

| format / applier | 4MiB | 16MiB | 64MiB | 520MiB |
|:---|:---:|:---:|:---:|:---:|
| ips / flips | 20ms / 10ms | 33ms / 30ms | | |
| ips32 / atmosphereIps | 21ms / 9ms | 32ms / 27ms | 103ms / 103ms | 835ms / 776ms |
| ups / goUps | 15ms / 12ms | 35ms / 30ms | 126ms / 123ms | 902ms / 918ms |
| bps / flips | 34ms / 38ms | 35ms / 136ms | 122ms / 532ms | 896ms / 4.2s |
| ppf3 / applyppf3 | 16ms / 30ms | 31ms / 19ms | 112ms / 109ms | 837ms / 109ms |
| ninja1 / ninjaPhp | 21ms / 15s+ | 60ms / 15s+ | 163ms / 15s+ | |
| ninja2 / ninja2Php | 23ms / 65ms | 64ms / 51ms | 232ms / 232ms | 1.82s / 1.48s |
| gdiff / javaxdelta | 18ms / 48ms | 33ms / 55ms | 110ms / 165ms | 830ms / 1.01s |
| bsdiff / bsdiff | 44ms / 27ms | 112ms / 59ms | 471ms / 279ms | 3.41s / 1.72s |
| xdelta1 / xdelta1 | 30ms / 19ms | 65ms / 46ms | 238ms / 174ms | 1.84s / 1.18s |
| xdelta3 / xdelta3 | 35ms / 16ms | 35ms / 32ms | 152ms / 134ms | 848ms / 843ms |

sips and makeppf3 only create, so in this table ips32 and ppf3 are compared against their format's reference applier instead.

On application we lose more cells than we win; at cartridge sizes the gaps are tens of milliseconds. Every applier here takes slap's patches byte-perfectly.

::: {.note title="in fairness"}
- javaxdelta boots a JVM inside every timed call. That cost dominates its 4MiB numbers and fades to noise by 520MiB; the library itself is quick.

- applyppf3 and the ninja appliers modify a file in place instead of writing a fresh output, so each timed run is handed a pre-made copy, and making the copy is not timed. At 520MiB most of slap's apply time is writing the 520MiB output; an in-place applier writes only the changed bytes. That row is two different jobs sharing a table.
:::

### in the browser

Web slap's natural comparison is [RomPatcher.js](https://www.marcrobledo.com/RomPatcher.js/), the community's longtime standard.

Three browser-sized pairs: the 4MiB and 64MiB roms from above, and an 8MiB pair for ips and ebp, which cannot address 64MiB.

Both sides apply slap's patch; a blank cell means that pairing wasn't benched at that size.

Both sides are timed warm: booted once, files already in memory. Unlike the CLI tables, startup is in none of these numbers.

: Creating, **web slap / RomPatcher.js**

| format | 4MiB | 8MiB | 64MiB |
|:---|:---:|:---:|:---:|
| ips | 45ms / 36ms | 17ms / 219ms | |
| ups | 6ms / 43ms | | 75ms / 620ms |
| bps | 60ms / 15s+ | | 2.0s / 560ms |
| ppf | 5ms / 31ms | | 72ms / 421ms |
| ebp | 45ms / 37ms | 17ms / 220ms | |
| aps | 6ms / 33ms | | 74ms / 412ms |
| rup | 14ms / 61ms | | 214ms / 789ms |

At 4MiB, RomPatcher.js walks the same search our Rust differ walks, in pure JavaScript; that is the 15s+, and its patch comes out nearly as small. Above 4MiB (a threshold in its source) it switches to a linear pass, which is much quicker and writes a bigger patch. The trade lands in the patch table below.

: The patches each create wrote, **web slap / RomPatcher.js**

| format | 4MiB | 8MiB | 64MiB |
|:---|:---:|:---:|:---:|
| ips | 655KiB / 886KiB | 554KiB / 556KiB | |
| ups | 888KiB / 888KiB | | 4.5MiB / 4.5MiB |
| bps | 276KiB / 308KiB | | 1.9MiB / 4.4MiB |
| ppf | 922KiB / 936KiB | | 4.6MiB / 4.9MiB |
| ebp | 655KiB / 886KiB | 554KiB / 556KiB | |
| aps | 905KiB / 908KiB | | 4.5MiB / 4.6MiB |
| rup | 891KiB / 903KiB | | 4.4MiB / 4.7MiB |

: Applying, **web slap / RomPatcher.js**

| format | 4MiB | 8MiB | 64MiB |
|:---|:---:|:---:|:---:|
| ips | 22ms / 4ms | 9ms / 14ms | |
| ups | 5ms / 12ms | | 82ms / 98ms |
| bps | 29ms / 10ms | | 68ms / 48ms |
| ppf | 3ms / 10ms | | 43ms / 59ms |
| ebp | 22ms / 3ms | 8ms / 19ms | |
| aps | 24ms / 11ms | | 37ms / 66ms |
| rup | 12ms / 17ms | | 176ms / 198ms |

The full grids, the harness itself, and the six CLI formats with no scriptable reference tool to race against are all in [the results directory](https://github.com/nyuutsu/slap/tree/main/bench/results).

---
title: "PicNRec for Everyone"
icon: "📷"
description: "Multiplatform client for the Game Boy Camera PicNRec."
weight: 4
---

::: tip
Just want the code for some reason? Get it [here](https://github.com/nyuutsu/picnrec-py).
:::

![A demonstration](/images/projects/picnrec/picnrec-screen-comparison-to-irl.webp){alt="Hand holding a Game Boy Color with a PicNRec cartridge, framing a fireplace mantel. The GBC screen shows a dithered preview of the scene."}

The [Game Boy Camera](https://en.wikipedia.org/wiki/Game_Boy_Camera) is a camera-in-a-cartridge for the [Game Boy](https://en.wikipedia.org/wiki/Game_Boy). It takes four-color, *harshly*-dithered, 128x112 pictures. It has a kind of twee crudeness that [some people really like](https://github.com/Raphael-Boichot/Awesome-Game-Boy-Camera-and-Game-Boy-Printer-projects). It holds few pictures and doesn't *meaningfully* expose a way to get the pictures off of it. (You can print them out using the [Game Boy Printer](https://en.wikipedia.org/wiki/Game_Boy_Printer).)

The "Game Boy Camera PicNRec" is a [flashcart](https://en.wikipedia.org/wiki/Flash_cartridge) treatment of the Game Boy Camera. It lets you take *lots* of pictures. It also lets you record video. It *also* comes with software to get the media off of the cartridge and onto your computer. Said software is Windows-only. I run Linux. I'd rather not have to deal with [Wine](https://en.wikipedia.org/wiki/Wine_(software)). To solve my (and maybe also your) problem I've written a multiplatform program for interacting with the PicNRec.

The program consists of a library for interacting with the PicNRec, a [CLI](https://en.wikipedia.org/wiki/Command-line_interface) interface, and a GUI interface. I'd recommend using the GUI. Two screenshots that comprehensive-ish-ly show what it is like:

![The extraction dialog](/images/projects/picnrec/picnrec-gui-1.webp){alt="PicNRec GUI showing the extraction dialog: 430 images found, with options to extract all, a range, or multiple ranges" .clickable}

![Browsing retrieved images](/images/projects/picnrec/picnrec-gui-2.webp){alt="PicNRec GUI displaying a retrieved Game Boy Camera image, with palette, color adjustment, and export options in the sidebar" .clickable}

The CLI works well enough:

![The pinnacle of user experience](/images/projects/picnrec/picnrec-cli.webp){alt="Terminal showing picnrec CLI help: subcommands for info, view, export, erase, and ports, with options for port selection and verbosity"}

This program is a prototype. The main goal in writing this version was just to figure out how to reliably connect to, query, retrieve-from, and gallery-wipe the PicNRec. I anticipate rewriting with more care in a language I find more fun.

Despite it being in [tk](https://en.wikipedia.org/wiki/Tk_(software)), I've attempted to make it feel good to use. (e.g. <kbd>Ctrl</kbd>+<kbd>A</kbd> and its ilk should work properly.) It retrieves media slowly since the controller seems to require this.

## Source

Get it [here](https://github.com/nyuutsu/picnrec-py)

---
title: "DM4 Translation"
icon: "🕹️"
description: "English patch, guide, & save-editor for Yu-Gi-Oh! Duel Monsters 4 (GBC)"
weight: 2
---

::: tip
Get it here: [dm4-patch.zip](https://files.nyuu.page/dm4-patch.zip) (6.4 MB), or here: [dm4-patch.tar.xz](https://files.nyuu.page/dm4-patch.tar.xz) (0.3 MB). If in doubt, go with the zip.
:::

## What is this?

This is a full English translation of each of the three versions of *Yu-Gi-Oh! Duel Monsters 4: Battle of Great Duelist* ("DM4"). It comes with a [companion website](https://dm4.nyuu.page/){.companion-link}, which includes a [save editor](https://dm4.nyuu.page/editor){.companion-link .to-editor}.

![A collage of some screenshots](/images/projects/dm4-translation/screenshot-composite-B1.webp){alt="A 4-by-4 collage of Game Boy Color screenshots from the English patch. Top row: the credit screen (\"Lovingly delocalized by: nyuu — when the ※ mark appears, more info is available on https://dm4.nyuu.page/\"); the Jonouchi Deck title screen; a duel where \"Giant Divine Soldier of Obelisk activated its effect.\"; a duel where \"The trap was Mousetrap. Tsurupurun was eliminated.\" Second row: Kaiser saying \"You think you can duel me? You're 100 trillion years too early!\"; the ritual card Invocation Through Dance (\"Sacrifice Water Dancer and two other monsters to summon Dancing Soldier.\"); the card Arm of the Dead (\"Seizes the strongest enemy monster & drags both victim and itself to the grave together.\"); Esper Roba saying \"Crap! Clouds are covering the sky so the cosmic energy can't reach me.\" Third row: the main menu (Campaign, Trade, Versus, Record, Password); the trap card Torrential Burial (\"When your opponent declares an attack, destroy all monsters on their side of the field.\"); Exodia declaring \"Hellfire of Wrath — Exōd Flame!\"; the card Giant Virus (\"It's so terrible that just one virion can kill even a dragon.\"). Bottom row: the fusion card Thousand-Eyes Sacrifice (\"It steals and becomes the foe's strongest monster, raised to its maximum level.\"); Pegasus saying \"each and every mistake accumulates, leading you to defeeeeeeat!\"; the card That Which Slurps Lifeblood (\"In the darkness, this humanoid blood-sucking snake ambushes wayfarers along the roadside.\"); the Bag / Card Confirmation / Card Trade menu."}

*An official translation exists now; it's part of the "Early Days Collection". When we began, this wasn't around.*

### Vibes

We have attempted to preserve context and feel. So: Japanese names rather than localized ones, generally keeping onomatopoeia and sound effects, maintaining speech patterns, and declining cultural substitution. We do one class of deviation. Sometimes the base text is ambiguous or even flatly wrong. So, when writing a card's effect-text, we take into account what the effect **actually** does and describe **that**.  When "deviating", we still try to preserve what we can; many of these rules-texts have flavor or voice that can be used while not-misleading.

## How do I get this?

### Download

Get it here: [dm4-patch.zip](https://files.nyuu.page/dm4-patch.zip) (6.4 MB), or here: [dm4-patch.tar.xz](https://files.nyuu.page/dm4-patch.tar.xz) (0.3 MB). If in doubt, go with the zip.

### Pick your patch

Open the folder for your version. In it, there are a bunch of files. Pick **exactly one**. The plain one (e.g. `dm4-kaiba.bps`), is the translation on its own.

The others are the translation **and** different combinations of extras.

#### The options

`bugfixes`: Fixes two bugs inherited from the original. First, makes `Pot of Greed` stop taking up a spot in your hand while you're drawing the cards. Second, makes `Beckoning to Darkness` stop fizzling when you have five monsters out.

`rainbow`: Monsters you can fuse for have the [violet background color](https://tcrf.net/Yu-Gi-Oh!_Dark_Duel_Stories#Unused_Card_Color) that was scrapped during development of DM3. Monsters you can ritual for have the ritual blue background color. If either and they have an effect on top of that, then their rulebox has an orange outline.

`opendeck`: Removes the ban-list and the limited-list.

### Applying it

The rom to apply it to is the Japanese cartridge rom from 2000. The standard `no-intro` one.

Apply the patch to the rom.

Consider doing so with *my rom patcher*, [slap](https://slap.nyuu.page/)! You can also use RomPatcher.js, Floating IPS, etc.

#### Hashes of the rom to apply the patch to

| Deck | CRC32 | MD5 | SHA1 |
|---|---|---|---|
| Yuugi Deck | 4d6105f6 | e3809354341cfb1f2ebb3e4dd1bc8828 | 3199283039089fdf1e1b3cbb5b95fe7b26c6765f |
| Kaiba Deck | a4d06001 | 19b1085c7c17a8123a7ec59f4033e92c | ee769a23750e48c5ba4949f83236b18814316de2 |
| Jounouchi Deck | 298bd054 | f84f21fd860d1d9cfb8ca6ea62a0da8f | 2fdf56c2b52ba83fee778f3c2961a90ab69ea899 |

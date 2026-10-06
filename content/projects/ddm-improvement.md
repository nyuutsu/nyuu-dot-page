---
title: "DDM Improvement"
icon: "🎲"
description: "Improvement patch, guide, & save-editor for Yu-Gi-Oh! Dungeon Dice Monsters (GBA)."
weight: 3
---

::: tip
Get it here: [ddm-patch.zip](https://files.nyuu.page/ddm-patch.zip) (15.2 MB), or here: [ddm-patch.tar.xz](https://files.nyuu.page/ddm-patch.tar.xz) (2.9 MB). If in doubt, go with the zip.
:::

## What is this?

This is an improvement patch for the game *Yu-Gi-Oh! Dungeon Dice Monsters* ("DDM"). It comes with a [companion website](https://ddm.nyuu.page/){.companion-link}, which includes a [save editor](https://ddm.nyuu.page/editor){.companion-link .to-editor}.

```{=html}
<div class="game-clips">
  <figure>
    <video controls preload="none" playsinline width="240" height="160"
           poster="/images/projects/ddm-improvement/clip1-poster.webp">
      <source src="/videos/projects/ddm-improvement/clip1.webm" type='video/webm; codecs="av01.0.04M.10, opus"'>
      <source src="/videos/projects/ddm-improvement/clip1.mp4" type='video/mp4; codecs="avc1.64001F, mp4a.40.2"'>
      <p><a href="/videos/projects/ddm-improvement/clip1.mp4">Download clip 1</a></p>
    </video>
    <figcaption>We roll twice, then summon Swamp Battleguard.</figcaption>
  </figure>
  <figure>
    <video controls preload="none" playsinline width="240" height="160"
           poster="/images/projects/ddm-improvement/clip2-poster.webp">
      <source src="/videos/projects/ddm-improvement/clip2.webm" type='video/webm; codecs="av01.0.04M.10, opus"'>
      <source src="/videos/projects/ddm-improvement/clip2.mp4" type='video/mp4; codecs="avc1.64001F, mp4a.40.2"'>
      <p><a href="/videos/projects/ddm-improvement/clip2.mp4">Download clip 2</a></p>
    </video>
    <figcaption>The opponent uses Time Wizard's effect.</figcaption>
  </figure>
  <figure>
    <video controls preload="none" playsinline width="240" height="160"
           poster="/images/projects/ddm-improvement/clip3-poster.webp">
      <source src="/videos/projects/ddm-improvement/clip3.webm" type='video/webm; codecs="av01.0.04M.10, opus"'>
      <source src="/videos/projects/ddm-improvement/clip3.mp4" type='video/mp4; codecs="avc1.64001F, mp4a.40.2"'>
      <p><a href="/videos/projects/ddm-improvement/clip3.mp4">Download clip 3</a></p>
    </video>
    <figcaption>The opponent uses three monsters to attack our Die Master three times in one turn.</figcaption>
  </figure>
  <figure>
    <video controls preload="none" playsinline width="240" height="160"
           poster="/images/projects/ddm-improvement/clip4-poster.webp">
      <source src="/videos/projects/ddm-improvement/clip4.webm" type='video/webm; codecs="av01.0.04M.10, opus"'>
      <source src="/videos/projects/ddm-improvement/clip4.mp4" type='video/mp4; codecs="avc1.64001F, mp4a.40.2"'>
      <p><a href="/videos/projects/ddm-improvement/clip4.mp4">Download clip 4</a></p>
    </video>
    <figcaption>We suspend the duel, then resume it.</figcaption>
  </figure>
</div>
```

### What does it change?

Some of what the patch does:

- Speeds the game up, by a lot.
- Makes the AI smarter & lets it use its monsters' abilities.
- Adds a suspend feature.
- Rolls twice, à la the paper game's "advanced" rules.
- Adjusts the droprates to make the commons less common and rares less rare. The sale prices are reduced accordingly.
- Adjusts the shop's unlock curve, such that non-grindy play is enough to unlock everything.
- Lists D. Magician Girl in the shop once she's farmable.
- Fixes various bugs.
- You can have at most *one* of any die in your pool, so the best pool isn't just Time Wizards, Battle Warriors, & Energy Discs.

[everything the patch changes →](https://ddm.nyuu.page/patch){.companion-link .to-patch}

## How do I get this?

### Download

Get it here: [ddm-patch.zip](https://files.nyuu.page/ddm-patch.zip) (15.2 MB), or here: [ddm-patch.tar.xz](https://files.nyuu.page/ddm-patch.tar.xz) (2.9 MB). If in doubt, go with the zip.

### Pick your patch

There are eight patches, one for each language in each version of the game. Pick the one that's right for you:

| file | version | language |
|---|---|---|
| ddm-usa-english-\<release\>.bps | USA | English |
| ddm-usa-spanish-\<release\>.bps | USA | Spanish |
| ddm-europe-english-\<release\>.bps | Europe | English |
| ddm-europe-spanish-\<release\>.bps | Europe | Spanish |
| ddm-europe-italian-\<release\>.bps | Europe | Italian |
| ddm-europe-german-\<release\>.bps | Europe | German |
| ddm-europe-french-\<release\>.bps | Europe | French |
| ddm-japan-\<release\>.bps | Japan | Japanese |

### Applying it

Apply patch to rom with any `bps` patcher. Consider doing so with *my rom patcher*, [slap](https://slap.nyuu.page/)! You can also use RomPatcher.js, Floating IPS, etc.

#### Hashes of the rom to apply the patch to

The patches expect to be applied to the nointro dump of the rom.

| Version | CRC32 | MD5 | SHA1 |
|---|---|---|---|
| USA | 8b5e0a27 | 1ac4901f9a831d6b86ca776bb61f8d8b | fdd69455a072b2f74e6c5c50b96daa0438156b27 |
| Europe | ee317f69 | ec2e23cc5fd7a3ea4e32ac7b8d488103 | 3ded1227698fbdb2ba47f03025cd1934fc184b99 |
| Japan | 51b35e87 | 72f072d0e26a9e3d12b6107598cbaf69 | a0ad0cbff3d74bb3e234abcff866994ea602c43a |

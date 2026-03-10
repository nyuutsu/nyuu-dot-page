---
title: "DM4 Translation"
icon: "🎮"
description: "English patch for Yu-Gi-Oh! Duel Monsters 4 (GBC). Ongoing."
weight: 3
status: wip
---

::: tip
Just want the patch for some reason? Get it [here](https://files.nyuu.page/dm4y-patch.bps).
:::

::: warning
This is a long-running project as I'm frequently working on other things. I anticipate finishing it within the month (month of March 2026) but make no promises.
:::

In late 2024 I started translating [Yu-Gi-Oh! Duel Monsters 4: Battle of Great Duelists](https://yugipedia.com/wiki/Yu-Gi-Oh!_Duel_Monsters_4:_Battle_of_Great_Duelists) into English. This resulted in a [cool blog post](https://nyuu.page/posts/2024-10-15-romhack/).

I translated 2/3 of the cards. The text fields were subject to *brutal* space limits that spoiled a lot of the fun of making the translation. I took a detour to attempt to patch/translate the menus and hit a wall.

I found a charming Japanese → Chinese translation that fixed many of my pain points & resolved to use its plumbing in my translation. I re-translated all the cards, the script, the menus, the in-game field menus & such, the title screen, & the *this is only playable on the game-boy color* error screen.

I have yet to finish the tooling for actually inserting the script & the dynamic in-battle text. As such this is patch is incomplete. But I'm quite proud of the parts that are done. On request I'm making it available as-is.

## Title & credits

![Credit screen](/images/projects/dm4-translation/credit-screen.png){.gbc alt="GBC screen reading: Lovingly delocalized by nyuu. When a crossed-swords icon appears, more info is available on https://dm4.nyuu.page/. Freely distributed, without exception."}

![Translated title screen](/images/projects/dm4-translation/title-screen.png){.gbc alt="Title screen showing the Yu-Gi-Oh! Duel Monsters 4 logo with subtitle Battle of Great Duelist, Yugi Deck. Begin Anew and Continue options at the bottom."}

![GBC-only error screen](/images/projects/dm4-translation/gbc-only-screen.png){.gbc alt="Error screen reading: This game is designed for use on GAME BOY COLOR only. Shows Yu-Gi-Oh! Duel Monsters 4: Battle of Great Duelist beneath character portraits of Yugi, Kaiba, and Jounouchi."}

## Menus

![Main menu](/images/projects/dm4-translation/main-menu.png){.gbc alt="Main menu screen with five options: Campaign, Trade, Versus, Record, and Password, arranged on an ornate blue stone background."}

![Record screen](/images/projects/dm4-translation/record-screen.png){.gbc alt="Record screen listing duelists with win/loss tallies: Ryota Kajiki, Siamun Muran, Esper Roba, Ryuzaki, and Insector Haga, all showing zero wins and losses."}

![Password entry](/images/projects/dm4-translation/password-entry.png){.gbc alt="Password entry screen with an eight-digit input field showing all zeroes."}

## Cards

![Card detail for Wriggle](/images/projects/dm4-translation/card-wriggle.png){.gbc alt="Card detail screen for Wriggle: Insect type, stats 300 attack 350 defense, Forest-Taxon. Description reads: It deals direct damage equal to its attack to the opponent."}

![Card detail for Killer Snake](/images/projects/dm4-translation/card-killer-snake.png){.gbc alt="Card detail screen for Killer Snake: Reptile type, stats 300 attack 250 defense, Water-Taxon. Description reads: This venomous snake has wings and can fly through the sky, but struggles with ground movement."}

## Patch

[https://files.nyuu.page/dm4y-patch.bps](https://files.nyuu.page/dm4y-patch.bps)

## Coming next

The script and in-battle dialogue are translated but not yet inserted. Here's what that looks like in dev:

![Siamun pre-duel dialogue](/images/projects/dm4-translation/dialogue-siamun.png){.gbc alt="Siamun standing in a stone chamber, saying: Show this old one what you can do. Defeat me 5 times with a deck wherein your heart dwells."}

![Dinosaur Ryuzaki pre-duel dialogue](/images/projects/dm4-translation/dialogue-ryuzaki.png){.gbc alt="Dinosaur Ryuzaki adjusting his hat, saying: I'm Dinosaur Ryuzaki, and just like the name says, I'm a dinosaur duelist!"}

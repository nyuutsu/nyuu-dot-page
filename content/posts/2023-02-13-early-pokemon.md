---
title: "Early 'Pokemon Trading Card Game' Design Review"
date: 2023-02-13
---

::: cards
:::

One of the things I'm keeping score on when reviewing a game is, how many of its mechanics *matter* to someone playing to win? Let's turn back the clock, to when the Pokemon Trading Card Game was first released in the US. How did it fare making its mechanics relevant to competitive players? I think it did badly; here's why.

This post's examples are (with one) about the first Pokemon set - the [Base Set](https://pkmncards.com/set/base-set/) - exclusively. The base set was, for little while, the *only* set. A short while later, two more sets came out: [Jungle](https://bulbapedia.bulbagarden.net/wiki/Jungle_(TCG)) and [Fossil](https://bulbapedia.bulbagarden.net/wiki/Fossil_(TCG)). These three were the cardpool for the first notable competitive format, *descriptively* named "BJF", short for "Base/Jungle/Fossil". It's a bit weird to try to size up the base set on its own since it wasn't played without Jungle or Fossil for *that* long. But the BJF sets are all fairly similar in terms of balance: trainers are strong; non-evolving pokemon are stong; other things are weak. The general design trends still hold, even if trivia like "what percentage of the cardpool is trainers" changes a bit when you bring Jungle and Fossil into the picture.

I am going to explain mechanics by alluding and comparing to what *Magic* does.

### game design

At the beginning, Pokemon had [one set](https://pkmncards.com/set/base-set/); the Base Set. We can look at its composition to make reasonable guesses about what the designers were thinking. If they emphasized a mechanic (featured on lots of cards, or rarer ones, or shinier and/or cooler ones, or it gets allocated a lot of the rules-space) then there's a good chance they thought it was important.

It *looks* like the core mechanical selling point was supposed to be about a rising power level over the course of the game via the *evolution* mechanic. The way evolution works is, you can use later, stronger evolutionary stages of a given Pokemon, but fonly if you already have the unevolved form in play, and only if it has survived at its current stage for at least one turn already. Some Pokemon evolve no times, some once, and some twice. The cards have rarities; the packs they came in would come with more commons and fewer rares. Second-stage evolutions were pretty much exclusively found at the highest rarity and made up much of the rare pool. There were a few fancy, shiny foil-art cards; all of them Pokemon, most of them second-stage evolutions.  The marketing I remember seeing as a kid was about getting to use evolution to play a [Charizard]{.card set="base1"}. Evolution is flavorful; it's cool; it's strategically *awful*.

::: note
Evolution was bad at the time. It might be good now.
:::

::: info
Aside: the first set has 102 cards. The card-type breakdown is 69 Pokemon, 26, trainers, 7 energy. The trainers focus on lots of different mechanics. A mere two of them ([Devolution Spray]{.card source="pokemon"}, [Pokémon Breeder]{.card set="base1"}) are "about" evolution and an additional handful could benefit evolution-based strategies but weren't about them. It'd be fair to say trainers are not intended to be "about" evolution. Pokemon, however, are **about evolution**. 53/69<sup>(77%!)</sup> of them evolve or are evolved. Of the quarter that don't have evolutions, a bunch gain them in Jungle and/or Fossil. This game is "about evolution".
:::

Evolution could be great if the evolved forms were sufficiently stronger (more health, more damage per energy, more raw damage) than the non-evolving Pokemon. They aren't; evolving isn't profitable. Your attacks get stronger, which is flashy and cool! But your attacks also get more expensive, which is a huge problem and makes it impossible to *actually do damage*.

An important idea in trading card games: over the course of the game, the amount of "swinginess" that happens in each turn should increase. The first turn should have puny little effects that represent tiny swings in "who is winning". Later turns should have increasingly large effects & so large swings in "who is winning and by how much". Analogous maybe to the "material advantage" bars shown by chess apps? Most collectible card games have a mechanic meant to achieve this.

* Magic has "you need mana to cast spells. You get mana from lands. You can play one land per turn. Thus, you can do more expensive (and therefore stronger) things the longer the game goes on".

* Hearthstone has "you need mana to cast spells. You have a mana pool. It starts at one mana. Each turn, its capacity increases by one, and then it refills completely. So on turn one you can cast a one mana card. And you must wait until turn ten to can cast a ten mana card".

* Yu-Gi-Oh has the mechanic of "you need creatures to win. You can play one creature per turn. Larger creatures require you to sacrifice in-play creatures. So, large creatures cost cards and time."

* Pokemon has *energy* cards. You can play one energy per turn. Energy are attached to a specific Pokemon. To use an attack, you must have some minimum amount of energy. Stronger attacks generally have higher energy requirements.

Destroying an energy in Pokemon is loosely analogous to destroying a land in Magic.

Roughly a quarter of every competitively viable early Pokemon deck consists of uncounterable zero-cost [Stone Rain]{.card source="mtg"}s! Every sixty-card deck contains four of each of the following: [Energy Removal]{.card source="pokemon"} (destroy an energy), [Super Energy Removal]{.card source="pokemon"} (destroy *two* energy), [Item Finder]{.card source="pokemon"} (graveyard recursion for your energy removals), and [Computer Search]{.card source="pokemon"} (unconditional [tutor](https://mtg.fandom.com/wiki/Tutor)/search library for whatever card you want; can find an energy removal).

We know that every viable deck runs the maximum allowed amount of the above cards, since blowing up your opponent's resources is pretty much the strongest thing you can be doing. In fact: every viable deck has something like *thirty* cards (half of the deck!) in common with all other viable decks, since there are so many overwhelmingly generically powerful effects in the format.

Attacks must be cheap to be viable, since your opponent is going to be constantly destroying your energies. Attacks of evolved Pokemon are *expensive*; they'll often cost three or four energy pips. Evolutions overall are too hard to get into play and too easy to end up unable to act due to lack of energy. The more reliable strategy is to pick from a shortlist of powerful non-evolving options: [Hitmonchan]{.card source="pokemon"} of [Electabuzz]{.card source="pokemon"} [Mewtwo]{.card set="base1"} [Chansey]{.card set="base1"}. The next two sets, Jungle and Fossil, were designed similarly: they added many Pokemon, but the ones with competitive relevance continued to be efficient non-evolving Pokemon ([Moltres]{.card set="base3"} [Magmar]{.card source="pokemon"}-[Scyther]{.card source="pokemon"} [Mewtwo]{.card set="base1"}); The Jungle and Fossil additions didn't change the "evolved is a really big downside" dynamic.

Pokemon had large competitive tournaments almost immediately after it was brought to the US. This is unusual for a new trading card game; it's common for competitive support to emerge only later. In the case of Pokemon, this early competitive support means lots of people got to go to tournaments and experience playing against "a deck consisting of efficient non-evolving pokemon and energy destruction"!

Sometimes, a contemporary writer will try to cover "the early Pokemon trading card game's metagame" and will list a few strategies. They'll generally be left scrabbling to find strategies that *aren't* "just use the efficient non-evolving ones"; they'll likely mention the [Blastoise]{.card set="base1"}/Rain Dance strategy, [Wigglytuff]{.card source="pokemon"}/"Do the Wave", and if they're especially good researchers then they may talk about Moltres + Chansey Stall/Mill. The latter two archetypes are pretty good, too. Rain Dance is rather bad, though. *Back in the late 90s*, people hadn't figured this out, so contemporaneous sources would talk about it being good. It turns out, "being able to play as many energy as you can access, *if* you can evolve", is a fragile strategy! You might not find your combo pieces. You might get forced to start the game with just a [Squirtle]{.card set="base1"}; you plausibly get one-turn killed by a *lot* of unevolved-pokemon-deck's opening hands in this situation.

For the curious, there are [strategic resources](https://jklaczPokemon.com/) out there specifically about the earliest Pokemon formats. There is a very cool [Discord server](https://discord.gg/hqRmAb6h), also focused on retro Pokemon formats, particularly base-jungle-fossil. If you aren't put off by the strong non-evolving Pokemon and the rampant land destruction, you actually can play this (twenty years out of date!) format, in paper, via webcam, on that server. It's part of a recent broader trend of forming communities for webcam-based play for older or less accessible trading card game formats. There's one for [legacy Magic](https://discord.gg/np5CFwh), too.

## conclusion

Parting thought: check out my BJF decks! The discord server I mentioned in the previous paragraphs holds monthly tournaments; the registration process involves submitting a decklist via taking a picture of your deck all splayed out. These pictures were taken for that purpose.

In cases where I didn't have a desired card in time for the deck registration photo but expected I'd have it in time for my actual matches, I sometimes used proxies. So there are a few obvious "fakes" in these. I still think they're cool, though:

![haymaker](/images/pkmn-history/pkmndeck1.webp)

![rain dance](/images/pkmn-history/pkmndeck2.webp)

![stall](/images/pkmn-history/pkmndeck3.webp)

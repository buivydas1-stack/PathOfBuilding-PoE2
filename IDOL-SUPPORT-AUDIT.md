# Idol support audit - 2026-10-04

PoB source/runtime baseline: v0.23.1 custom fork. Current public patch checked: 0.5.5d (separate from the source version). Data comparison: pinned RePoE b818b843337cae43b090b272fd98bbc0fd3a34f3, 2026-09-15; [current Sycophant effects](https://poe2db.tw/us/Idol_of_the_Sycophant) agree with it. This is a software support audit, not a claim of complete current-game data.

All 83 idol/slot entries pass the real selector, import, editor and item round-trip checks. Sycophant's weapon damage/resistances and replacement limit have independent calculation checks. The shared combined weapon category, missing limits, Bonded actor/special parsing, item-local Fox Idol activation and Carved Majesty's Spirit-per-Idol wording are repaired.

The first combat batch adds three effects using existing calculations: Carved Cunning's helmet hit guarantee against enemies on Full Life, its body-armour deflection prevention bonus, and Carved Mischief's raised-shield maximum Block bonus. Full Life and Active Blocked Recently use existing Configuration conditions; Deflected Recently has a new manual checkbox. Wrapped Cunning body-armour clipboard text is recognised as one modifier. Import/editor checks, condition toggles and independent recommendation/calculation comparisons pass. Current effect text checked against [Carved Cunning](https://poe2db.tw/us/Carved_Cunning) and [Carved Mischief](https://poe2db.tw/us/Carved_Mischief).

The second combat batch adds Carved Cunning boots' Onslaught on Mark activation and Pharisee's missing-Mana physical damage for martial weapons, wands and staves. "Has a Mark Activated Recently?" is distinct from casting a Mark and is exposed when an enabled Mark can supply that scenario. Current Mana % is available with a socketed eligible weapon before comparing Pharisee; enter 30 for 70% missing Mana. It accepts zero, clamps 0-100 and uses completed ten-percent missing-Mana increments. It does not set the existing Low Mana checkbox. Onslaught does not stack with the existing manual buff. Direct and background-snapshot comparisons agree; item import/editor round trips and zero/full/blank/boundary Mana checks pass. [Voltaic Mark activates on Electrocution](https://poe2db.tw/us/Voltaic_Mark); [Pharisee effects](https://poe2db.tw/us/Idol_of_the_Pharisee) are checked separately from simulation assumptions. Pharisee's sceptre Command-skill cost wording remains outside this batch.

The following 39 item modifier lines still have no complete parser result. This list retains the earlier inventory; non-combat effects are excluded from further implementation at the user's request. They remain marked unsupported in item previews and contribute no value for that effect. Parsed remaining lines are not thereby proven fully simulated: charge transfer, temporal/conditional uptime, probabilistic actions and skill limits require their own calculation models. These are existing engine support limitations, not evidence that a recommendation with those lines has zero potential in-game value.

| Idol | Socket category | Unsupported modifier |
| --- | --- | --- |
| Carved Majesty | boots | 1% increased Movement Speed while Sprinting per Persistent Minion |
| Carved Majesty | gloves | Companions gain Onslaught for 4 seconds on Hitting your Marked targets |
| Carved Mischief | helmet | Gain Guard equal to 10% of maximum Life for 4 seconds on taking Savage Hit |
| Carved Tenacity | boots | Your speed is Unaffected by Slows while Sprinting |
| Carved Tenacity | gloves | Enemies you Critically Hit get 100% reduced Life Regeneration Rate for 4 seconds |
| Carved Tenacity | helmet | Enemies have no Critical Damage Bonus for 4 seconds after you Blind them |
| Idol of Alira | helmet | 15% chance when you gain a Power Charge to gain an additional Power Charge |
| Idol of Alira | sceptre | If you would gain a Power Charge, Allies in your Presence gain that Charge instead |
| Idol of Egrin | sceptre | Bonded: Curse zones erupt after 20% reduced delay |
| Idol of Eramir | body armour | Bonded: 15% chance for Charms you use to not consume Charges |
| Idol of Eramir | body armour | Skills have 10% chance to not remove Charges but still count as consuming them |
| Idol of Eramir | sceptre | Allies in your Presence share Charges with you |
| Idol of Greust | sceptre | Bonded: Recover 3% of maximum Life when one of your Minions is Revived |
| Idol of Greust | sceptre | Companions deal 10% more Damage for each different type of dead Companion you have |
| Idol of Grold | boots | Bonded: 30% increased Glory generation |
| Idol of Grold | sceptre | 15% increased Damage per each different Companion in your Presence |
| Idol of Kraityn | gloves | 15% chance when you gain a Frenzy Charge to gain an additional Frenzy Charge |
| Idol of Kraityn | sceptre | If you would gain a Frenzy Charge, Allies in your Presence gain that Charge instead |
| Idol of Maxarius | body armour | Bonded: Storm Skills have +1 to Limit |
| Idol of Oak | boots | 15% chance when you gain an Endurance Charge to gain an additional Endurance Charge |
| Idol of Oak | sceptre | If you would gain an Endurance Charge, Allies in your Presence gain that Charge instead |
| Idol of Silk | sceptre | Companions in your Presence gain 1 Rage on hit |
| Idol of Sirrius | gloves | Bonded: 20% reduced Slowing Potency of Debuffs on You |
| Idol of Yeena | boots | Bonded: Plants have a 25% chance to immediately Overgrow when they enter your Presence for the first time |
| Idol of Yeena | sceptre | Plants have a 25% chance to immediately Overgrow when they enter your Presence for the first time |
| Idol of the Martyr | staff | Bonded: Invocated skills have 25% increased Maximum Energy |
| Idol of the Martyr | staff | Meta Skills gain 40% increased Energy |
| Idol of the Martyr | wand | Bonded: Invocated skills have 25% increased Maximum Energy |
| Idol of the Martyr | wand | Meta Skills gain 40% increased Energy |
| Idol of the Martyr | weapon | Bonded: Invocated skills have 25% increased Maximum Energy |
| Idol of the Martyr | weapon | Meta Skills gain 40% increased Energy |
| Idol of the Pharisee | sceptre | 30% reduced Mana Cost Efficiency of Command Skills |
| Owl Idol | focus | Bonded: 20% increased effect of Archon Buffs on you |
| Ox Idol | buckler | Bonded: 15% chance for Damage of Enemies Hitting you to be Unlucky |
| Ox Idol | shield | Bonded: 15% chance for Damage of Enemies Hitting you to be Unlucky |
| Primate Idol | helmet | Bonded: Remnants can be collected from 30% further away |
| Rabbit Idol | body armour | Bonded: 10% increased Quantity of Gold Dropped by Slain Enemies |
| Stag Idol | helmet | Bonded: Projectiles have 25% chance for an additional Projectile when Forking |
| Stag Idol | helmet | Projectiles have 15% chance to Fork |

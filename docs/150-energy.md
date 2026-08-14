---
title: Restoration Energy and levels
group: Build & ship
description: Every hour you ship becomes Restoration Energy, or RE.
---

# Restoration Energy and levels

^ Every hour you ship becomes **Restoration Energy**, or RE. It's the number the whole economy runs on: RE decides what an hour of your work pays, and your level is a readout of how much of it you've built up.

You never spend RE. It only goes up, nothing decays, and nothing anyone else ships takes any of it away from you. Pixels are the thing you spend; RE is the thing that decides how many pixels an hour is worth.

## Tiers decide what an hour is worth

When a reviewer approves your project they also give it a **tier**, 1 to 4, based on how ambitious the build actually is. The tier sets how much RE each shipped hour on that project earns.

| T1 Spark | A first spark of Restoration: a simple site, script or tiny tool. | {{t1}} RE / hour |
| T2 Signal | A focused app, CLI or game with real polish, one system back online. | {{t2}} RE / hour |
| T3 Grid | Several systems working together: backend, state, infrastructure. | {{t3}} RE / hour |
| T4 Beacon | Deep systems work: complex architecture and serious scope. | {{t4}} RE / hour |

Tier is about the project, not about you. A first timer who ships something genuinely hard gets the high tier for it. Padding a simple site out with hours doesn't move it up either, since reviewers look at the actual repo.

## RE decides your rate, one project at a time

Each project's own RE, its tier weighted by its hours, is what sets *that project's* hourly rate. It starts at {{baseUsd}} an hour and climbs in a straight line to {{maxUsd}} an hour once the project alone earns {{reCap}} RE. In pixels, that's {{basePx}} an hour rising to {{maxPx}}.

The climb counts for the project that's earning it, and only that project. Its rate rises *while* its hours land, so it gets paid the average rate across the RE it earned, from zero. Whatever RE you've already banked from other projects doesn't carry over: every project starts its own climb from the bottom, so splitting your work across several projects or bundling it into one pays about the same either way, and no single big build inflates the rate on everything you ship afterwards.

For example, a {{capExampleHours}} hour T4 project earns the full {{reCap}} RE by itself, so its rate runs the entire ramp start to finish and it's paid {{capExampleUsd}} ({{capExamplePx}}) total. Ship a {{nextExampleHours}} hour T1 project right after it and that one earns barely any RE on its own, so it's paid close to base: around {{nextExampleRate}} an hour ({{nextExamplePx}} total), not the {{maxUsd}} the big project just finished at.

::: note The short version
On any one project, ship more, and ship something more ambitious, and every hour of it is worth more than the one before it. That project's own rate has a ceiling; your lifetime RE, below, does not.
:::

## The tier bonus

That climb is deliberately slow, because {{reCap}} RE is a lot of shipping for one project. On a short project it would barely register, and a tier 4 weekend build would pay about the same as a tier 1 one. So tier also pays a flat bonus on top: {{kickerUsd}} an hour for every tier above T1, on the first {{kickerHours}} hours of a project.

So a 10 hour T4 project earns {{kickerExampleUsd}}, about {{kickerExamplePx}}, on top of whatever its normal rate pays. Put together: 10 hours at T4 earns {{exampleRampUsd}} off the RE ramp (its own RE barely dents {{reCap}}, so the ramp alone is still close to base) plus the {{kickerExampleUsd}} kicker, for {{exampleTotalUsd}} total, about {{exampleTotalPx}}.

After that the bonus stops, because by then a high tier project is already earning RE several times faster than a low tier one, so its own rate has already climbed a long way up the ramp without needing the flat bonus's help.

## Levels

Your level is a display of lifetime RE and nothing more. Levels run 1 to {{maxLevel}}, each one costs more RE than the last, and they have **no effect on what you get paid**: the rate comes straight off RE. Level is just there so the shipping shows up somewhere.

| Levels {{band1From}}-{{band1To}} | {{band1Per}} RE per level | {{band1Total}} RE total |
| Levels {{band2From}}-{{band2To}} | {{band2Per}} RE per level | {{band2Total}} RE total |
| Levels {{band3From}}-{{band3To}} | {{band3Per}} RE per level | {{band3Total}} RE total |

Early levels are cheap on purpose: a couple of hours on your first project already moves you a level or two. The last level and the top pay rate land on the same amount of RE, so you hit both at once. RE keeps stacking past that, it just runs out of levels to show for it.

## Where to see all this

The bar at the top of your Builder Terminal shows your level, your lifetime RE and your current rate in pixels per hour. It updates as soon as a project is approved.

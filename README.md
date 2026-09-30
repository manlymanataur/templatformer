# Templatformer

A 3D platformer in the spirit of Zelda: Ocarina of Time and Sonic, built in Godot 4.5.

## Play

Every push to `main` runs the feel tests and publishes a web build to GitHub Pages.
Locally: open this folder in Godot 4.5 and press F5.

## Controls (test room)

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | WASD / arrows | left stick |
| Jump (hold for higher) | Space | A |
| Jump chain (Mario style) | jump again right as you land while running: double, then triple | |
| Wall jump | push into a wall in the air, then jump | |
| Roll (dodges hits) | while holding lock-on, a quick tap of a direction (no roll button) | same, quick flick of the stick |
| Lock on / strafe (hold) | Shift or Z | left trigger |
| Dodge while locked on | quick tap of the stick: sideways side hop, back backflip, forward roll | same |
| Camera | mouse (click to capture, Esc to release), or I J K L | right stick |
| Spear attack (once you've found it) | F or left click | X |
| Combo / long slash | tap attack up to 3 times / attack while running | |
| Homing attack / air slash | attack in the air while holding lock-on: you home in on the nearest monster or spike ball ahead, hit it and bounce up, ready to home in on the next (it doesn't stick to your lock-on target, so chains keep going). Nothing in reach: an air slash | |
| Perfect dodge | get hit during a roll's i-frames: no damage, and the world slows to 30% for 1.5 s while you don't | |
| Climb | push into vines (or a trunk) to climb as high as they go; jump kicks off | |
| Ledge grab | fall against a wall whose top is within 1.2 m above you: you hang. Push on or jump to pull up, pull away to drop. Iron is too smooth to grab | |
| Ground pound | attack in the air without lock-on (hands empty; no spear needed): a pause, then straight down at 30 m/s. Onto a monster or spikes it hits and bounces you up (pound again, or hold lock-on and attack to home in on the next). Onto flat ground, jump right away for a 5.4 m high jump, or hold a direction to roll out. Onto a slope, the fall turns into downhill speed | |
| Long jump | jump out of a roll: 20 m/s forward, about 12 m | |
| Combos | a wall kick counts as the first jump of the chain; rolls keep their speed and gain it downhill; slopes give the speed a triple jump needs | |
| Grind rail | land or walk onto a rail. Downhill speeds you up, uphill slows you; jump hops off | |
| Spin attack | hold attack until the tip glows, then let go | |
| Use quick item 1 / 2 / 3 | 1 / 2 / 3 | Y / LB / RB |
| Context action | E | B |
| | Picks up a seed cube or the spider, pulls a bomb off a bomb plant, pulls a planted seed back up. Holding something: moving throws it, standing still sets it down; a seed set down on soil, mud or roots plants | |
| Candle Hat (quick slot) | wear it to light the dark and set fire to vines, grass, ice and braziers | |
| Umbra (quick slot) | call or dismiss the mirrored ghost. It floats in the dark and crawls in light, and in the dark it copies your attacks with a greatsword | |
| Magnet (quick slot) | always on once you have it. The button flips it between − (pull) and + (push) | |
| Lash (quick slot) | crack it ahead, or at what you're locked on to: it pulls you to a post or trunk, fetches a seed into your hands, stings and yanks a monster, or hooks the clockwork spider on a taut rope. Press again to unhook. Hands must be empty | |
| Clockwork Spider (quick slot) | the first press sends it out and you steer it; each press after swaps between steering it and steering yourself. Pick it up with the context button | |
| Inventory (assign items to 1-3) | Enter | Start |
| Respawn | R | Back |

The panel in the corner edits every feel number live: `[` `]` pick a value, `-` `=` change it by 10%,
Backspace resets it, Tab hides the panel. Changes are saved and survive restarts.

### Playtest tools

| Key | What it does |
| --- | --- |
| G | Warp and debug menu: jump to any room, give every item, god mode, heal, shrink or grow |
| P | Feedback pin: type a note, press Enter, and a link to this exact spot (with your items, size and facing) is copied. Paste it in the project chat. |
| O | Load a pin: paste a pin link or code |

Opening a pin link loads the game straight into that spot.

## Moves yard

South of the start. One station per move: an 8 m vine tower to climb, a grind rail from its top that runs 4 m downhill (about 18 m/s) and kicks you over a 10 m gap, two spike balls to homing-pogo up to an 8 m ledge (touching spikes hurts), and a 3.5 m block to catch by the ledge. Hits freeze the game for a moment, shake the camera and throw sparks.

Three purple doors along the yard's north edge lead to challenge rooms: short courses floating high above the world, each built around one combo. Touch the star at the end and you're back by the door, which turns gold. Fall off and you start that course again.

- **Pogo chain.** Pound onto four spike balls in a row to bounce across a 25 m drop.
- **Rail run.** Two downhill rails, each kicking you over a 10 m gap.
- **Long jump.** Three 10 m gaps between 4 m platforms, too short for a run-up. Pound onto each platform, roll out and long-jump off the edge.

Speed above your running top speed (from slopes, pads, launches) bleeds back down on flat ground. Running downhill still builds it.

## Test colossus

East of the moves yard (warp: "Test colossus"). A 13 m stone beast walks a slow circle and stands still while you're on it. Its feet hurt if it steps on you.

- **Climb** the fur on the outside of either back leg, all the way up to its back.
- **Back sigil.** A bone plate covers it. Ground pound the plate to crack it off, then pound or hit the sigil.
- **Front shins.** Only a bomb breaks them (two bomb plants grow at the arena's north edge). With one gone it limps; with both gone it falls to its knees.
- **Forehead sigil.** It opens once it kneels, low enough to hit from the ground. Strike both sigils and it falls apart.

## Rootworks

Winch and Propagule, north-east of the monster arena up a 6 m ramp. The lash and the clockwork spider lie at the ramp's foot.

- **Seeds** (Propagule) are 2 m cubes, one grid cell, big enough to jump on. Set down on soil, mud or roots, a seed plants: a trunk grows from its top to 8 m (or to the ceiling), and four roots run along the ground, each straight out until something blocks it (18 m at most). Roots bridge gaps; trunks can be climbed and lashed to. A seed that falls 3 m or more onto mud spears in and plants itself. Your hands are full while you carry one.
- **Lash** (Winch's leash and Propagule's lash in one rope). It reaches 16 m. Hooked on the spider it's a taut 16 m rope: it runs straight and only bends around walls, ledges, gears and cubes, letting go of a bend once it swings clear. At full length, whichever of you you're steering drags the other.
- **Clockwork Spider** (Winch's walker). It's as big as you: bars and grates stop it, and you can stand on it. The spider button swaps who you steer. It turns any gear it walks past. Unhooked, it breaks more than 30 m from you and goes back in your pack.
- **Gears.** A gear turns when the spider walks past its teeth or when the rope, bent round it, slides over it (0.5 m of lift per metre). It keeps its angle when the rope comes off, so you can wind it over several trips.
- **Bomb plants.** Bombs aren't an item. Pull one off a bomb plant with the context button and carry it; the plant grows another in 4 s.

The rooms:
1. **Root bridge.** Plant the seed on the soil at the edge of a 14 m chasm, and walk its root across.
2. **Lash ledge.** Lock on to the seed on the 4.5 m ledge and lash it down. Plant it in the mud at the ledge's foot, then climb the trunk (or jump on the cube and catch the ledge) for the heart.
3. **Lash post.** Lock on to the post across the second 14 m chasm and lash it to be pulled over.
4. **Gear room.** The gear is in a cage of bars. Lash the spider and steer it round the cage, south side first, so the rope loops the gear; keep going and the rope slides over it, dragging you to the cage, and the gate to the heart rises.

## Ember & Umbra hall

Up the ramp behind the start. The hall is dark, so light is a rule, not just a look:

- The candle hat lights about 12 m around you and sets fire to what you touch. While you wear it, your spear attacks are on fire too. Fire spreads through grass, burns vines away, melts ice and lights braziers.
- Umbra copies your movement, mirrored left to right (the mirror line is the camera's left-right when you call it). Walls stop it separately from you.
- In the dark Umbra floats at its height, even over a chasm. In light it drops to the ground and crawls. Light that hits it over a chasm drops it in, and you call it again.
- Your body casts a shadow for Umbra, unless you're wearing the lit candle.
- Moon plates only react to Umbra.
- Umbra appears 1.5 m beside you, on the mirror line.
- In the dark Umbra copies each of your spear moves, mirrored, with a greatsword (2 damage). Lit, it's too limp to swing.

## Lodestone yard

East of the ramps, on a 2 m grid. Pick up the magnet at the south edge.

- Iron blocks are 2 m wide and 4.5 m tall: a running triple jump clears one, a double can't.
- Iron blocks slide one cell at a time along the grid. Your magnet only moves a cube when you stand at one of its sides (in its row or column), never from a diagonal, and only the nearest cube in each line. Walls and other iron shield what's behind them.
- Pull (−) draws a cube until it's beside you. Push (+) drives it until something stops it.
- Batteries power iron touching their sides, and power runs through iron touching iron. Doors and dead pads come alive while powered iron (or a battery) touches them.
- Three stations: a powered door, a dead launch pad under a 6 m block, and a dead boost pad that fires you across a 14 m gap.


## Scale garden

West of the gap course. Green shrink pads make you small, orange grow pads make you normal again (if there's room).

- Small you're a third of the size, run at 60% speed and jump about 1 m.
- Small you slip through grates, fences and bars, float on water and ride fans. You're too light to crack a cracked floor.
- At normal size you sink in water, your weight breaks cracked floors a moment after you stand on them, and a roll bursts cracked walls. Bombs burst them at any size.
- Growing needs room. You can't grow inside a grate.
- Small with the magnet, iron moves you instead of you moving it. Pull flies you along an iron's line to its side and you cling there. Push flies you away. Its reach is 22 m.
- Three stations:
  - A grate room with a cracked floor and a cracked wall.
  - A 16 m pond with a covered fan vent under an 8 m tower.
  - A 16 m chasm you cross with the magnet (bring it from the Lodestone yard).

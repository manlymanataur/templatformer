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
| Roll (dodges hits) | C | B |
| Lock on / strafe (hold) | Shift or Z | left trigger |
| Dodge while locked on | quick tap of the stick: sideways side hop, back backflip, forward roll | same |
| Camera | mouse (click to capture, Esc to release), or I J K L | right stick |
| Spear attack (once you've found it) | F or left click | X |
| Combo / long slash / air slash | tap attack up to 3 times / attack while running / attack in the air | |
| Spin attack | hold attack until the tip glows, then let go | |
| Use quick item 1 / 2 / 3 | 1 / 2 / 3 | Y / LB / RB |
| Bomb: throw or set down | pull one out with its item button, then press attack or the button again. Moving throws it, standing still sets it down | |
| Candle Hat (quick slot) | wear it to light the dark and set fire to vines, grass, ice and braziers | |
| Umbra (quick slot) | call or dismiss the mirrored ghost. It floats in the dark and crawls in light, and in the dark it copies your attacks with a greatsword | |
| Magnet (quick slot) | always on once you have it. The button flips it between − (pull) and + (push) | |
| Inventory (assign items to 1-3) | Enter | Start |
| Respawn | R | Back |

The panel in the corner edits every feel number live: `[` `]` pick a value, `-` `=` change it by 10%,
Backspace resets it, Tab hides the panel. Changes are saved and survive restarts.

## Ember & Umbra hall

Up the ramp behind the start. The hall is dark, so light is a rule, not just a look:

- The candle hat lights about 12 m around you and sets fire to what you touch. While you wear it, your spear attacks are on fire too. Fire spreads through grass, burns vines away, melts ice and lights braziers.
- Umbra copies your movement, mirrored left to right (the mirror line is the camera's left-right when you call it). Walls stop it separately from you.
- In the dark Umbra floats at its height, even over a chasm. In light it drops to the ground and crawls. Light that hits it over a chasm drops it in, and you call it again.
- Your body casts a shadow for Umbra, unless you're wearing the lit candle.
- Moon plates only react to Umbra.
- In the dark Umbra copies each of your spear moves, mirrored, with a greatsword (2 damage). Lit, it's too limp to swing.

## Lodestone yard

East of the ramps, on a 2 m grid. Pick up the magnet at the south edge.

- Iron cubes slide one cell at a time along the grid. Your magnet only moves a cube when you stand at one of its sides (in its row or column), never from a diagonal, and only the nearest cube in each line. Walls and other iron shield what's behind them.
- Pull (−) draws a cube until it's beside you. Push (+) drives it until something stops it.
- Batteries power iron touching their sides, and power runs through iron touching iron. Doors and dead pads come alive while powered iron (or a battery) touches them.
- Three stations: a powered door, a dead launch pad under a 6 m block, and a dead boost pad that fires you across a 14 m gap.


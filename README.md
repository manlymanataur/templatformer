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
| Lock on | Shift or Z (hold) | left trigger |
| Camera | mouse (click to capture, Esc to release), or I J K L | right stick |
| Respawn | R | Back |

The panel in the corner edits every feel number live: `[` `]` pick a value, `-` `=` change it by 10%,
Backspace resets it, Tab hides the panel. Changes are saved and survive restarts.

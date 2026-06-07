# Retro Space Shooter

A fast-paced ASCII space shooter written entirely in **Bash**. Pilot your ship through endless enemy waves, battle powerful bosses, dodge incoming fire, and chase the highest score—all from your terminal.

---

## Features

* 🚀 ASCII-art player spaceship
* 👾 Multiple enemy types

  * Scout
  * Fighter
  * Heavy
  * Boss
* 💥 Explosion animations
* 🔫 Continuous shooting system
* ❤️ Health system
* 📈 Progressive wave difficulty
* 👑 Boss battles every 5th wave
* 🎯 Score tracking
* 💾 Persistent high scores
* ⭐ Animated starfield background
* 📏 Dynamic terminal resize support
* ⏸ Pause and resume gameplay
* 🖥 Pure Bash implementation

---

## Preview

```text
HP [#####]
SCORE 000420   HIGH 001200
WAVE 05   BOSS

                 .      .
        .                     .

            \||/
           <====>

                    !
                    !

        __/====\__
       |___====___|
          /_||_\
```

---

## Requirements

* Bash 4+
* Linux, macOS, or WSL
* Terminal supporting ANSI escape sequences
* Minimum terminal size:

```text
40 x 18
```

Recommended:

```text
80 x 24
```

---

## Project Structure

```text
retro-space-shooter/
├── data/
│   └── highscore.dat
├── src/
│   ├── config.sh
│   ├── input.sh
│   ├── render.sh
│   └── explosion.sh
├── game.sh
└── README.md
```

### Files

| File           | Description                             |
| -------------- | --------------------------------------- |
| `game.sh`      | Main game engine and gameplay loop      |
| `config.sh`    | Game configuration and balancing values |
| `input.sh`     | Keyboard input and terminal handling    |
| `render.sh`    | Screen rendering and HUD system         |
| `explosion.sh` | Explosion sprite animations             |

---

## Controls

| Key     | Action         |
| ------- | -------------- |
| `A`     | Move Left      |
| `D`     | Move Right     |
| `SPACE` | Fire           |
| `P`     | Pause / Resume |
| `Q`     | Quit           |

---

## Installation

Clone the repository:

```bash
git clone https://github.com/yourusername/retro-space-shooter.git
cd retro-space-shooter
```

Make scripts executable:

```bash
chmod +x game.sh
chmod +x src/*.sh
```

Run the game:

```bash
./game.sh
```

---

## Gameplay

### Enemies

#### Scout

```text
 .--.
 (oo)
 '--'
```

* Fast
* 1 HP
* 10 points

---

#### Fighter

```text
 \||/
<====>
 /||\
```

* Medium speed
* 2 HP
* 20 points

---

#### Heavy

```text
 /MMMM\
|MMMMMM|
 \MMMM/
  \/\/
```

* Slow
* Fires bullets
* 3 HP
* 50 points

---

#### Boss

Appears every 5th wave.

```text
   .-========-.
 _/  X    X   \_
|      /\       |
|   \______/    |
 \____________/
```

* Massive HP pool
* Fires frequently
* Worth 500 points

---

## Scoring

| Enemy   | Points |
| ------- | ------ |
| Scout   | 10     |
| Fighter | 20     |
| Heavy   | 50     |
| Boss    | 500    |

High scores are automatically saved to:

```text
data/highscore.dat
```

---

## Configuration

Game settings can be adjusted in:

```bash
src/config.sh
```

Examples:

```bash
PLAYER_HP_MAX=5
PLAYER_SPEED=2
PLAYER_FIRE_COOLDOWN=2

FRAME_DELAY=0.045

STAR_COUNT=42
```

You can customize:

* Player health
* Movement speed
* Fire rate
* Game speed
* Enemy projectile speed
* Starfield density
* Screen requirements

---

## Development

The game is intentionally split into modular components:

### Input Layer

Handles:

* Raw keyboard input
* Terminal setup
* Terminal restoration

### Rendering Layer

Handles:

* Sprite drawing
* HUD rendering
* Screen updates
* Coordinate-based rendering

### Game Engine

Handles:

* Enemy spawning
* Collision detection
* Wave progression
* Score tracking
* AI behavior

### Effects Layer

Handles:

* Explosion animations
* Visual feedback

---

## Known Limitations

* Single-player only
* No sound effects
* Terminal-based graphics
* Requires ANSI-compatible terminal

---

## Future Ideas

* Power-ups
* Multiple weapons
* Shield system
* Enemy formations
* Multiplayer mode
* Colorized sprites
* Save/load campaigns
* Boss attack patterns
* Particle effects

---

## License

MIT License

Feel free to modify, distribute, and improve the game.

---

## Author

Siddharth Verma

Built with Bash and ASCII graphics for retro terminal gaming enthusiasts.

⭐ If you enjoy the project, consider starring the repository.



# Gravity Force LÖVE2D Clone

A physics-based cave flyer game inspired by the classic Amiga game *Gravity Force*, built with the **LÖVE** (Love2D) engine.

## 🚀 Getting Started

### Prerequisites

Ensure you have [LÖVE 11.5+](https://love2d.org/) and [just](https://github.com/casey/just) installed.

### Commands

We use `just` as a command runner:

*   **Run the game:**
    ```bash
    just
    # or
    just run
    ```
*   **Run unit tests:**
    ```bash
    just test
    ```

---

## 🎮 Controls

*   **A** / **D**: Rotate the ship left / right
*   **W**: Fire thrusters (accelerate in current heading)
*   **R**: Reset ship back to the starting platform
*   **Esc**: Quit the game

---

## 📂 Project Structure

```
├── src/
│   ├── conf.lua     # Window config (1024x768, VSync)
│   ├── main.lua     # Game entry, main loop & HUD
│   ├── ship.lua     # Ship physics & collision engine
│   ├── world.lua    # Level terrain definitions
│   └── tests.lua    # Test suite for physics & collision
├── justfile         # Script commands runner
├── LICENSE          # MIT License
└── README.md        # This file
```

---

## 🧪 Testing

We have built-in axis-aligned bounding box (AABB) collision unit tests verifying:
*   Landing on platforms (top surface gravity snapping & friction damping)
*   Ceiling collisions (bottom surface pushback)
*   Wall collisions (side pushback & velocity zeroing)

You can run these via `just test`.

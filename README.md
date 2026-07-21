# StarWarsVR : Godot 4 Prototype

> A VR combat simulation focused on realistic lightsaber physics, vector-based projectile deflection, and immersive interactions. Built with **Godot 4** and **Godot XR Tools**

This project serves as a technical case study on advanced VR mechanics. The goal is not just to recreate the visual fidelity of Star Wars, but to capture the **"Game Feel"** of Jedi combat by solving common VR development challenges such as *object tunneling* and imprecise *haptic feedback*.

## ⚙️ Key Technical Features

### ⚔️ Vector-Based Blaster Deflection
The deflection mechanic uses real-time vector math rather than random scattering to simulate collisions with a cylindrical energy blade:
* **Cylindrical Normal Calculation:** The reflection logic ignores the impact height along the blade, calculating the normal based on the cylinder's rotation. This ensures projectiles always ricochet outwards horizontally, rather than erratically upwards.
* **Active vs. Passive Defense:** The system detects the player's "swing" velocity. A stationary blade performs a passive bounce (block), while swinging against the projectile adds the arm's force vector to the reflection.
* **Auto-Aim Assist:** A dot-product algorithm subtly adjusts the reflected trajectory towards enemies if the player performs a roughly correct swing, compensating for the lack of precise depth perception in VR.

### 🚀 Anti-Tunneling Solution (Ghosting Prevention)
To prevent high-speed blasters from passing through the lightsaber blade between frames:
* Implemented **Predictive Raycasting** via code (`PhysicsRayQueryParameters3D`).
* The script calculates where the projectile *will be* in the next frame and checks for collisions before moving the object, ensuring 100% impact detection even at high velocities.

### 📳 Procedural Haptic Feedback
The controller vibration system responds dynamically to player actions:
* **Ignition:** High-amplitude, low-frequency (60Hz) pulse to simulate the raw energy surge.
* **Retraction:** Short, high-frequency pulse for the mechanical "power down" sensation.

## 🛠️ Tech Stack

* **Engine:** Godot 4.6 (GDScript)
* **Framework:** [Godot XR Tools](https://github.com/GodotVR/godot-xr-tools) 4.5.1 (vendored under `addons/`)
* **Target Hardware:** Meta Quest 2 / 3S / 3 (Standalone & PCVR)

## 🚀 Getting Started

1. Install **Godot 4.6** (standard build — the project uses GDScript only).
2. Clone and open the project. Godot XR Tools ships in `addons/`, so there is nothing extra to install.
3. Main scene: `Scenes/Testing/LightSaberHoldingBehaviour.tscn`.

Without a headset the project falls back to flat mode, so scenes can still be opened and run on a
desktop for iteration. Set `quit_if_no_xr` on the `XRInitializer` node to `true` if you would rather
it exit when no OpenXR runtime is found.

### Controls

| Action | Input |
| --- | --- |
| Grab / release the saber | Grip on either controller |
| Ignite / retract the blade | `by_button` (B / Y) while holding the saber |
| Move / turn | Left stick / right stick |
| Holster | Bring the saber to the snap zone at the waist |

## 📸 Showcase of Actual Status


![StarWarsVR](https://github.com/user-attachments/assets/f56eefba-e875-43bd-9eea-3e36b7370151)


## 🚧 Roadmap & Future Improvements

### ✅ To-Do (Upcoming Features)
- [ ] **Advanced Enemy AI:** Implement behavior trees for enemies to flank and take cover instead of standing still.
- [ ] **Force Powers:** Add gesture-based recognition for "Force Push" and "Force Pull".
- [ ] **Spatial Audio:** Tune the 3D attenuation curves and unit sizes (the saber players are now `AudioStreamPlayer3D`, but still on default falloff).
- [ ] **Destructible Environment:** Allow lightsaber marks on walls and floors (Decal system).


### 🔧 Polishing & Fixes
- [ ] **Visuals:** Add bloom and particle effects for blaster impacts.
- [ ] **Performance:** Optimize geometry for standalone Quest 2 target (LOD implementation).
- [ ] **UX:** Add a visual tutorial for the holster mechanic.

### 🐛 Known Issues
- *Physics Jitter:* Rare physics instability when the saber collides with complex geometry at high speeds.

### ✔️ Recently Fixed
- **Hand Pose / Snap Zone:** both traced to the same root cause — `LightSaberSettings._ready()`
  overrode `XRToolsPickable._ready()` without calling `super()`, so the addon never collected the
  saber's grab points. The saber was being grabbed by the RigidBody origin instead of the hilt.
- **Bolt spawn position:** `top_level` was flipped *after* the bolt's global position was written,
  which reinterpreted the local transform and offset every shot by the turret's transform.
- **Deflection crash:** a bolt hitting the hilt (same physics layer as the blade) resolved to the
  wrong node and called `get_saber_velocity()` on it. Impacts now resolve through the
  `lightsaber_blade` group and a typed ancestor walk.
- **Runaway bolts:** an impact on the blade axis produced a zero-length normal, so the bolt kept
  its direction, stayed inside the blade and gained 50% speed every frame. Deflections now have a
  fallback normal, a speed ceiling and a clearance step.

## 🎨 Credits & Assets
This project is for educational and portfolio purposes. Star Wars visual and audio assets belong to Disney/Lucasfilm.

**Programming, Lightsaber animation**: Matheus Soares ([@MrVeGGi3](https://github.com/MrVeGGi3))

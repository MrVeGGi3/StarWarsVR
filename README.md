# StarWarsVR : Godot 4 Prototype

> A VR combat simulation focused on realistic lightsaber physics, vector-based projectile deflection, Force powers, and immersive interactions. Built with **Godot 4** and **Godot XR Tools**

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

### 🤚 Hand-Locked Saber & Belt Holster
The saber behaves like a weapon you commit to, not a prop you juggle:
* **Stuck to the hand:** Once drawn, the holding hand's pickup is disabled while no holster is in
  range, so releasing the grip never drops the blade mid-fight.
* **Belt holster:** Bringing the hilt back inside a hip snap-zone re-enables the grip and a press
  stows the saber; distance is measured from the active grab-point so the hilt collider is always
  overlapping the zone when the drop fires.
* **Draw-to-ignite:** Pulling the saber from the belt ignites the blade automatically; picking it
  up off the floor leaves it as it was.

### 🙌 Two-Handed Grip (Djem So)
The free hand can grab the hilt for a braced, two-handed stance:
* **Aim drive:** The second hand steadies and steers the blade's orientation via XR Tools' grab
  drive, giving a heavier, more deliberate guard.
* **Stronger block:** A deflection performed two-handed returns the bolt tighter and faster than a
  one-handed parry.
* **Hand swapping:** A single re-sync keeps the lock, the blade button and the forced grip on
  whichever hand is primary after either hand lets go.

### ✋ Force Push & Pull
Gesture-driven telekinesis on the empty hand (the saber hand cannot use the Force; both hands free
boosts the power):
* **Push:** Hold the trigger and thrust the controller forward to blast everything in a cone away
  from the palm.
* **Pull:** Trigger plus grip locks onto the object nearest the aim line, floats it to the palm,
  and releasing with a shove throws it.
* **Cheap targeting:** Candidates are filtered by squared distance and a dot-product against the
  aim — no physics queries — so the cost stays flat as the scene fills up.

### 🤖 Training Remote AI
A Jedi training droid that circles and tests the player:
* **State loop:** Orbits at head height varying altitude and distance, stops, draws one of eight
  firing ports, swings it onto the player behind a red charge-up telegraph, then fires — or feints,
  breaking off without a shot.
* **Bursts & heights:** Fires up to three shots per stop, each at a fresh band (head, chest,
  thigh). Aim heights are fractions of the player's head-above-floor height with a posture-aware
  floor clamp, so a **seated** player is never shot at the feet.
* **Spatial audio:** A looping hover whose pitch rides the orbit speed, a servo click on stop, and
  a charge/shot pair emitted from the drawn port so the shot can be located by ear.

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
| Draw the saber from the belt | Grip near a hip snap-zone (auto-ignites) |
| Ignite / retract the blade | `by_button` (B / Y) while holding the saber |
| Stow the saber | Bring the hilt to a hip snap-zone and press grip |
| Two-handed grip | Grab the hilt with the free hand |
| Force Push | Hold the trigger and thrust the hand forward (empty hand) |
| Force Pull / throw | Trigger + grip to pull, release with a shove to throw (empty hand) |
| Move / turn | Left stick / right stick |

## 📸 Showcase of Actual Status


![StarWarsVR](https://github.com/user-attachments/assets/f56eefba-e875-43bd-9eea-3e36b7370151)


## 🚧 Roadmap & Future Improvements

### ✅ To-Do (Upcoming Features)
- [ ] **Advanced Enemy AI:** The training remote orbits, telegraphs and feints; next is enemies that flank and take cover. The `force_push()` hook is already in place for when they need to react to a shove.
- [ ] **Destructible Environment:** Allow lightsaber marks on walls and floors (Decal system).
- [ ] **Saber SFX polish:** Charge/servo/hover streams are wired on the droid; still need charge and travel sounds on the saber and bolts.


### 🔧 Polishing & Fixes
- [ ] **Visuals:** Add bloom and particle effects for blaster impacts.
- [ ] **Performance:** Optimize geometry for standalone Quest 2 target (LOD implementation).
- [ ] **UX:** Add a visual tutorial for the holster mechanic.

### 🐛 Known Issues
- *Physics Jitter:* Rare physics instability when the saber collides with complex geometry at high speeds.

### ✔️ Recently Added
- **Force Push & Pull** on the empty hand, with an empty-hands power boost.
- **Two-handed grip** with aim-drive stabilisation and a stronger deflection.
- **Training remote AI** (orbit, telegraph, burst, feint) with posture-aware aim heights and
  positional audio.
- **Hand-locked saber + belt holster**, drawing from the belt auto-ignites the blade.
- **Per-shooter bolt colour** (yellow training bolts vs red turret bolts).

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

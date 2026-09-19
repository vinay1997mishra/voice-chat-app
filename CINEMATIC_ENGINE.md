# V7.5 Cinematic 3D/4D Engine

## Offline cinematic pipeline

V7.5 renders and exports locally with Android OpenGL ES + MediaCodec. Runtime does not require
GitHub, an AI API, a website, or an animation server.

### Implemented cinematic scene
- Procedural articulated 3D dragon fallback (body, chest, neck, head, muzzle, horns, four limbs, tail, wings, dorsal spikes)
- Scripted sky-circle -> spiral descent -> landing choreography
- Continuous wing flap and tail wave
- Two fire-breath windows
- Cloud/fog particle layers
- Cinematic follow/wide/close camera phases
- Landing camera shake + impact ring
- Depth/parallax from real perspective projection
- Motion-trail echoes during fast descent
- PBR-inspired diffuse/specular/rim lighting shader
- 720p / 1080p30 / 1080p60 / 2K / 4K export choices
- H.264 MP4 hardware encoding through MediaCodec

## Meaning of “4D” in this mobile app
A phone video is still a 2D display. V7.5 uses “4D” as an immersive presentation mode:
depth, parallax, camera motion, impact shake, temporal motion effects, fog, light and particles.
It does not claim physical 4D cinema effects such as moving seats, wind or water.

## Film-grade asset path
The included procedural dragon proves the full offline choreography/export pipeline. For
feature-film creature detail, bundle a licensed rigged PBR dragon GLB and map its animation clips
to the same DragonFlightPath timeline. High-detail geometry/textures cannot be fabricated by a
small procedural mesh with movie-level fidelity.


## V7.5 Universal Subjects
V7.5 adds a prompt-selected subject layer for dragon, phoenix, eagle, wolf, lion, supercar, spaceship, robot, crystal/logo and a custom-asset extension slot. Procedural geometry is a fallback; production movie realism requires appropriate rigged/PBR assets or a dedicated local text-to-3D model.

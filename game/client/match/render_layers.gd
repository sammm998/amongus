class_name RenderLayers
extends RefCounted
## Visual layer bits shared by cameras and avatars.

const WORLD := 1
const NAME_TAGS := 2
const AVATARS := 16
const REPLAY_GHOSTS := 32
## Main camera: everything except replay ghosts.
const MAIN_CAMERA := 0xFFFFF & ~REPLAY_GHOSTS
## Live security feeds: world + avatars, never name tags.
const LIVE_FEED := WORLD | AVATARS
## Replay feeds: world + ghosts from the recording, never the live avatars.
const REPLAY_FEED := WORLD | REPLAY_GHOSTS

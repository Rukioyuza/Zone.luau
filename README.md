<h1 align="left">Zone</h1>

<p align="left">
  <img src="https://img.shields.io/badge/Roblox-181717?style=for-the-badge&logo=roblox&logoColor=white" />
  <img src="https://img.shields.io/badge/Luau-181717?style=for-the-badge&logo=luau&logoColor=00A2FF" />
  <img src="https://img.shields.io/badge/Types-Strict-181717?style=for-the-badge" />
</p>

Know when players walk into and out of an area. A zone is a box at any rotation, made from a part or from a CFrame and a size.

---

### About

Zone checks each player's `HumanoidRootPart` against the box a few times a second and fires an event when a player goes in or comes out.

- **No physics queries.** Each check moves the point into the box's frame with three dot products and compares it to half the size.
- **Not every frame.** Checks run on `Heartbeat` at a rate you choose, 10 a second by default.
- **Spread out.** Each zone starts at a random point in its interval, so many zones do not all check on the same frame.
- **Rotated boxes.** The box keeps its rotation, so a turned part is a turned zone.
- **Follows its part.** A zone made from a part moves and resizes with it, and is destroyed when the part is.
- **Self contained.** Its events are built in, so there is nothing else to install.

---

### Usage

```luau
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zone = require(ReplicatedStorage.Zone)

local shop = Zone.fromPart(workspace:WaitForChild("ShopArea") :: BasePart)

shop.playerEntered:connect(function(player: Player)
	print(player.Name, "entered the shop")
end)

shop.playerExited:connect(function(player: Player)
	print(player.Name, "left the shop")
end)

local arena = Zone.fromBox(CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(40, 20, 40), {
	checksPerSecond = 4,
})

print(arena:findPoint(Vector3.new(0, 10, 0))) -- true
print(arena:findPoint(Vector3.new(0, 30, 0))) -- false
print(#arena:getPlayers()) -- players inside as of the last check

arena:destroy()
```

---

### API

| Function | Returns | Purpose |
| --- | --- | --- |
| `Zone.fromPart(part, config?)` | `Zone` | A zone that follows `part` and is destroyed with it |
| `Zone.fromBox(CFrame, size, config?)` | `Zone` | A zone that stays where it was made |
| `playerEntered:connect(handler)` | connection | Runs `handler(player)` when a player comes in |
| `playerExited:connect(handler)` | connection | Runs `handler(player)` when a player goes out or leaves the game |
| `getPlayers()` | `{ Player }` | The players inside as of the last check |
| `isPlayerInside(player)` | `boolean` | Whether the player was inside at the last check |
| `findPoint(point)` | `boolean` | Whether a point is inside the box right now |
| `check()` | | Checks every player now instead of waiting for the next interval |
| `destroy()` | | Stops checking and disconnects every handler |

A connection has `disconnect()` and `connected`. Events also have `disconnectAll()`.

---

### Behaviour

- **Late by one interval at most.** A change is seen at the next check, so a player who crosses a zone faster than one interval may never be seen.
- **Respawning.** A player is inside through one character. When they respawn, they exit, and enter again only if the new character is inside.
- **Leaving the game.** A player inside who leaves fires `playerExited` straight away.
- **Destroy.** Destroying a zone fires no exits.
- **Handlers.** Each handler runs on its own thread with `task.spawn`, so one that yields or errors does not hold up the rest.

---

### Configuration

| Field | Default | Purpose |
| --- | --- | --- |
| `checksPerSecond` | `10` | How often the zone checks players. `math.huge` checks every frame |

---

### Install

- **Rojo.** Sync `src` with the included `default.project.json`; it builds a ModuleScript named `Zone`.
- **By hand.** Copy `src/init.luau` into a ModuleScript named `Zone` and `src/OrientedBox.luau` into its child ModuleScript `OrientedBox`.

---

### Tests

The box test runs under the standalone `luau` CLI. From the repo root:

```bash
luau tests/OrientedBox.test.luau
```

The rest of Zone needs a running Roblox server, so it is type checked against Roblox's definitions rather than run.

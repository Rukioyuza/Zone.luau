--!strict

local OrientedBox = require("@self/OrientedBox")

type OrientedBox = OrientedBox.OrientedBox

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DEFAULT_CHECKS_PER_SECOND = 10

export type Config = {
	checksPerSecond: number?,
}

type PlayerConnectionImpl = {
	__index: PlayerConnectionImpl,
	disconnect: (self: PlayerConnection) -> (),
}

type PlayerConnectionData = {
	connected: boolean,
	handler: (player: Player) -> (),
	event: PlayerEvent,
}

export type PlayerConnection = setmetatable<PlayerConnectionData, PlayerConnectionImpl>

type PlayerEventImpl = {
	__index: PlayerEventImpl,
	new: () -> PlayerEvent,
	connect: (self: PlayerEvent, handler: (player: Player) -> ()) -> PlayerConnection,
	fire: (self: PlayerEvent, player: Player) -> (),
	disconnectAll: (self: PlayerEvent) -> (),
}

type PlayerEventData = {
	connections: { PlayerConnection },
}

export type PlayerEvent = setmetatable<PlayerEventData, PlayerEventImpl>

type ZoneImpl = {
	__index: ZoneImpl,
	fromPart: (part: BasePart, config: Config?) -> Zone,
	fromBox: (Frame: CFrame, size: Vector3, config: Config?) -> Zone,
	check: (self: Zone) -> (),
	getPlayers: (self: Zone) -> { Player },
	isPlayerInside: (self: Zone, player: Player) -> boolean,
	findPoint: (self: Zone, point: Vector3) -> boolean,
	destroy: (self: Zone) -> (),
}

type ZoneData = {
	read playerEntered: PlayerEvent,
	read playerExited: PlayerEvent,
	part: BasePart?,
	box: OrientedBox,
	interval: number,
	elapsed: number,
	inside: { [Player]: Model },
	connections: { RBXScriptConnection },
	destroyed: boolean,
}

export type Zone = setmetatable<ZoneData, ZoneImpl>

local function characterInside(box: OrientedBox, player: Player): Model?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	if not OrientedBox.contains(box, root.Position) then
		return nil
	end

	return character
end

local function readInterval(config: Config?): number
	if config == nil then
		return 1 / DEFAULT_CHECKS_PER_SECOND
	end
	assert(type(config) == "table", `Zone expects config to be a table, got {typeof(config)}`)

	local checksPerSecond = config.checksPerSecond or DEFAULT_CHECKS_PER_SECOND
	assert(
		type(checksPerSecond) == "number" and checksPerSecond > 0,
		`Zone expects ChecksPerSecond to be a number above 0, got {checksPerSecond}`
	)

	return 1 / checksPerSecond
end

local PlayerConnection = {} :: PlayerConnectionImpl
PlayerConnection.__index = PlayerConnection

local PlayerEvent = {} :: PlayerEventImpl
PlayerEvent.__index = PlayerEvent

local Zone = {} :: ZoneImpl
Zone.__index = Zone

local function newZone(part: BasePart?, box: OrientedBox, config: Config?): Zone
	local interval = readInterval(config)

	local self: ZoneData = {
		playerEntered = PlayerEvent.new(),
		playerExited = PlayerEvent.new(),
		part = part,
		box = box,
		interval = interval,
		elapsed = math.random() * interval,
		inside = {},
		connections = {},
		destroyed = false,
	}
	local created = setmetatable(self, Zone)

	table.insert(
		self.connections,
		RunService.Heartbeat:Connect(function(deltaTime: number): ()
			created.elapsed += deltaTime
			if created.elapsed < created.interval then
				return
			end
			created.elapsed = 0
			created:check()
		end)
	)

	table.insert(
		self.connections,
		Players.PlayerRemoving:Connect(function(player: Player): ()
			if created.inside[player] == nil then
				return
			end
			created.inside[player] = nil
			created.playerExited:fire(player)
		end)
	)

	if part then
		table.insert(
			self.connections,
			part.Destroying:Connect(function(): ()
				created:destroy()
			end)
		)
	end

	return created
end

function PlayerConnection.disconnect(self: PlayerConnection): ()
	if not self.connected then
		return
	end
	self.connected = false

	local connections = self.event.connections
	local index = table.find(connections, self)
	if index then
		table.remove(connections, index)
	end
end

function PlayerEvent.new(): PlayerEvent
	local self: PlayerEventData = {
		connections = {},
	}
	return setmetatable(self, PlayerEvent)
end

function PlayerEvent.connect(self: PlayerEvent, handler: (player: Player) -> ()): PlayerConnection
	assert(type(handler) == "function", "Zone events expect a function, nothing was connected")

	local connection: PlayerConnectionData = {
		connected = true,
		handler = handler,
		event = self,
	}
	local connected = setmetatable(connection, PlayerConnection)
	table.insert(self.connections, connected)

	return connected
end

function PlayerEvent.fire(self: PlayerEvent, player: Player): ()
	for _, connection in table.clone(self.connections) do
		if connection.connected then
			task.spawn(connection.handler, player)
		end
	end
end

function PlayerEvent.disconnectAll(self: PlayerEvent): ()
	for _, connection in self.connections do
		connection.connected = false
	end
	table.clear(self.connections)
end

function Zone.fromPart(part: BasePart, config: Config?): Zone
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), `Zone.fromPart expects a BasePart, got {typeof(part)}`)

	return newZone(part, OrientedBox.fromCFrame(part.CFrame, part.Size), config)
end

function Zone.fromBox(frame: CFrame, size: Vector3, config: Config?): Zone
	assert(typeof(frame) == "CFrame", `Zone.fromBox expects a CFrame, got {typeof(frame)}`)
	assert(typeof(size) == "Vector3", `Zone.fromBox expects a Vector3 size, got {typeof(size)}`)
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, `Zone.fromBox expects every side of the size above 0, got {size}`)

	return newZone(nil, OrientedBox.fromCFrame(frame, size), config)
end

function Zone.check(self: Zone): ()
	local part = self.part
	if part then
		self.box = OrientedBox.fromCFrame(part.CFrame, part.Size)
	end

	for _, player in Players:GetPlayers() do
		if self.destroyed then
			return
		end

		local character = characterInside(self.box, player)
		local tracked = self.inside[player]
		if character == tracked then
			continue
		end

		if tracked then
			self.inside[player] = nil
			self.playerExited:fire(player)
		end

		if character then
			self.inside[player] = character
			self.playerEntered:fire(player)
		end
	end
end

function Zone.getPlayers(self: Zone): { Player }
	local inside: { Player } = {}
	for player in self.inside do
		table.insert(inside, player)
	end
	return inside
end

function Zone.isPlayerInside(self: Zone, player: Player): boolean
	return self.inside[player] ~= nil
end

function Zone.findPoint(self: Zone, point: Vector3): boolean
	assert(typeof(point) == "Vector3", `Zone:findPoint expects a Vector3, got {typeof(point)}`)

	local part = self.part
	if part then
		self.box = OrientedBox.fromCFrame(part.CFrame, part.Size)
	end

	return OrientedBox.contains(self.box, point)
end

function Zone.destroy(self: Zone): ()
	if self.destroyed then
		return
	end
	self.destroyed = true

	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	table.clear(self.inside)

	self.playerEntered:disconnectAll()
	self.playerExited:disconnectAll()
end

return Zone

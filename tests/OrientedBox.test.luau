--!strict

local OrientedBox = require("../src/OrientedBox")

type OrientedBox = OrientedBox.OrientedBox

local passed = 0
local failed = 0

local function test(name: string, body: () -> ()): ()
	local finished, problem = pcall(body)
	if finished then
		passed += 1
	else
		failed += 1
		print(`FAIL {name}: {problem}`)
	end
end

local function expect(condition: boolean, message: string): ()
	if not condition then
		error(message, 2)
	end
end

local function vec(x: number, y: number, z: number): Vector3
	return vector.create(x, y, z) :: any
end

local function frame(position: Vector3, right: Vector3, up: Vector3, look: Vector3): CFrame
	local fake = {
		Position = position,
		RightVector = right,
		UpVector = up,
		LookVector = look,
	}
	return fake :: any
end

local function turnedFrame(position: Vector3, yaw: number, pitch: number): CFrame
	local right = vec(math.cos(yaw), 0, -math.sin(yaw))
	local flatUp = vec(0, 1, 0)
	local flatLook = vec(-math.sin(yaw), 0, -math.cos(yaw))

	local up = flatUp * math.cos(pitch) + flatLook * math.sin(pitch)
	local look = flatLook * math.cos(pitch) - flatUp * math.sin(pitch)

	return frame(position, right, up, look)
end

local function pointIn(box: OrientedBox, across: number, above: number, ahead: number): Vector3
	return box.center + box.right * across + box.up * above + box.look * ahead
end

local ORIGIN = vec(0, 0, 0)

local STRAIGHT = frame(vec(10, 5, -3), vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, -1))

test("FromCFrame keeps the frame and halves the size", function()
	local box = OrientedBox.fromCFrame(STRAIGHT, vec(4, 6, 8))

	expect(box.center == vec(10, 5, -3), "the center should be the frame position")
	expect(box.halfSize == vec(2, 3, 4), "the half size should be half the size")
end)

test("A straight box holds its center and every face, and nothing past them", function()
	local box = OrientedBox.fromCFrame(STRAIGHT, vec(4, 6, 8))

	expect(OrientedBox.contains(box, vec(10, 5, -3)), "the center should be inside")
	expect(OrientedBox.contains(box, vec(12, 8, 1)), "a corner should be inside")
	expect(OrientedBox.contains(box, vec(8, 2, -7)), "the opposite corner should be inside")
	expect(not OrientedBox.contains(box, vec(12.001, 5, -3)), "past the right face should be outside")
	expect(not OrientedBox.contains(box, vec(10, 1.999, -3)), "below the bottom face should be outside")
	expect(not OrientedBox.contains(box, vec(10, 5, 1.001)), "past the back face should be outside")
end)

test("A box turned 45 degrees refuses the corners of the box it was turned from", function()
	local box = OrientedBox.fromCFrame(turnedFrame(ORIGIN, math.pi / 4, 0), vec(10, 10, 10))

	expect(not OrientedBox.contains(box, vec(4.9, 0, 4.9)), "an old corner should now be outside")
	expect(OrientedBox.contains(box, vec(6.9, 0, 0)), "a point the turn swung inside should be inside")
	expect(not OrientedBox.contains(box, vec(7.1, 0, 0)), "just past the turned corner should be outside")
end)

test("Points placed inside a turned box along its own axes are inside", function()
	math.randomseed(7)

	for _ = 1, 500 do
		local turned = turnedFrame(vec(3, -2, 9), math.random() * 2 * math.pi, math.random() * 2 * math.pi)
		local box = OrientedBox.fromCFrame(turned, vec(2, 4, 6))

		local across = (math.random() * 2 - 1) * 0.999
		local above = (math.random() * 2 - 1) * 1.999
		local ahead = (math.random() * 2 - 1) * 2.999

		expect(OrientedBox.contains(box, pointIn(box, across, above, ahead)), "a point inside should be inside")
	end
end)

test("Points just past any one face of a turned box are outside", function()
	math.randomseed(11)

	for _ = 1, 500 do
		local turned = turnedFrame(vec(-4, 1, 0), math.random() * 2 * math.pi, math.random() * 2 * math.pi)
		local box = OrientedBox.fromCFrame(turned, vec(2, 4, 6))

		local side = if math.random() < 0.5 then -1 else 1
		local face = math.random(1, 3)
		local across = if face == 1 then side * 1.001 else 0
		local above = if face == 2 then side * 2.001 else 0
		local ahead = if face == 3 then side * 3.001 else 0

		expect(
			not OrientedBox.contains(box, pointIn(box, across, above, ahead)),
			"a point past a face should be outside"
		)
	end
end)

test("A point with NaN in it is outside", function()
	local box = OrientedBox.fromCFrame(STRAIGHT, vec(4, 6, 8))
	expect(not OrientedBox.contains(box, vec(0 / 0, 5, -3)), "a NaN point should be outside")
end)

print(`{passed} passed, {failed} failed`)

if failed > 0 then
	error(`{failed} OrientedBox tests failed`)
end

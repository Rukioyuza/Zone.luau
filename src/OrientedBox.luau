--!strict

export type OrientedBox = {
	read center: Vector3,
	read right: Vector3,
	read up: Vector3,
	read look: Vector3,
	read halfSize: Vector3,
}

local function dot(first: Vector3, second: Vector3): number
	return first.X * second.X + first.Y * second.Y + first.Z * second.Z
end

local OrientedBox = {}

function OrientedBox.fromCFrame(frame: CFrame, size: Vector3): OrientedBox
	return {
		center = frame.Position,
		right = frame.RightVector,
		up = frame.UpVector,
		look = frame.LookVector,
		halfSize = size / 2,
	}
end

function OrientedBox.contains(box: OrientedBox, point: Vector3): boolean
	local offset = point - box.center
	local halfSize = box.halfSize

	if math.abs(dot(offset, box.right)) > halfSize.X then
		return false
	end

	if math.abs(dot(offset, box.up)) > halfSize.Y then
		return false
	end

	return math.abs(dot(offset, box.look)) <= halfSize.Z
end

return OrientedBox

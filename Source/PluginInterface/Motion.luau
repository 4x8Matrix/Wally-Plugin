local GuiService = game:GetService("GuiService")

local Flipper = require(script.Parent.Parent.Packages.Flipper)

local Motion = {}

Motion.Presets = {
	sheet = { frequency = 4, dampingRatio = 0.9 },
	tab = { frequency = 5, dampingRatio = 1 },
	selection = { frequency = 6, dampingRatio = 1 },
	progress = { frequency = 6, dampingRatio = 1 },
	expand = { frequency = 5, dampingRatio = 1 },
	push = { frequency = 6, dampingRatio = 1 },
	hover = { frequency = 8, dampingRatio = 1 },
	press = { frequency = 7, dampingRatio = 0.55 },
	fade = { frequency = 5, dampingRatio = 1 },
}

--[[
	Whether motion should be skipped, from Roblox's reduced motion setting. Specs and the visual harness replace it.
]]
function Motion.ReadReduced(_: Motion): boolean
	local readable, reduced = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)

	return readable and reduced
end

--[[
	The Flipper goal that moves a motor to `target` on one of the presets, or at once when motion is reduced.
]]
function Motion.Goal(self: Motion, target: number, preset: string)
	if self:ReadReduced() then
		return Flipper.Instant.new(target)
	end

	return Flipper.Spring.new(target, self.Presets[preset])
end

--[[
	Puts a motor at `value` at once, so the next goal animates from there.
]]
function Motion.Snap(_: Motion, motor, value: number)
	motor:setGoal(Flipper.Instant.new(value))
	motor:step(0)
end

export type Motion = typeof(Motion)

return Motion

if not SERVER then
	return
end

local MODEL = "models/gman.mdl"

local function pick_sound()
	local ok, files = pcall(cc.fs.Find, "sound/gman/*.wav", true)
	local found = nil

	if not ok then
		return nil
	end

	table.sort(files)

	for _, file in ipairs(files) do
		local name = file:lower()

		if not found and name:find("choose", 1, true) then
			found = file
		end
	end

	if not found then
		cc.log.Info("nextbot gman: no 'choose' sound found, available: " .. table.concat(files, ", "))
		return nil
	end

	return (found:gsub("^sound/", ""))
end

local def = {
	name = "G-Man",
	description = "Walks up, adjusts his tie and teleports away",
	model = MODEL,
	sprites = { "sprites/lgtning.spr" },
	sounds = {},
	teleport_sound = nil,
}

local voice = pick_sound()

if voice then
	def.sounds[1] = voice
end

function def.Run(bot)
	bot:Appear()
	bot:Wait(0.6)
	bot:Play({ "walk" })
	bot:WalkToPlayer(90, 70)
	bot:FacePlayer()

	local pose = bot:Play({ "tie", "adjust", "straighten", "fix", "idle" })
	bot:Wait(math.max(pose, 1.2))

	local length = bot:Say(voice)
	bot:Wait(length + 0.4)
	bot:Vanish()
end

cc.nextbot.Register("gman", def)

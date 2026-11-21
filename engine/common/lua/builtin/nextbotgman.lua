if not SERVER then
	return
end

local function pick_model()
	local candidates = { "models/gman.mdl", "models/player/gman/gman.mdl" }

	for _, path in ipairs(candidates) do
		local ok, exists = pcall(cc.fs.Exists, path, true)

		if ok and exists then
			return path
		end
	end

	return candidates[1]
end

local MODEL = pick_model()

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
		cc.log.Print("nextbot gman: no 'choose' sound found, available: " .. table.concat(files, ", "))
		return nil
	end

	return (found:gsub("^sound/", ""))
end

local def = {
	name = "G-Man",
	description = "Walks up, adjusts his tie and teleports away",
	model = MODEL,
	image = "models/player/gman/gman.bmp",
	image_w = 164,
	image_h = 200,
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

	local brush = bot:Find({ "idlebrush", "brush", "tie", "adjust", "straighten", "fix" })
	local pose

	if brush then
		pose = bot:Play({ brush.name:lower() })

		if pose == 0 then
			pose = 3.5
		end
	else
		bot:Play({ "idle", "idle1", "stand" })
		pose = 1.5
	end

	bot:Wait(math.min(pose, 4))

	local length = bot:Say(voice)
	bot:Wait(length + 0.4)
	bot:Vanish()
end

cc.nextbot.Register("gman", def)

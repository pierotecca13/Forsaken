-- Cofres.server.luau
-- Genera cofres en el mundo con timers y recompensas de gemas.
-- Tipos: Madera (1-2 gemas, 5 max, cada 6min)
--        Piedra (3-5 gemas, 3 max, cada 8min)
--        Dorado (6-10 gemas, 2 max, cada 10min)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemasManager  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemasManager"))
local CofresConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CofresConfig"))

-- ============================================================
-- Estado de partida
-- ============================================================
local contadores        = { Madera = 0, Piedra = 0, Dorado = 0 }
local posicionesOcupadas = {}   -- { [tostring(Vector3)] = true }

-- ============================================================
-- Helpers
-- ============================================================

-- Devuelve una posición libre aleatoria del pool, o nil si no hay
local function posicionLibre()
	local disponibles = {}
	for _, pos in ipairs(CofresConfig.POSICIONES_SPAWN) do
		if not posicionesOcupadas[tostring(pos)] then
			table.insert(disponibles, pos)
		end
	end
	if #disponibles == 0 then return nil end
	return disponibles[math.random(#disponibles)]
end

-- ============================================================
-- Crear cofre en el mundo
-- ============================================================
local function crearCofre(tipo, pos)
	local cfg = CofresConfig.TIPOS[tipo]

	-- Modelo raíz
	local cofreModel = Instance.new("Model")
	cofreModel.Name   = "Cofre_" .. tipo
	cofreModel.Parent = workspace

	-- Cuerpo principal del cofre
	local cuerpo = Instance.new("Part")
	cuerpo.Name      = "Cuerpo"
	cuerpo.Size      = Vector3.new(2, 1.2, 1.2)
	cuerpo.CFrame    = CFrame.new(pos)
	cuerpo.Anchored  = true
	cuerpo.CanCollide = true
	cuerpo.Color     = cfg.color
	cuerpo.Material  = cfg.material
	cuerpo.Parent    = cofreModel
	cofreModel.PrimaryPart = cuerpo

	-- Tapa del cofre (ligeramente más clara)
	local tapa = Instance.new("Part")
	tapa.Name      = "Tapa"
	tapa.Size      = Vector3.new(2.05, 0.35, 1.25)
	tapa.Anchored  = true
	tapa.CanCollide = false
	tapa.Color     = Color3.new(
		math.min(cfg.color.R + 0.06, 1),
		math.min(cfg.color.G + 0.06, 1),
		math.min(cfg.color.B + 0.06, 1)
	)
	tapa.Material  = cfg.material
	tapa.CFrame    = CFrame.new(pos + Vector3.new(0, 0.775, 0))
	tapa.Parent    = cofreModel

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cuerpo
	soldadura.Part1 = tapa
	soldadura.Parent = cuerpo

	-- Destello dorado para el cofre dorado
	if tipo == "Dorado" then
		local brillo = Instance.new("SelectionBox")
		brillo.Adornee      = cofreModel
		brillo.Color3       = Color3.fromRGB(255, 220, 0)
		brillo.LineThickness = 0.04
		brillo.Parent       = cofreModel
	end

	-- Billboard con nombre del cofre
	local billboard = Instance.new("BillboardGui")
	billboard.Size        = UDim2.new(0, 160, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 1.8, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent      = cuerpo

	local lblNombre = Instance.new("TextLabel")
	lblNombre.Size                  = UDim2.new(1, 0, 1, 0)
	lblNombre.BackgroundColor3      = Color3.fromRGB(10, 10, 10)
	lblNombre.BackgroundTransparency = 0.4
	lblNombre.BorderSizePixel       = 0
	lblNombre.Text                  = cfg.nombre
	lblNombre.Font                  = Enum.Font.GothamBold
	lblNombre.TextScaled            = true
	lblNombre.TextColor3            = Color3.fromRGB(255, 230, 100)
	lblNombre.Parent                = billboard

	local cornerBb = Instance.new("UICorner")
	cornerBb.CornerRadius = UDim.new(0, 6)
	cornerBb.Parent       = lblNombre

	-- ProximityPrompt para recoger
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText           = "Recoger"
	prompt.ObjectText           = cfg.nombre
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration         = 0
	prompt.KeyboardKeyCode      = Enum.KeyCode.E
	prompt.Parent               = cuerpo

	-- Al recoger: dar gemas y destruir cofre
	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled then return end
		prompt.Enabled = false

		local gemas = math.random(cfg.gemasMin, cfg.gemasMax)
		GemasManager.agregar(player, gemas)

		-- Liberar la posición para futuros spawns
		posicionesOcupadas[tostring(pos)] = nil

		print(string.format("[Cofres] %s recogió %s: +%d gemas.", player.Name, cfg.nombre, gemas))

		task.delay(0.4, function()
			if cofreModel and cofreModel.Parent then
				cofreModel:Destroy()
			end
		end)
	end)
end

-- ============================================================
-- Loops de spawn (uno por tipo, arrancan al iniciar el servidor)
-- ============================================================
for tipo, cfg in pairs(CofresConfig.TIPOS) do
	task.spawn(function()
		while true do
			task.wait(cfg.intervalo)
			if contadores[tipo] < cfg.maxPartida then
				local pos = posicionLibre()
				if pos then
					posicionesOcupadas[tostring(pos)] = true
					contadores[tipo] += 1
					crearCofre(tipo, pos)
					print(string.format("[Cofres] Cofre %s spawneado en %s (total: %d/%d).",
						tipo, tostring(pos), contadores[tipo], cfg.maxPartida))
				end
			end
		end
	end)
end

print("[Cofres] Sistema de cofres iniciado.")

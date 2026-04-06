-- Inventario.server.luau
-- Maneja el RemoteEvent de descarte de inventario iniciado por el cliente.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InventarioManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("InventarioManager"))

local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(className)
		obj.Name   = nombre
		obj.Parent = parent
	end
	return obj
end

local carpetaEventos = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evDescartar    = obtenerOCrear(carpetaEventos, "RemoteEvent", "InventarioDescartar")
local evColocar      = obtenerOCrear(carpetaEventos, "RemoteEvent", "ColocarHerramienta")

local HERRAMIENTAS_VALIDAS = { Antorcha = true, Hoguera = true }

-- Config de cada herramienta: radio de luz, tamaño visual, color, duración en segundos
local HERRAMIENTA_CFG = {
	Antorcha = { radio = 10, tamano = Vector3.new(0.25, 1.4, 0.25), color = Color3.fromRGB(255, 200, 60),  duracion = 300 },
	Hoguera  = { radio = 20, tamano = Vector3.new(1.2,  1.2, 1.2),  color = Color3.fromRGB(255, 110, 25), duracion = 480 },
}

evDescartar.OnServerEvent:Connect(function(player, recurso, cantidad)
	if type(recurso)   ~= "string" then return end
	if type(cantidad)  ~= "number" then return end
	cantidad = math.max(1, math.floor(cantidad))
	InventarioManager.descartar(player, recurso, cantidad)
end)

evColocar.OnServerEvent:Connect(function(player, herramienta)
	if type(herramienta) ~= "string" then return end
	if not HERRAMIENTAS_VALIDAS[herramienta] then return end

	-- Descontar 1 unidad del inventario
	local ok = InventarioManager.descontar(player, { [herramienta] = 1 })
	if not ok then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local cfg = HERRAMIENTA_CFG[herramienta]
	local posXZ = hrp.CFrame * CFrame.new(0, 0, -3)   -- 3 studs delante del jugador

	-- Parte visual (llama neon)
	local parte = Instance.new("Part")
	parte.Name        = herramienta
	parte.Size        = cfg.tamano
	parte.Position    = Vector3.new(posXZ.X, 0.4 + cfg.tamano.Y / 2, posXZ.Z)
	parte.Anchored    = true
	parte.CanCollide  = false
	parte.CastShadow  = false
	parte.Color       = cfg.color
	parte.Material    = Enum.Material.Neon
	parte.Parent      = workspace

	local luz = Instance.new("PointLight")
	luz.Range      = cfg.radio * 1.5
	luz.Brightness = 3
	luz.Color      = cfg.color
	luz.Parent     = parte

	-- Registrar en HoguerasActivas para repeler corrompidos
	local carpetaHogueras = workspace:FindFirstChild("HoguerasActivas")
		or Instance.new("Folder")
	if not workspace:FindFirstChild("HoguerasActivas") then
		carpetaHogueras.Name   = "HoguerasActivas"
		carpetaHogueras.Parent = workspace
	end

	local marcador = Instance.new("Part")
	marcador.Name        = herramienta .. "_" .. player.Name
	marcador.Size        = Vector3.new(1, 1, 1)
	marcador.Position    = parte.Position
	marcador.Anchored    = true
	marcador.CanCollide  = false
	marcador.Transparency = 1
	marcador:SetAttribute("Radio", cfg.radio)
	marcador.Parent      = carpetaHogueras

	-- Auto-destruir tras la duración
	game:GetService("Debris"):AddItem(parte,    cfg.duracion)
	game:GetService("Debris"):AddItem(marcador, cfg.duracion)

	print(string.format("[Inventario] %s colocó %s en %s.", player.Name, herramienta, tostring(parte.Position)))
end)

print("[Inventario] Sistema de descarte y colocación activo.")

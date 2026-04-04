-- Comida.server.luau
-- Maneja la petición ComerAlimento del cliente.
-- Valida inventario, aplica penalización nocturna y cura al jugador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local ComidaConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ComidaConfig"))
local InventarioMgr = require(script.Parent:FindFirstChild("InventarioManager"))

-- ============================================================
-- Eventos
-- ============================================================
local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj        = Instance.new(className)
		obj.Name   = nombre
		obj.Parent = parent
	end
	return obj
end

local carpetaEventos   = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evComerAlimento  = obtenerOCrear(carpetaEventos, "RemoteEvent", "ComerAlimento")
local evResultadoComer = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoComer")

-- ============================================================
-- Helper: ¿es de noche según el reloj del mapa?
-- ============================================================
local function esDeNoche()
	local h = Lighting.ClockTime
	return h >= 19 or h < 7
end

-- ============================================================
-- Escuchar petición de comer
-- ============================================================
evComerAlimento.OnServerEvent:Connect(function(player, tipoComida)
	-- Validar que el tipo de comida esté en la config
	local infoComida = ComidaConfig.ALIMENTOS[tipoComida]
	if not infoComida then return end

	-- Validar que el jugador tenga al menos 1 unidad en inventario
	local inv = InventarioMgr.obtener(player)
	if (inv[tipoComida] or 0) <= 0 then return end

	-- Validar personaje y humanoid
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Rechazar si la vida ya está completa
	if humanoid.Health >= humanoid.MaxHealth then
		evResultadoComer:FireClient(player, { vidaLlena = true })
		return
	end

	-- Calcular curación con posible penalización nocturna
	local noche     = esDeNoche()
	local vidaBase  = infoComida.vidaBase
	local vidaFinal = noche
		and math.floor(vidaBase * (1 - ComidaConfig.PENALIZACION_NOCHE))
		or  vidaBase

	-- Aplicar curación (sin superar el máximo)
	local vidaAntes  = humanoid.Health
	humanoid.Health  = math.min(humanoid.MaxHealth, humanoid.Health + vidaFinal)
	local vidaCurada = humanoid.Health - vidaAntes

	-- Consumir 1 unidad del alimento
	InventarioMgr.descontar(player, { [tipoComida] = 1 })

	-- Enviar resultado al cliente para feedback visual
	evResultadoComer:FireClient(player, {
		nombre     = infoComida.nombre,
		vidaCurada = math.ceil(vidaCurada),
		noche      = noche,
	})

	print(string.format("[Comida] %s comió %s → +%.0f HP%s",
		player.Name, tipoComida, vidaCurada,
		noche and "  (noche -30%)" or ""))
end)

print("[Comida] Sistema de alimentación iniciado.")

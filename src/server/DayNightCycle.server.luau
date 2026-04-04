-- DayNightCycle.server.luau
-- Controla el ciclo día/noche de forma autoritativa en el servidor.
-- Mueve Lighting.ClockTime, interpola la atmósfera y emite RemoteEvents
-- cuando cambia la fase para que otros sistemas reaccionen.

local Lighting        = game:GetService("Lighting")
local RunService      = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DayNightConfig"))

-- ============================================================
-- Crear carpeta de eventos compartidos (si no existe)
-- ============================================================
local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(className)
		obj.Name = nombre
		obj.Parent = parent
	end
	return obj
end

local carpetaEventos = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")

-- Eventos disponibles para otros scripts:
--   NocheComenzo  → sin parámetros, se dispara al iniciar la noche
--   DiaComenzo    → sin parámetros, se dispara al iniciar el día
--   TiempoSync    → (esNoche: bool, segundosRestantes: number) cada ~1 segundo
local evNocheComenzo = obtenerOCrear(carpetaEventos, "RemoteEvent", "NocheComenzo")
local evDiaComenzo   = obtenerOCrear(carpetaEventos, "RemoteEvent", "DiaComenzo")
local evTiempoSync   = obtenerOCrear(carpetaEventos, "RemoteEvent", "TiempoSync")

-- ============================================================
-- Helpers de interpolación
-- ============================================================
local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return Color3.new(
		lerp(c1.R, c2.R, t),
		lerp(c1.G, c2.G, t),
		lerp(c1.B, c2.B, t)
	)
end

-- Curva suave (ease in-out) para transiciones menos abruptas
local function smoothstep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Aplica la iluminación interpolada entre día (factor=0) y noche (factor=1)
local function aplicarIluminacion(factor)
	local t  = smoothstep(factor)
	local d  = Config.LUZ_DIA
	local n  = Config.LUZ_NOCHE

	Lighting.Brightness     = lerp(d.Brightness, n.Brightness, t)
	Lighting.Ambient        = lerpColor(d.Ambient, n.Ambient, t)
	Lighting.OutdoorAmbient = lerpColor(d.OutdoorAmbient, n.OutdoorAmbient, t)
	Lighting.FogEnd         = lerp(d.FogEnd, n.FogEnd, t)
	Lighting.FogColor       = lerpColor(d.FogColor, n.FogColor, t)
end

-- Calcula el factor de oscuridad (0=día pleno, 1=noche plena)
-- basado en qué tan avanzada está la fase actual.
local function calcularFactor(progreso, esNoche)
	local m = Config.MARGEN_TRANSICION  -- porcentaje de transición

	if not esNoche then
		-- Día: claro la mayor parte, se oscurece en el último MARGEN
		if progreso < (1 - m) then
			return 0
		else
			return (progreso - (1 - m)) / m
		end
	else
		-- Noche: oscuro la mayor parte, aclara en el último MARGEN
		if progreso < (1 - m) then
			return 1
		else
			return 1 - ((progreso - (1 - m)) / m)
		end
	end
end

-- ============================================================
-- Estado del ciclo
-- ============================================================
local esNoche        = false
local tiempoFase     = 0   -- segundos en la fase actual
local tiempoUltimoSync = 0 -- acumulador para enviar sync cada ~1s

-- Configuración inicial: arrancar en día
Lighting.ClockTime = Config.HORA_INICIO_DIA
aplicarIluminacion(0)

-- ============================================================
-- Loop principal (Heartbeat = cada frame, igual que FixedUpdate)
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	tiempoFase        = tiempoFase + dt
	tiempoUltimoSync  = tiempoUltimoSync + dt

	local duracion = esNoche and Config.DURACION_NOCHE or Config.DURACION_DIA
	local progreso = math.clamp(tiempoFase / duracion, 0, 1)

	-- Mover el sol/luna (ClockTime)
	if not esNoche then
		-- Día: ClockTime de HORA_INICIO_DIA → HORA_INICIO_NOCHE
		local rango = Config.HORA_INICIO_NOCHE - Config.HORA_INICIO_DIA
		Lighting.ClockTime = Config.HORA_INICIO_DIA + rango * progreso
	else
		-- Noche: ClockTime de HORA_INICIO_NOCHE → HORA_INICIO_DIA + 24 (cruza medianoche)
		local horaFin = Config.HORA_INICIO_DIA + 24
		local rango   = horaFin - Config.HORA_INICIO_NOCHE
		Lighting.ClockTime = (Config.HORA_INICIO_NOCHE + rango * progreso) % 24
	end

	-- Actualizar iluminación atmosférica gradualmente
	local factor = calcularFactor(progreso, esNoche)
	aplicarIluminacion(factor)

	-- ¿Se acabó la fase?
	if tiempoFase >= duracion then
		tiempoFase = 0
		esNoche = not esNoche

		if esNoche then
			-- Forzar iluminación nocturna completa al iniciar
			Lighting.ClockTime = Config.HORA_INICIO_NOCHE
			aplicarIluminacion(1)
			evNocheComenzo:FireAllClients()
			print("[DayNight] === NOCHE COMIENZA ===")
		else
			-- Forzar iluminación diurna completa al iniciar
			Lighting.ClockTime = Config.HORA_INICIO_DIA
			aplicarIluminacion(0)
			evDiaComenzo:FireAllClients()
			print("[DayNight] === DIA COMIENZA ===")
		end
	end

	-- Enviar sync al cliente cada ~1 segundo (para el timer de UI)
	if tiempoUltimoSync >= 1 then
		tiempoUltimoSync = 0
		local restante = math.ceil(duracion - tiempoFase)
		evTiempoSync:FireAllClients(esNoche, restante)
	end
end)

print("[DayNight] Sistema de ciclo dia/noche iniciado.")

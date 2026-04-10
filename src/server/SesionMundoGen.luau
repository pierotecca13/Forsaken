-- SesionMundoGen.luau  (ModuleScript en ServerScriptService/Server/)
-- Genera el mundo procedural para una sesión, desplazado en X.
-- Función pública: M.generar(sesionId, offsetX, carpetaSesion)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))

local M = {}

-- ============================================================
-- Utilidades (misma lógica que WorldGen.server.luau)
-- ============================================================
local function distanciaXZ(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function enExclusion(pos, exclusiones)
	for _, excl in ipairs(exclusiones) do
		if distanciaXZ(pos, excl.centro) < excl.radio then
			return true
		end
	end
	return false
end

local function generarPosiciones(zona, cantidad, espaciado, exclusiones, margen)
	margen = margen or 15
	local posiciones  = {}
	local intentosMax = cantidad * 40
	for _ = 1, intentosMax do
		if #posiciones >= cantidad then break end
		local x = zona.minX + margen + math.random() * ((zona.maxX - margen) - (zona.minX + margen))
		local z = zona.minZ + margen + math.random() * ((zona.maxZ - margen) - (zona.minZ + margen))
		local candidato = Vector3.new(x, 0, z)
		if enExclusion(candidato, exclusiones or {}) then continue end
		local cerca = false
		for _, pos in ipairs(posiciones) do
			if distanciaXZ(candidato, pos) < espaciado then
				cerca = true
				break
			end
		end
		if not cerca then
			table.insert(posiciones, candidato)
		end
	end
	return posiciones
end

-- ============================================================
-- Publicar posiciones en subcarpetas dentro de la sesión
-- ============================================================
local function publicarPosicionesRecursos(carpetaSesion, posicionesPorTipo)
	local carpeta = Instance.new("Folder")
	carpeta.Name   = "PosicionesRecursos"
	carpeta.Parent = carpetaSesion
	for tipo, lista in pairs(posicionesPorTipo) do
		local sub = Instance.new("Folder")
		sub.Name   = tipo
		sub.Parent = carpeta
		for i, pos in ipairs(lista) do
			local v = Instance.new("Vector3Value")
			v.Name   = tostring(i)
			v.Value  = pos
			v.Parent = sub
		end
	end
end

local function publicarPosicionesEnemigos(carpetaSesion, posicionesPorTipo, nombreCarpeta)
	local carpeta = Instance.new("Folder")
	carpeta.Name   = nombreCarpeta
	carpeta.Parent = carpetaSesion
	for tipo, lista in pairs(posicionesPorTipo) do
		local sub = Instance.new("Folder")
		sub.Name   = tipo
		sub.Parent = carpeta
		for i, pos in ipairs(lista) do
			local v = Instance.new("Vector3Value")
			v.Name   = tostring(i)
			v.Value  = Vector3.new(pos.X, 3, pos.Z)
			v.Parent = sub
		end
	end
end

local function publicarPosicionesCofres(carpetaSesion, lista)
	local carpeta = Instance.new("Folder")
	carpeta.Name   = "PosicionesCofres"
	carpeta.Parent = carpetaSesion
	for i, pos in ipairs(lista) do
		local v = Instance.new("Vector3Value")
		v.Name   = tostring(i)
		v.Value  = Vector3.new(pos.X, 1, pos.Z)
		v.Parent = carpeta
	end
end

-- ============================================================
-- Suelo del bioma
-- ============================================================
local function crearSuelo(cfg, carpetaPadre)
	local anchoX  = cfg.maxX - cfg.minX
	local anchoZ  = cfg.maxZ - cfg.minZ
	local centroX = (cfg.minX + cfg.maxX) / 2
	local centroZ = (cfg.minZ + cfg.maxZ) / 2
	local suelo = Instance.new("Part")
	suelo.Name       = "Suelo_Bosque"
	suelo.Size       = Vector3.new(anchoX, 0.4, anchoZ)
	suelo.CFrame     = CFrame.new(centroX, 0.2, centroZ)
	suelo.Anchored   = true
	suelo.CanCollide = true
	suelo.Color      = cfg.sueloColor
	suelo.Material   = cfg.sueloMaterial
	suelo.CastShadow = false
	suelo.Parent     = carpetaPadre
end

-- ============================================================
-- Barreras invisibles
-- ============================================================
local function crearBarreras(cfg, carpetaPadre)
	local grosor  = 4
	local altura  = 30
	local minX, maxX, minZ, maxZ = cfg.minX, cfg.maxX, cfg.minZ, cfg.maxZ
	local centroX = (minX + maxX) / 2
	local centroZ = (minZ + maxZ) / 2
	local anchoX  = maxX - minX
	local anchoZ  = maxZ - minZ
	local bordes = {
		{ pos = Vector3.new(centroX,         altura/2, minZ - grosor/2), size = Vector3.new(anchoX + grosor*2, altura, grosor) },
		{ pos = Vector3.new(centroX,         altura/2, maxZ + grosor/2), size = Vector3.new(anchoX + grosor*2, altura, grosor) },
		{ pos = Vector3.new(minX - grosor/2, altura/2, centroZ),         size = Vector3.new(grosor, altura, anchoZ) },
		{ pos = Vector3.new(maxX + grosor/2, altura/2, centroZ),         size = Vector3.new(grosor, altura, anchoZ) },
	}
	for _, b in ipairs(bordes) do
		local muro = Instance.new("Part")
		muro.Name         = "Barrera_Bosque"
		muro.Size         = b.size
		muro.Position     = b.pos
		muro.Anchored     = true
		muro.CanCollide   = true
		muro.Transparency = 1
		muro.CastShadow   = false
		muro.Parent       = carpetaPadre
	end
end

-- ============================================================
-- Función principal
-- ============================================================
function M.generar(sesionId, offsetX, carpetaSesion)
	-- Semilla única por sesión para reproducibilidad
	math.randomseed(math.floor(tick() * 1000 + sesionId * 137) % 2147483647)

	local cfgOrig = WorldConfig.ZONAS.Bosque

	-- Zona con offset X aplicado (copia superficial + campos modificados)
	local cfg = {}
	for k, v in pairs(cfgOrig) do cfg[k] = v end
	cfg.minX = cfgOrig.minX + offsetX
	cfg.maxX = cfgOrig.maxX + offsetX

	-- Exclusiones con offset X
	local exclOffset = {}
	for _, e in ipairs(cfgOrig.exclusiones) do
		table.insert(exclOffset, {
			centro = Vector3.new(e.centro.X + offsetX, e.centro.Y, e.centro.Z),
			radio  = e.radio,
		})
	end
	cfg.exclusiones = exclOffset

	local camp = Vector3.new(offsetX + 0, 0, -20)

	-- Subcarpeta del bioma
	local carpetaBosque = Instance.new("Folder")
	carpetaBosque.Name   = "Bosque"
	carpetaBosque.Parent = carpetaSesion

	crearSuelo(cfg, carpetaBosque)
	crearBarreras(cfg, carpetaBosque)

	-- ── Recursos ────────────────────────────────────────────
	local todasPosiciones   = {}
	local posicionesPorTipo = {}
	for _, recCfg in ipairs(cfgOrig.recursos) do
		local exclCombinadas = {}
		for _, e in ipairs(exclOffset) do table.insert(exclCombinadas, e) end
		for _, p in ipairs(todasPosiciones) do
			table.insert(exclCombinadas, { centro = p, radio = recCfg.espaciado })
		end
		local posiciones = generarPosiciones(cfg, recCfg.cantidad, recCfg.espaciado, exclCombinadas, 20)
		posicionesPorTipo[recCfg.tipo] = posiciones
		for _, p in ipairs(posiciones) do table.insert(todasPosiciones, p) end
	end
	publicarPosicionesRecursos(carpetaSesion, posicionesPorTipo)

	-- ── Enemigos día ─────────────────────────────────────────
	local exclCamp = {}
	for _, e in ipairs(exclOffset) do table.insert(exclCamp, e) end
	table.insert(exclCamp, { centro = camp, radio = 20 })

	local configDia = {
		{ tipo = "Conejo", cantidad = 12, espaciado = 25 },
		{ tipo = "Zorro",  cantidad = 8,  espaciado = 30 },
		{ tipo = "Lobo",   cantidad = 8,  espaciado = 35 },
		{ tipo = "Oso",    cantidad = 4,  espaciado = 45 },
	}
	local posicionesEnemigos = {}
	local todasEnemigos = {}
	for _, eCfg in ipairs(configDia) do
		local exclEnem = {}
		for _, e in ipairs(exclCamp) do table.insert(exclEnem, e) end
		for _, p in ipairs(todasEnemigos) do
			table.insert(exclEnem, { centro = p, radio = eCfg.espaciado })
		end
		local posiciones = generarPosiciones(cfg, eCfg.cantidad, eCfg.espaciado, exclEnem, 20)
		posicionesEnemigos[eCfg.tipo] = posiciones
		for _, p in ipairs(posiciones) do table.insert(todasEnemigos, p) end
	end
	publicarPosicionesEnemigos(carpetaSesion, posicionesEnemigos, "PosicionesEnemigos")

	-- ── Enemigos noche ───────────────────────────────────────
	local configNoche = {
		{ tipo = "Conejo", cantidad = 36, espaciado = 18 },
		{ tipo = "Zorro",  cantidad = 24, espaciado = 22 },
		{ tipo = "Lobo",   cantidad = 24, espaciado = 25 },
		{ tipo = "Oso",    cantidad = 12, espaciado = 35 },
	}
	local posicionesNoche = {}
	local todasNoche = {}
	for _, eCfg in ipairs(configNoche) do
		local exclEnem = {}
		for _, e in ipairs(exclCamp) do table.insert(exclEnem, e) end
		for _, p in ipairs(todasNoche) do
			table.insert(exclEnem, { centro = p, radio = eCfg.espaciado })
		end
		local posiciones = generarPosiciones(cfg, eCfg.cantidad, eCfg.espaciado, exclEnem, 20)
		posicionesNoche[eCfg.tipo] = posiciones
		for _, p in ipairs(posiciones) do table.insert(todasNoche, p) end
	end
	publicarPosicionesEnemigos(carpetaSesion, posicionesNoche, "PosicionesEnemigosCorrompidos")

	-- ── Cofres ──────────────────────────────────────────────
	local exclCofres = {}
	for _, e in ipairs(exclOffset) do table.insert(exclCofres, e) end
	table.insert(exclCofres, { centro = camp, radio = 40 })
	local posicionesCofres = generarPosiciones(cfg, 25, 35, exclCofres, 20)
	publicarPosicionesCofres(carpetaSesion, posicionesCofres)

	print(string.format(
		"[SesionMundoGen] Sesion %d (offsetX=%d): %d recursos, %d posDia, %d posNoche, %d posCofres.",
		sesionId, offsetX, #todasPosiciones, #todasEnemigos, #todasNoche, #posicionesCofres
	))
end

return M

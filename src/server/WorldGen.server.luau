-- WorldGen.server.luau
-- Motor de generación procedural del mundo.
-- Corre una vez al inicio del servidor y construye el Bosque (fase 1).
-- Los demás biomas se activarán en fases posteriores.
-- Comentado en español; no toca sistemas existentes de combate ni inventario.

local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))

-- ============================================================
-- Semilla aleatoria única por sesión
-- ============================================================
math.randomseed(math.floor(tick() * 1000) % 2147483647)

-- ============================================================
-- Carpeta raíz del mundo generado
-- ============================================================
local mundoFolder = Instance.new("Folder")
mundoFolder.Name   = "MundoGenerado"
mundoFolder.Parent = Workspace

-- ============================================================
-- Utilidades
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

-- Genera N posiciones aleatorias dentro de la zona respetando espaciado y exclusiones.
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

-- Genera posiciones dentro de un anillo de distancia desde un centro.
local function generarPosicionesAnillo(zona, cantidad, centro, distMin, distMax, espaciado)
	local posiciones  = {}
	local intentosMax = cantidad * 50

	for _ = 1, intentosMax do
		if #posiciones >= cantidad then break end

		local angulo = math.random() * math.pi * 2
		local dist   = distMin + math.random() * (distMax - distMin)
		local x      = centro.X + math.cos(angulo) * dist
		local z      = centro.Z + math.sin(angulo) * dist

		-- Verificar límites de la zona
		if x < zona.minX + 15 or x > zona.maxX - 15 then continue end
		if z < zona.minZ + 15 or z > zona.maxZ - 15 then continue end

		local candidato = Vector3.new(x, 0, z)

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
-- Suelo del bioma
-- ============================================================
local function crearSuelo(nombreZona, cfg)
	local anchoX  = cfg.maxX - cfg.minX
	local anchoZ  = cfg.maxZ - cfg.minZ
	local centroX = (cfg.minX + cfg.maxX) / 2
	local centroZ = (cfg.minZ + cfg.maxZ) / 2

	local suelo = Instance.new("Part")
	suelo.Name       = "Suelo_" .. nombreZona
	suelo.Size       = Vector3.new(anchoX, 0.4, anchoZ)
	-- Y=0.2 → superficie superior en Y=0.4, por encima del baseplate (Y=0)
	-- evita el Z-fighting que causaba el flickering gris/verde
	suelo.CFrame     = CFrame.new(centroX, 0.2, centroZ)
	suelo.Anchored   = true
	suelo.CanCollide = true    -- jugadores caminan sobre el pasto
	suelo.Color      = cfg.sueloColor
	suelo.Material   = cfg.sueloMaterial
	suelo.CastShadow = false
	suelo.Parent     = mundoFolder
end

-- ============================================================
-- Barreras invisibles del bioma
-- ============================================================
local function crearBarreras(nombreZona, cfg, carpeta)
	local grosor  = 4
	local altura  = 30
	local minX, maxX, minZ, maxZ = cfg.minX, cfg.maxX, cfg.minZ, cfg.maxZ
	local centroX = (minX + maxX) / 2
	local centroZ = (minZ + maxZ) / 2
	local anchoX  = maxX - minX
	local anchoZ  = maxZ - minZ

	local bordes = {
		{ pos = Vector3.new(centroX,       altura/2, minZ - grosor/2), size = Vector3.new(anchoX + grosor*2, altura, grosor) },
		{ pos = Vector3.new(centroX,       altura/2, maxZ + grosor/2), size = Vector3.new(anchoX + grosor*2, altura, grosor) },
		{ pos = Vector3.new(minX - grosor/2, altura/2, centroZ),       size = Vector3.new(grosor, altura, anchoZ) },
		{ pos = Vector3.new(maxX + grosor/2, altura/2, centroZ),       size = Vector3.new(grosor, altura, anchoZ) },
	}

	for _, b in ipairs(bordes) do
		local muro = Instance.new("Part")
		muro.Name         = "Barrera_" .. nombreZona
		muro.Size         = b.size
		muro.Position     = b.pos
		muro.Anchored     = true
		muro.CanCollide   = true
		muro.Transparency = 1
		muro.CastShadow   = false
		muro.Parent       = carpeta
	end
end

-- ============================================================
-- Publicar posiciones de recursos para Recoleccion.server
-- ============================================================
local function publicarPosicionesRecursos(posicionesPorTipo)
	local carpeta = Instance.new("Folder")
	carpeta.Name   = "PosicionesRecursos"
	carpeta.Parent = Workspace

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

-- ============================================================
-- Publicar posiciones de enemigos para Enemigos.server
-- ============================================================
local function publicarPosicionesEnemigos(posicionesPorTipo, nombreCarpeta)
	local carpeta = Instance.new("Folder")
	carpeta.Name   = nombreCarpeta or "PosicionesEnemigos"
	carpeta.Parent = Workspace

	for tipo, lista in pairs(posicionesPorTipo) do
		local sub = Instance.new("Folder")
		sub.Name   = tipo
		sub.Parent = carpeta
		for i, pos in ipairs(lista) do
			local v = Instance.new("Vector3Value")
			v.Name   = tostring(i)
			v.Value  = Vector3.new(pos.X, 3, pos.Z)  -- Y=3 para que spawnen sobre el suelo
			v.Parent = sub
		end
	end
end

-- ============================================================
-- Publicar posiciones de cofres para Cofres.server
-- ============================================================
local function publicarPosicionesCofres(lista)
	local carpeta = Instance.new("Folder")
	carpeta.Name   = "PosicionesCofres"
	carpeta.Parent = Workspace

	for i, pos in ipairs(lista) do
		local v = Instance.new("Vector3Value")
		v.Name   = tostring(i)
		v.Value  = Vector3.new(pos.X, 1, pos.Z)  -- Y=1 sobre el suelo
		v.Parent = carpeta
	end
end

-- ============================================================
-- GENERACIÓN DEL BOSQUE
-- ============================================================
local function generarBosque()
	local cfg  = WorldConfig.ZONAS.Bosque
	local excl = cfg.exclusiones
	local camp = Vector3.new(0, 0, -20)  -- posición del campamento

	local carpeta = Instance.new("Folder")
	carpeta.Name   = "Bosque"
	carpeta.Parent = mundoFolder

	-- 1. Suelo (fix Z-fighting)
	crearSuelo("Bosque", cfg)

	-- 2. Recursos interactivos (todos, sin separación decorativo/interactivo)
	local todasPosiciones = {}
	local posicionesPorTipo = {}

	for _, recCfg in ipairs(cfg.recursos) do
		local exclCombinadas = {}
		for _, e in ipairs(excl) do table.insert(exclCombinadas, e) end
		for _, p in ipairs(todasPosiciones) do
			table.insert(exclCombinadas, { centro = p, radio = recCfg.espaciado })
		end

		local posiciones = generarPosiciones(cfg, recCfg.cantidad, recCfg.espaciado, exclCombinadas, 20)
		posicionesPorTipo[recCfg.tipo] = posiciones

		for _, p in ipairs(posiciones) do
			table.insert(todasPosiciones, p)
		end
	end

	publicarPosicionesRecursos(posicionesPorTipo)

	-- 3. Enemigos distribuidos por todo el mapa
	--    Día:   Conejo 12, Zorro 8, Lobo 8, Oso 4   (total 32)
	--    Noche: x3 de cada tipo, posiciones distintas (total 96)
	--    Exclusión: zona del campamento (radio 20)
	local exclCamp = {}
	for _, e in ipairs(excl) do table.insert(exclCamp, e) end
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
	publicarPosicionesEnemigos(posicionesEnemigos, "PosicionesEnemigos")

	-- Noche: x3 de cada tipo, posiciones independientes
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
	publicarPosicionesEnemigos(posicionesNoche, "PosicionesEnemigosCorrompidos")

	-- 4. Cofres: 25 posiciones distribuidas por todo el Bosque
	--    alejadas del campamento (radio 40) y entre sí (espaciado 35)
	local exclCofres = {}
	for _, e in ipairs(excl) do table.insert(exclCofres, e) end
	table.insert(exclCofres, { centro = camp, radio = 40 })

	local posicionesCofres = generarPosiciones(cfg, 25, 35, exclCofres, 20)
	publicarPosicionesCofres(posicionesCofres)

	-- 5. Barreras invisibles
	crearBarreras("Bosque", cfg, carpeta)

	-- 6. Iluminación base
	Lighting.FogColor = cfg.nieblaDia.color
	Lighting.FogEnd   = cfg.nieblaDia.distancia

	print(string.format(
		"[WorldGen] Bosque: %d recursos, %d posDia, %d posNoche, %d posCofres.",
		#todasPosiciones, #todasEnemigos, #todasNoche, #posicionesCofres
	))
end

-- ============================================================
-- Ejecutar
-- ============================================================
generarBosque()
print("[WorldGen] Generación del mundo completada.")

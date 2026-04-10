-- SesionManager.luau  (ModuleScript en ServerScriptService/Server/)
-- Orquesta la creación y limpieza de sesiones por grupo.
-- API pública:
--   M.nuevaSesion(grupo)   → crea una sesión para una tabla de Players
--   M.playerSale(player)   → notifica que un jugador salió del juego

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SesionMundoGen   = require(script.Parent:WaitForChild("SesionMundoGen"))
local SesionRecursos   = require(script.Parent:WaitForChild("SesionRecursos"))
local SesionCofres     = require(script.Parent:WaitForChild("SesionCofres"))
local SesionEnemigos   = require(script.Parent:WaitForChild("SesionEnemigos"))
local SesionCampamento = require(script.Parent:WaitForChild("SesionCampamento"))
local SesionCofreAlm   = require(script.Parent:WaitForChild("SesionCofreAlm"))

local M = {}

-- ============================================================
-- Helpers
-- ============================================================
local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(className)
		obj.Name   = nombre
		obj.Parent = parent
	end
	return obj
end

-- ============================================================
-- Eventos (crear todos en startup para que los clientes puedan WaitForChild)
-- ============================================================
local carpetaEventos    = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evSesionPreparando = obtenerOCrear(carpetaEventos, "RemoteEvent", "SesionPreparando")
local evSesionLista      = obtenerOCrear(carpetaEventos, "RemoteEvent", "SesionLista")

-- BindableEvent para reiniciar el ciclo día/noche cuando arranque la primera sesión
local bePrimeraSesion  = obtenerOCrear(carpetaEventos, "BindableEvent", "PrimeraSesionIniciada")
local primeraSesionFired = false

-- Eventos de campamento (antes los creaba Campamento.server.luau, ahora desactivado)
obtenerOCrear(carpetaEventos, "RemoteEvent", "AbrirMenuCampamento")
obtenerOCrear(carpetaEventos, "RemoteEvent", "SolicitarMejora")
obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoMejora")
obtenerOCrear(carpetaEventos, "RemoteEvent", "CampamentoActualizado")
-- Eventos de vendaje (antes los creaba Combate.server.luau, orden de carga no garantizado)
obtenerOCrear(carpetaEventos, "RemoteEvent", "VendajeActualizado")
obtenerOCrear(carpetaEventos, "RemoteEvent", "UsarVendaje")
-- Eventos del cofre de almacenamiento (pre-crear para que el cliente pueda WaitForChild)
obtenerOCrear(carpetaEventos, "RemoteEvent", "CraftearCofreAlm")
obtenerOCrear(carpetaEventos, "RemoteEvent", "AbrirCofreAlm")
obtenerOCrear(carpetaEventos, "RemoteEvent", "MoverAlCofre")
obtenerOCrear(carpetaEventos, "RemoteEvent", "MoverAlInventario")
obtenerOCrear(carpetaEventos, "RemoteEvent", "CofreAlmActualizado")

-- Inicializar sistema de cofre de almacenamiento
SesionCofreAlm.inicializar()

-- ============================================================
-- Carpetas raíz
-- ============================================================
local carpetaSesionesWS = obtenerOCrear(workspace,         "Folder", "Sesiones")
local carpetaSesionesRS = obtenerOCrear(ReplicatedStorage, "Folder", "Sesiones")

-- ============================================================
-- Estado global del manager
-- ============================================================
local contadorSesion = 0
local sesiones       = {}   -- { [id] = { jugadores, carpeta, carpetaRS, cancelar } }
local sesionPorJugador = {}  -- { [player] = sesionId }

-- ============================================================
-- Limpiar sesión vacía
-- ============================================================
local function limpiarSesion(id)
	local s = sesiones[id]
	if not s then return end
	s.cancelar = true
	if s.carpeta and s.carpeta.Parent then
		s.carpeta:Destroy()
	end
	if s.carpetaRS and s.carpetaRS.Parent then
		s.carpetaRS:Destroy()
	end
	sesiones[id] = nil
	print(string.format("[SesionManager] Sesion %d limpiada.", id))
end

-- ============================================================
-- Crear nueva sesión para un grupo de jugadores
-- ============================================================
function M.nuevaSesion(grupo)
	if #grupo == 0 then return end

	-- Reiniciar ciclo día/noche en la primera sesión para que el timer empiece en 0
	if not primeraSesionFired then
		primeraSesionFired = true
		bePrimeraSesion:Fire()
	end

	contadorSesion += 1
	local id      = contadorSesion
	local offsetX = id * 2000

	-- Carpeta en Workspace/Sesiones/Sesion_[id]
	local carpeta = Instance.new("Folder")
	carpeta.Name   = "Sesion_" .. id
	carpeta.Parent = carpetaSesionesWS

	-- Carpeta en ReplicatedStorage/Sesiones/Sesion_[id]
	local carpetaRS = Instance.new("Folder")
	carpetaRS.Name   = "Sesion_" .. id
	carpetaRS.Parent = carpetaSesionesRS

	-- Nivel de campamento propio de esta sesión
	local nivelCampamento = Instance.new("NumberValue")
	nivelCampamento.Name   = "NivelCampamento"
	nivelCampamento.Value  = 1
	nivelCampamento.Parent = carpetaRS

	-- Registro de la sesión
	local sesionRef = {
		jugadores = {},
		carpeta   = carpeta,
		carpetaRS = carpetaRS,
		cancelar  = false,
	}
	sesiones[id] = sesionRef

	-- Marcar atributos de cada jugador
	for _, player in ipairs(grupo) do
		player:SetAttribute("SesionActual",  id)
		player:SetAttribute("SesionOffsetX", offsetX)
		table.insert(sesionRef.jugadores, player)
		sesionPorJugador[player] = id
	end

	-- Notificar pantalla de carga
	for _, player in ipairs(grupo) do
		evSesionPreparando:FireClient(player)
	end

	-- Generar mundo (sincrónico: crea suelo, barreras y posiciones)
	SesionMundoGen.generar(id, offsetX, carpeta)

	-- Campamento (registra también HoguerasActivas que usan los enemigos)
	SesionCampamento.crear(id, offsetX, carpeta, nivelCampamento)

	-- Recursos recolectables
	SesionRecursos.crear(id, carpeta)

	-- Cofres (arrancan loops de respawn)
	SesionCofres.crear(id, carpeta, sesionRef)

	-- Enemigos (arrancan loops de IA)
	SesionEnemigos.iniciar(id, carpeta, sesionRef)

	-- Cargar personajes (CharacterAdded → Combate posiciona con offsetX)
	for _, player in ipairs(grupo) do
		player:LoadCharacter()
	end

	-- Esperar a que el personaje esté visible antes de quitar la pantalla de carga
	task.wait(1.5)
	for _, player in ipairs(grupo) do
		evSesionLista:FireClient(player)
	end

	print(string.format("[SesionManager] Sesion %d creada (offsetX=%d) con %d jugadores.",
		id, offsetX, #grupo))
end

-- ============================================================
-- Jugador sale del juego (vuelve al lobby o desconecta)
-- ============================================================
function M.playerSale(player)
	local id = sesionPorJugador[player]
	if not id then return end
	sesionPorJugador[player] = nil

	local s = sesiones[id]
	if not s then return end

	-- Destruir cofre de almacenamiento del jugador
	SesionCofreAlm.limpiarJugador(player)

	-- Limpiar atributos de sesión
	player:SetAttribute("SesionActual",  nil)
	player:SetAttribute("SesionOffsetX", nil)

	-- Quitar de la lista de jugadores de la sesión
	for i, p in ipairs(s.jugadores) do
		if p == player then
			table.remove(s.jugadores, i)
			break
		end
	end

	-- Si la sesión quedó vacía, limpiarla
	if #s.jugadores == 0 then
		limpiarSesion(id)
	end
end

-- ============================================================
-- Limpiar cuando un jugador se desconecta del servidor
-- ============================================================
Players.PlayerRemoving:Connect(function(player)
	M.playerSale(player)
end)

return M

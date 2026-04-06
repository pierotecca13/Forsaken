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

evDescartar.OnServerEvent:Connect(function(player, recurso, cantidad)
	-- Validación básica de tipos (anti-exploit)
	if type(recurso)   ~= "string" then return end
	if type(cantidad)  ~= "number" then return end
	cantidad = math.max(1, math.floor(cantidad))

	InventarioManager.descartar(player, recurso, cantidad)
end)

print("[Inventario] Sistema de descarte activo.")

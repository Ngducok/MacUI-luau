local Store = {}
Store.__index = Store

export type Adapter = {
	Load: (() -> { [string]: any }?)?,
	Save: (({ [string]: any }) -> ())?,
	Delay: number?,
}

local function encode(value: any): any
	local kind = typeof(value)
	if kind == "Color3" then
		return { __color = value:ToHex() }
	elseif kind == "EnumItem" then
		return { __enum = tostring(value.EnumType), name = value.Name }
	elseif kind == "table" then
		local out = {}
		for key, item in value do
			out[key] = encode(item)
		end
		return out
	end
	return value
end

local function decode(value: any): any
	if type(value) ~= "table" then
		return value
	end
	if value.__color then
		local ok, color = pcall(Color3.fromHex, value.__color)
		return if ok then color else nil
	end
	if value.__enum then
		local ok, item = pcall(function()
			return Enum[value.__enum][value.name]
		end)
		return if ok then item else nil
	end
	local out = {}
	for key, item in value do
		out[key] = decode(item)
	end
	return out
end

Store.encode = encode
Store.decode = decode

function Store.new(adapter: Adapter?)
	local self = setmetatable({ values = {}, listeners = {}, saved = {}, defined = {}, normalizers = {}, adapter = adapter, auto = 0 }, Store)
	if adapter and adapter.Load then
		local ok, data = pcall(adapter.Load)
		if ok and type(data) == "table" then
			self.saved = data
		elseif not ok then
			warn(`[MacUI] settings failed to load: {data}`)
		end
	end
	return self
end

function Store:define(id: string?, default: any, normalize: ((any) -> any)?): (string, any)
	if id == nil then
		repeat self.auto += 1; id = `_auto{self.auto}` until not self.defined[id]
	end
	assert(type(id) == "string" and id ~= "", "Flag Id must be a non-empty string")
	assert(not self.defined[id], `Flag id "{id}" already exists in this window`)

	local value = default
	local raw = self.saved[id]
	if raw ~= nil then
		local decoded = decode(raw)
		if decoded ~= nil and typeof(decoded) == typeof(default) then
			value = decoded
		end
	end
	if normalize then value = normalize(value) end
	self.defined[id] = true
	self.normalizers[id] = normalize
	self.values[id] = value
	return id, value
end

function Store:get(id: string): any
	return self.values[id]
end

function Store:set(id: string, value: any): boolean
	if self.normalizers[id] then value = self.normalizers[id](value) end
	local old = self.values[id]
	if old == value and type(value) ~= "table" then
		return false
	end
	self.values[id] = value
	local list = self.listeners[id]
	if list then
		for _, fn in table.clone(list) do
			fn(value, old)
		end
	end
	self:_queueSave()
	return true
end

function Store:observe(id: string, fn: (any, any) -> ()): () -> ()
	local list = self.listeners[id]
	if not list then
		list = {}
		self.listeners[id] = list
	end
	table.insert(list, fn)
	return function()
		local index = table.find(list, fn)
		if index then
			table.remove(list, index)
		end
	end
end

-- Drops the value only; other subscribers (e.g. Window:OnFlagChanged) keep their listeners.
function Store:remove(id: string)
	self.values[id] = nil
	self.defined[id] = nil
	self.normalizers[id] = nil
end

function Store:snapshot(): { [string]: any }
	local out = {}
	for id, value in self.values do
		if string.sub(id, 1, 1) ~= "_" then
			out[id] = encode(value)
		end
	end
	return out
end

function Store:_queueSave()
	local adapter = self.adapter
	if not (adapter and adapter.Save) or self.pending then
		return
	end
	self.pending = true
	task.delay(adapter.Delay or 2, function()
		self.pending = false
		local ok, err = pcall(adapter.Save, self:snapshot())
		if not ok then
			warn(`[MacUI] settings failed to save: {err}`)
		end
	end)
end

return Store

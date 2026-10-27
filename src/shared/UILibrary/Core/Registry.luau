local Registry = {}
Registry.__index = Registry

export type Entry = {
	id: string,
	kind: "page" | "card" | "control",
	title: string,
	subtitle: string?,
	keywords: string?,
	aliases: (string | { string })?,
	icon: any?,
	state: (() -> string?)?,
	shortcut: string?,
	activate: () -> (),
	visible: (() -> boolean)?,
}

function Registry.new()
	return setmetatable({ entries = {}, order = {}, counter = 0 }, Registry)
end

function Registry:add(entry: Entry): () -> ()
	assert(type(entry.id) == "string" and entry.id ~= "" and type(entry.title) == "string" and type(entry.activate) == "function", "Search entries need an id, title and activate callback")
	self:remove(entry.id)
	self.counter += 1
	local record = {
		entry = entry,
		index = self.counter,
		title = string.lower(entry.title),
		haystack = "",
	}
	self.entries[entry.id] = record
	table.insert(self.order, record)
	self:update(entry.id, {})
	return function()
		if self.entries[entry.id] == record then
			self:remove(entry.id)
		end
	end
end

function Registry:remove(id: string)
	local record = self.entries[id]
	if record then
		self.entries[id] = nil
		local index = table.find(self.order, record)
		if index then
			table.remove(self.order, index)
		end
	end
end

function Registry:update(id: string, fields: { [string]: any })
	local record = self.entries[id]
	if not record then
		return
	end
	for key, value in fields do
		record.entry[key] = value
	end
	local entry = record.entry
	record.title = string.lower(entry.title)
	local aliases = if type(entry.aliases) == "table" then table.concat(entry.aliases, " ") else entry.aliases or ""
	record.haystack = string.lower(`{entry.title} {entry.subtitle or ""} {entry.keywords or ""} {aliases}`)
end

function Registry:get(id: string): Entry?
	local record = self.entries[id]
	return record and record.entry
end

function Registry:count(): number
	return #self.order
end

local KIND_BONUS = { page = 30, card = 20, control = 0 }

local function score(record, terms: { string }): number?
	local total = KIND_BONUS[record.entry.kind] or 0
	local phrase = table.concat(terms, " ")
	if record.title == phrase then
		total += 1000
	elseif string.sub(record.title, 1, #phrase) == phrase then
		total += 500
	end
	for i, term in terms do
		local at = string.find(record.haystack, term, 1, true)
		if not at then
			return nil
		end
		if i == 1 and string.sub(record.title, 1, #term) == term then
			total += 100
		elseif string.find(record.title, " " .. term, 1, true) then
			total += 60
		elseif string.find(record.title, term, 1, true) then
			total += 40
		else
			total += 10
		end
	end
	return total - #record.title * 0.1
end

function Registry:search(query: string, limit: number?): { Entry }
	local terms = string.split(string.lower(query), " ")
	for i = #terms, 1, -1 do
		if terms[i] == "" then
			table.remove(terms, i)
		end
	end

	local hits = {}
	for _, record in self.order do
		local visible = record.entry.visible
		if visible and not visible() then
			continue
		end
		local value = if #terms == 0 then 0 else score(record, terms)
		if value then
			table.insert(hits, { record = record, score = value })
		end
	end

	table.sort(hits, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.record.index < b.record.index
	end)

	local out = {}
	for i = 1, math.min(#hits, limit or 50) do
		out[i] = hits[i].record.entry
	end
	return out
end

return Registry

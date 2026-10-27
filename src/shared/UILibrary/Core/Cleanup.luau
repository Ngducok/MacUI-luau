local Cleanup = {}
Cleanup.__index = Cleanup

export type Task = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () }

function Cleanup.new()
	return setmetatable({ tasks = {} }, Cleanup)
end

function Cleanup:add<T>(task: T): T
	table.insert(self.tasks, task)
	return task
end

function Cleanup:connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	return self:add(signal:Connect(fn))
end

function Cleanup:count(): number
	return #self.tasks
end

function Cleanup:clean()
	local tasks = self.tasks
	for i = #tasks, 1, -1 do
		local task = tasks[i]
		tasks[i] = nil
		local kind = typeof(task)
		if kind == "RBXScriptConnection" then
			task:Disconnect()
		elseif kind == "Instance" then
			task:Destroy()
		elseif kind == "function" then
			task()
		elseif kind == "table" and task.Destroy then
			task:Destroy()
		end
	end
end

Cleanup.Destroy = Cleanup.clean

return Cleanup

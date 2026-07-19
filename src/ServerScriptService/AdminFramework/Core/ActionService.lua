--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

local ActionService = {}
ActionService.__index = ActionService

function ActionService.new(context)
    return setmetatable({
        _context = context,
        _actions = {},
        _modules = {},
    }, ActionService)
end

function ActionService:RegisterModule(moduleDefinition)
    assert(typeof(moduleDefinition) == "table", "Module definition must be a table")
    assert(typeof(moduleDefinition.Name) == "string", "Module requires a Name")
    assert(typeof(moduleDefinition.Actions) == "table", "Module requires Actions")

    self._modules[moduleDefinition.Name] = moduleDefinition
    for _, action in moduleDefinition.Actions do
        assert(typeof(action.Name) == "string", "Action requires a Name")
        assert(typeof(action.Permission) == "string", "Action requires a Permission")
        assert(typeof(action.Execute) == "function", "Action requires Execute")
        assert(self._actions[action.Name] == nil, "Duplicate action: " .. action.Name)
        action.Module = moduleDefinition.Name
        self._actions[action.Name] = action
    end
end

function ActionService:IsModuleEnabled(moduleName: string): boolean
    local runtime = self._context.RuntimeSettings.Modules[moduleName]
    if runtime ~= nil then
        return runtime
    end
    return self._context.Config.Modules[moduleName] ~= false
end

function ActionService:SetModuleEnabled(moduleName: string, enabled: boolean): (boolean, string)
    if not self._modules[moduleName] then
        return false, "Unknown module"
    end
    self._context.RuntimeSettings.Modules[moduleName] = enabled
    return true, string.format("%s module %s", moduleName, if enabled then "enabled" else "disabled")
end

function ActionService:GetModuleStates(): {any}
    local states = {}
    for name, definition in self._modules do
        table.insert(states, {
            Name = name,
            Enabled = self:IsModuleEnabled(name),
            Description = definition.Description or "",
            ActionCount = #definition.Actions,
        })
    end
    table.sort(states, function(a, b)
        return a.Name < b.Name
    end)
    return states
end

function ActionService:Execute(actor: Player, actionName: string, payload: any): {[string]: any}
    local action = self._actions[actionName]
    if not action then
        self._context.SecurityService:AddStrike(actor, "Unknown action: " .. tostring(actionName))
        return { Success = false, Message = "Unknown action" }
    end

    local rateAllowed, rateReason = self._context.SecurityService:CheckRateLimit(actor, actionName)
    if not rateAllowed then
        return { Success = false, Message = rateReason }
    end

    if not self:IsModuleEnabled(action.Module) and not self._context.RankService:IsOwnerUserId(actor.UserId) then
        return { Success = false, Message = "That module is disabled" }
    end

    if not self._context.RankService:HasPermission(actor, action.Permission) then
        self._context.LogService:Write(Constants.LogCategories.Security, actionName, actor, {
            Success = false,
            Message = "Permission denied",
            Payload = payload,
        })
        return { Success = false, Message = "Permission denied" }
    end

    local normalized = if typeof(payload) == "table" then payload else {}
    if action.Validate then
        local validateOk, valid, valueOrReason = pcall(action.Validate, self._context, actor, normalized)
        if not validateOk then
            self._context.LogService:Write(Constants.LogCategories.Errors, actionName .. ".Validate", actor, {
                Success = false,
                Message = tostring(valid),
                Payload = payload,
            })
            return { Success = false, Message = "Action validation failed" }
        end
        if not valid then
            return { Success = false, Message = tostring(valueOrReason or "Invalid request") }
        end
        if typeof(valueOrReason) == "table" then
            normalized = valueOrReason
        end
    end

    local executeOk, result = pcall(action.Execute, self._context, actor, normalized)
    if not executeOk then
        self._context.LogService:Write(Constants.LogCategories.Errors, actionName, actor, {
            Success = false,
            Message = tostring(result),
            Payload = normalized,
        })
        return { Success = false, Message = "Action failed safely; the error was logged" }
    end

    if typeof(result) ~= "table" then
        result = { Success = true, Message = tostring(result or "Action completed") }
    end
    if result.Success == nil then
        result.Success = true
    end

    local category = action.Category or Constants.LogCategories.Commands
    self._context.LogService:Write(category, actionName, actor, {
        Success = result.Success,
        Message = result.Message or actionName,
        TargetUserId = normalized.TargetUserId,
        TargetName = normalized.TargetName,
        Payload = normalized,
    })
    if result.Success then
        self._context.AnalyticsService:RecordAction(actor, category)
    end
    return Util.serializable(result)
end

return ActionService

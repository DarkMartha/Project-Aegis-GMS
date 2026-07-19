--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataStoreManager = {}
DataStoreManager.__index = DataStoreManager

export type DataStoreManager = typeof(setmetatable({} :: {
    _stores: {[string]: GlobalDataStore},
    _memoryFallback: {[string]: {[string]: any}},
    _warnedFallback: {[string]: boolean},
}, DataStoreManager))

function DataStoreManager.new(): DataStoreManager
    return setmetatable({
        _stores = {},
        _memoryFallback = {},
        _warnedFallback = {},
    }, DataStoreManager)
end

function DataStoreManager:_storeName(alias: string): string
    local configured = Config.DataStores[alias]
    assert(typeof(configured) == "string", string.format("Unknown DataStore alias: %s", alias))
    return Config.DataStores.Prefix .. configured
end

function DataStoreManager:_getStore(alias: string): GlobalDataStore
    if not self._stores[alias] then
        self._stores[alias] = DataStoreService:GetDataStore(self:_storeName(alias))
    end
    return self._stores[alias]
end

function DataStoreManager:_memoryBucket(alias: string): {[string]: any}
    if not self._memoryFallback[alias] then
        self._memoryFallback[alias] = {}
    end
    return self._memoryFallback[alias]
end

function DataStoreManager:_canFallback(): boolean
    return RunService:IsStudio() and Config.Persistence.AllowStudioMemoryFallback
end

function DataStoreManager:_warnFallback(alias: string, errorMessage: any)
    if self._warnedFallback[alias] then
        return
    end
    self._warnedFallback[alias] = true
    warn(string.format(
        "[Aegis GMS] DataStore '%s' is unavailable in Studio. Using temporary memory. Error: %s",
        alias,
        tostring(errorMessage)
    ))
end

function DataStoreManager:_retry(operationName: string, callback: () -> any): (boolean, any)
    if not Config.Persistence.Enabled then
        return false, "Persistence is disabled"
    end

    local attempts = math.max(1, Config.Persistence.RetryCount)
    local lastError = nil
    for attempt = 1, attempts do
        local ok, result = pcall(callback)
        if ok then
            return true, result
        end
        lastError = result
        if attempt < attempts then
            task.wait(Config.Persistence.RetryDelaySeconds * attempt)
        end
    end
    return false, string.format("%s failed: %s", operationName, tostring(lastError))
end

function DataStoreManager:Get(alias: string, key: string, defaultValue: any?): (any, string?)
    local ok, value = self:_retry("GetAsync", function()
        return self:_getStore(alias):GetAsync(key)
    end)

    if ok then
        if value == nil then
            return Util.deepCopy(defaultValue), nil
        end
        return value, nil
    end

    if self:_canFallback() then
        self:_warnFallback(alias, value)
        local memoryValue = self:_memoryBucket(alias)[key]
        if memoryValue == nil then
            return Util.deepCopy(defaultValue), nil
        end
        return Util.deepCopy(memoryValue), nil
    end

    return Util.deepCopy(defaultValue), tostring(value)
end

function DataStoreManager:Set(alias: string, key: string, value: any): (boolean, string?)
    local serializableValue = Util.serializable(value)
    local ok, result = self:_retry("SetAsync", function()
        self:_getStore(alias):SetAsync(key, serializableValue)
        return true
    end)

    if ok then
        return true, nil
    end

    if self:_canFallback() then
        self:_warnFallback(alias, result)
        self:_memoryBucket(alias)[key] = Util.deepCopy(serializableValue)
        return true, nil
    end

    return false, tostring(result)
end

function DataStoreManager:Update(alias: string, key: string, transform: (any) -> any, defaultValue: any?): (boolean, any)
    local ok, result = self:_retry("UpdateAsync", function()
        return self:_getStore(alias):UpdateAsync(key, function(oldValue)
            local baseValue = if oldValue == nil then Util.deepCopy(defaultValue) else oldValue
            return Util.serializable(transform(baseValue))
        end)
    end)

    if ok then
        return true, result
    end

    if self:_canFallback() then
        self:_warnFallback(alias, result)
        local bucket = self:_memoryBucket(alias)
        local oldValue = bucket[key]
        if oldValue == nil then
            oldValue = Util.deepCopy(defaultValue)
        end
        local transformed = Util.serializable(transform(Util.deepCopy(oldValue)))
        bucket[key] = transformed
        return true, Util.deepCopy(transformed)
    end

    return false, tostring(result)
end

function DataStoreManager:Remove(alias: string, key: string): (boolean, string?)
    local ok, result = self:_retry("RemoveAsync", function()
        self:_getStore(alias):RemoveAsync(key)
        return true
    end)

    if ok then
        return true, nil
    end

    if self:_canFallback() then
        self:_warnFallback(alias, result)
        self:_memoryBucket(alias)[key] = nil
        return true, nil
    end

    return false, tostring(result)
end

function DataStoreManager:RawGet(alias: string, key: string): (any, string?)
    return self:Get(alias, key, nil)
end

return DataStoreManager

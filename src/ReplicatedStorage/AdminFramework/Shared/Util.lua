--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Util = {}

function Util.trim(value: string): string
    return string.match(value, "^%s*(.-)%s*$") or ""
end

function Util.clampString(value: any, maxLength: number, fallback: string?): string
    if typeof(value) ~= "string" then
        return fallback or ""
    end

    local cleaned = Util.trim(value)
    if #cleaned > maxLength then
        return string.sub(cleaned, 1, maxLength)
    end
    return cleaned
end

function Util.toInteger(value: any): number?
    local numeric = tonumber(value)
    if numeric == nil or numeric ~= numeric then
        return nil
    end
    return math.floor(numeric)
end

function Util.toNumber(value: any): number?
    local numeric = tonumber(value)
    if numeric == nil or numeric ~= numeric then
        return nil
    end
    return numeric
end

function Util.findPlayer(value: any): Player?
    if typeof(value) == "Instance" and value:IsA("Player") then
        return value
    end

    local userId = Util.toInteger(value)
    if userId then
        return Players:GetPlayerByUserId(userId)
    end

    if typeof(value) == "string" then
        local needle = string.lower(Util.trim(value))
        if needle == "" then
            return nil
        end
        for _, player in Players:GetPlayers() do
            if string.sub(string.lower(player.Name), 1, #needle) == needle
                or string.sub(string.lower(player.DisplayName), 1, #needle) == needle then
                return player
            end
        end
    end

    return nil
end

function Util.safeUserName(userId: number): string
    local player = Players:GetPlayerByUserId(userId)
    if player then
        return player.Name
    end

    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    return if ok then name else tostring(userId)
end

function Util.shallowCopy<T>(source: T): T
    local result = {}
    for key, value in source :: any do
        result[key] = value
    end
    return result :: T
end

function Util.deepCopy(value: any, seen: {[any]: any}?): any
    if typeof(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, child in value do
        copy[Util.deepCopy(key, seen)] = Util.deepCopy(child, seen)
    end
    return copy
end

function Util.arrayContains<T>(array: {T}, wanted: T): boolean
    for _, item in array do
        if item == wanted then
            return true
        end
    end
    return false
end

function Util.removeArrayValue<T>(array: {T}, wanted: T)
    for index = #array, 1, -1 do
        if array[index] == wanted then
            table.remove(array, index)
        end
    end
end

function Util.guid(): string
    return HttpService:GenerateGUID(false)
end

function Util.isoTimestamp(timestamp: number?): string
    return os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp or os.time())
end

function Util.serializable(value: any, depth: number?): any
    depth = depth or 0
    if depth > 6 then
        return "<max-depth>"
    end

    local kind = typeof(value)
    if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
        return value
    elseif kind == "Vector3" then
        return { x = value.X, y = value.Y, z = value.Z, __type = "Vector3" }
    elseif kind == "CFrame" then
        return { components = { value:GetComponents() }, __type = "CFrame" }
    elseif kind == "Color3" then
        return { r = value.R, g = value.G, b = value.B, __type = "Color3" }
    elseif kind == "Instance" then
        return value:GetFullName()
    elseif kind == "table" then
        local output = {}
        local count = 0
        for key, child in value do
            count += 1
            if count > 60 then
                output["<truncated>"] = true
                break
            end
            output[tostring(key)] = Util.serializable(child, depth + 1)
        end
        return output
    end

    return tostring(value)
end

function Util.getCharacterParts(player: Player): (Model?, Humanoid?, BasePart?)
    local character = player.Character
    if not character then
        return nil, nil, nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and not root:IsA("BasePart") then
        root = nil
    end
    return character, humanoid, root :: BasePart?
end

return table.freeze(Util)

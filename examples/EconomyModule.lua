--!strict

-- Copy this ModuleScript into ServerScriptService/AdminFramework/Modules
-- after replacing the example economy write with your own server service.

return {
    Name = "Economy",
    Description = "Example extension module for a game-specific currency system.",
    Actions = {
        {
            Name = "Economy.SetCoins",
            Permission = "Developer.Test",
            Category = "Commands",
            Validate = function(_context, _actor, payload)
                local userId = tonumber(payload.TargetUserId)
                local amount = tonumber(payload.Amount)
                if not userId or userId <= 0 then
                    return false, "A valid TargetUserId is required"
                end
                if not amount then
                    return false, "Amount must be a number"
                end
                return true, {
                    TargetUserId = math.floor(userId),
                    Amount = math.clamp(math.floor(amount), 0, 1_000_000),
                }
            end,
            Execute = function(_context, _actor, payload)
                -- Example:
                -- EconomyService:SetCoins(payload.TargetUserId, payload.Amount)
                return {
                    Success = true,
                    Message = string.format("Economy adapter received %d coins for %d", payload.Amount, payload.TargetUserId),
                }
            end,
        },
    },
}

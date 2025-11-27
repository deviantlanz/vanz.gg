local function removeInvisibleWalls()
    local map = game.Workspace:FindFirstChild("Map")
    if map then
        local raid01Map = map:FindFirstChild("Raid01Map")
        if raid01Map then
            local innerMap = raid01Map:FindFirstChild("Map")
            if innerMap then
                local union = innerMap:FindFirstChild("Union")
                if union then union:Destroy() end
                
                local part29 = innerMap:FindFirstChild("Part29")
                if part29 then part29:Destroy() end
                
                local part31 = innerMap:FindFirstChild("Part31")
                if part31 then part31:Destroy() end
            end
        end
    end
end

removeInvisibleWalls()

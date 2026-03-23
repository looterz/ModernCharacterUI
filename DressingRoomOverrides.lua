-- Feature flags for our copied Transmog code.
-- Prefixed to avoid tainting Blizzard's own globals when Blizzard_Transmog loads.

function MCUDR_DressUpFrameLinkingSupported()
    return true
end

function MCUDR_DisplayTypeUnassignedSupported()
    return true
end

function MCUDR_HelpPlatesSupported()
    return false
end

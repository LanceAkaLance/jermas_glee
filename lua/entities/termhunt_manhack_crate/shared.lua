AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Box Of Manhacks"
ENT.Author      = "StrawWagen"
ENT.Purpose     = ""
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

function ENT:GetGivenScore()
    local plys = player.GetAll()
    local smallestDist = math.huge
    local scoreGiven = nil

    for _, currentPly in ipairs( plys ) do
        if currentPly:Health() <= 0 then continue end
        local distToCurrentPlySqr = self:GetPos():DistToSqr( currentPly:GetPos() )
        if distToCurrentPlySqr < smallestDist then
            smallestDist = distToCurrentPlySqr
        end
    end

    local smallestDistLinear = math.sqrt( smallestDist )

    if smallestDistLinear < 500 then
        scoreGiven = -100

    elseif smallestDistLinear < 1500 then
        scoreGiven = -50

    else
        scoreGiven = 0

    end
    return scoreGiven

end

hook.Add( "HUDPaint", "manhackcrate_paintscore", function()
    if not GAMEMODE.CanShowDefaultHud or not GAMEMODE:CanShowDefaultHud() then return end
    if not IsValid( LocalPlayer().glee_manhackCrate ) then return end

    local screenMiddleW = ScrW() / 2
    local screenMiddleH = ScrH() / 2

    local scoreGained = math.Round( GAMEMODE:ValidNum( LocalPlayer().glee_manhackCrate.oldScoreGiven ) )

    local scoreGainedString = "Manhacking Score: " .. tostring( scoreGained )
    surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

end )

function ENT:SetupPlayer()
    self.player.glee_manhackCrate = self
    self.player.ghostEnt = self
end

if not SERVER then return end

local GM = GAMEMODE

function GM:ManhackCrate( pos )
    local crate = ents.Create( "prop_physics" )
    crate:SetModel( "models/Items/item_item_crate.mdl" )
    crate:SetPos( pos )
    crate:Spawn()

    crate.glee_IsManhackCrate = true

    crate.terminatorHunterInnateReaction = function()
        return MEMORY_BREAKABLE
    end

    return crate

end

local function getCreationPos( ent )
    local creationPos = ent:GetPos() + ( VectorRand() * ent:GetModelRadius() )
    creationPos = ent:WorldToLocal( ent:NearestPoint( creationPos ) )
    creationPos = creationPos * 0.6
    return ent:LocalToWorld( creationPos )

end

hook.Add( "PropBreak", "glee_spawn_rewarding_manhacks", function( breaker, broken )
    if not broken.glee_IsManhackCrate then return end
    for _ = 1, 5 do
        local creationPos = getCreationPos( broken )

        local manhack = ents.Create( "npc_manhack" )
        manhack:SetPos( creationPos )
        manhack:SetAngles( AngleRand() )
        manhack:Spawn()

        SafeRemoveEntityDelayed( manhack, 240 )

        if broken.player then
            manhack.glee_ManhackCrateInitialOwner = broken.player
            manhack.glee_ManhackCrateDamagingId = broken:GetCreationID()

        end
    end
    for _ = 1, 5 do
        local creationPos = getCreationPos( broken )
        local score = ents.Create( "termhunt_score_pickup" )
        score:SetPos( creationPos )
        score:SetAngles( AngleRand() )
        score:Spawn()

    end
end )

hook.Add( "EntityTakeDamage", "glee_rewarding_manhacks_reward", function ( target, dmg )
    local attacker = dmg:GetAttacker()
    if not IsValid( attacker ) then return end
    if not attacker.glee_ManhackCrateDamagingId then return end

    local owner = attacker.glee_ManhackCrateInitialOwner
    if not IsValid( owner ) then return end

    local canDamageTbl = owner.glee_ManhacksThatCanDamage
    if not canDamageTbl then return end

    -- already spent!
    if not canDamageTbl[ attacker.glee_ManhackCrateDamagingId ] then return end
    if not owner.GivePlayerScore then return end

    owner.glee_ManhacksThatCanDamage[ attacker.glee_ManhackCrateDamagingId ] = nil
    if target:IsPlayer() then
        if target == owner then
            huntersGlee_Announce( { owner }, 5, 10, "You've been damaged by your own manhacks..." )

        else
            owner:GivePlayerScore( 75 )
            huntersGlee_Announce( { owner }, 5, 10, "The manhacks have damaged a player! You gain 75 score!" )

        end
    elseif target:IsNextBot() then
        owner:GivePlayerScore( 25 )
        huntersGlee_Announce( { owner }, 5, 10, "The manhacks have damaged a terminator. You only gain 25 score." )

    end
end )

hook.Add( "PostCleanupMap", "glee_cleanup_stale_manhackcrate", function()
    for _, ply in ipairs( player.GetAll() ) do
        ply.glee_ManhacksThatCanDamage = nil

    end
end )

function ENT:Place()

    local betrayalScore = self:GetGivenScore()
    local crate = GM:ManhackCrate( self:GetPos2() )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        crate.player = self.player
        self.player.glee_ManhacksThatCanDamage = self.player.glee_ManhacksThatCanDamage or {}
        self.player.glee_ManhacksThatCanDamage[ crate:GetCreationID() ] = true
        self.player:GivePlayerScore( betrayalScore )

    end
    SafeRemoveEntity( self )

end
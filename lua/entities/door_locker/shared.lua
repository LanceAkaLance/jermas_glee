AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Door Locker"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Locks doors"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

function ENT:PostInitializeFunc()
    if CLIENT then
        -- HACK
        self:SetNoDraw( true )

    end
    --self:SetOwner( Entity( 1 ) )
end

function ENT:GetNearestDoor()
    local nearestDoor = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all prop_door_rotating entities within a radius of 2048 units
    local doors = ents.FindInSphere( myPos, 2048 )
    for _, door in ipairs( doors ) do
        if door:GetClass() == "prop_door_rotating" then
            if not util.doorIsUsable( door ) then continue end
            -- Calculate the distance between the door and the entity
            local distance = myPos:Distance( door:GetPos() )
            if distance < nearestDistance then
                nearestDoor = door
                nearestDistance = distance

            end
        end
    end

    return nearestDoor
end

function ENT:NukeHighlighter()
    if SERVER then return end
    SafeRemoveEntity( self.player.doorHighliter )

end

if CLIENT then

    local materialOverride = render.MaterialOverride
    local setColorModulation = render.SetColorModulation
    local cam_Start3D = cam.Start3D
    local cam_End3D = cam.End3D

    local doorOverrideMat = CreateMaterial( "CHAMSMATDOORLOCKER1", "UnlitGeneric", { ["$basetexture"] = "lights/white001", ["$model"] = 1, ["$ignorez"] = 1 } )

    function ENT:HighlightNearestDoor()
        if not IsValid( self.nearestDoor ) then return end
        if not IsValid( self.player.doorHighliter ) then
            self.player.doorHighliter = ClientsideModel( self.nearestDoor:GetModel() )

            self.player.doorHighliter:Spawn()

        elseif self.lastNearestDoor ~= self.nearestDoor then
            self.lastNearestDoor = self.nearestDoor
            self.nearestDoor:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 100, 200 )
            self.player.doorHighliter:SetModel( self.nearestDoor:GetModel() )
            self.player.doorHighliter:SetPos( self.nearestDoor:GetPos() )
            self.player.doorHighliter:SetAngles( self.nearestDoor:GetAngles() )

        end
        if IsValid( self.player.doorHighliter ) then

            cam_Start3D();
                materialOverride( doorOverrideMat )

                setColorModulation( 255, 255, 255 )

                self.player.doorHighliter:DrawModel()
                materialOverride()

            cam_End3D();

        end
    end
end

function ENT:CanPlace()
    if not IsValid( self.nearestDoor ) then return end
    return true

end

function ENT:ModifiableThink()
    self:SetPos( self.player:GetEyeTrace().HitPos + self.PosOffset )

    self.nearestDoor = self:GetNearestDoor()
    if CLIENT then
        -- HACK
        self:SetNoDraw( true )

    end

    if SERVER and self:AliveCheck() then return end

end

function ENT:SetupPlayer()
    self.player.doorLocker = self
    self.player.ghostEnt = self
    if CLIENT and LocalPlayer() == self.player then
        hook.Add( "PostDrawOpaqueRenderables", "termHuntDrawNearestDoorDoorLocker", function()
            if not IsValid( self ) or not IsValid( self.player ) then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestDoorDoorLocker" ) return end
            if self.player ~= LocalPlayer() then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestDoorDoorLocker" ) return end
            self:HighlightNearestDoor()
        end )
    end
end

-- lock a prop_door_rotating
-- then run a function when the door is used by something

function LockDoorAndRunAFunctionWhenTheDoorIsUsed( door, playerAttaching, functionToRun )
    -- fire the "lock" input to lock the door
    door:Fire( "Lock" )
    door:EmitSound( "doors/door_locked2.wav", 80 )

    door.doorPlayers = door.doorPlayers or {}
    table.insert( door.doorPlayers, playerAttaching )

    local hookName = "CheckUsedEntity_DoorLocker_" .. door:GetCreationID()

    -- add a hook to run when a player uses an entity
    hook.Add( "PlayerUse", hookName, function( thingUsingTheDoor, entity )
        -- check if the used entity is the door
        -- the used entity is the door, so check if it is locked
        if entity == door and door:GetSaveTable().m_bLocked then
            for _, currentlyProcessingPlayer in ipairs( door.doorPlayers ) do
                -- the door is locked, so run the function
                functionToRun( door, thingUsingTheDoor, currentlyProcessingPlayer )

            end
            hook.Remove( hookName )
            -- clear the table
            door.doorPlayers = {}
        end
    end )
end

-- this is ran once on a door, when it's first used by something
-- if it's used by a player then it give currentlyProcessingPlayer some score via player:GivePlayerScore( score )
-- if it's used by a nextbot then give currentlyProcessingPlayer a bit less score
-- if it's used by a player with a specific value, give currentlyProcessingPlayer a bunch of score

local function DoorOnUsedInitial( _, thingUsingTheDoor, currentlyProcessingPlayer )
    if not currentlyProcessingPlayer.GivePlayerScore then return end

    local msg = ""

    -- check if the thing using the door is a player
    if thingUsingTheDoor:IsPlayer() then
        if thingUsingTheDoor == currentlyProcessingPlayer then
            msg = "You've used a door you locked!"

        -- check if the player has a specific value
        elseif IsValid( currentlyProcessingPlayer.huntersGleeHunterThatIsTargetingPly ) then
            -- give the player a bunch of score
            currentlyProcessingPlayer:GivePlayerScore( 150 )
            msg = "A fleeing player has used one of your locked doors, you gain 150 score!"

        else
            -- give the player some score
            currentlyProcessingPlayer:GivePlayerScore( 85 )
            msg = "A player has used one of your locked doors, you gain 85 score!"

        end
    -- check if the thing using the door is a nextbot
    elseif thingUsingTheDoor:IsNextBot() then
        -- give the player a bit less score
        currentlyProcessingPlayer:GivePlayerScore( 25 )
        msg = "A terminator has used one of your locked doors, you gain 25 score!"

    end
    huntersGlee_Announce( { currentlyProcessingPlayer }, 5, 10, msg )

end

function ENT:OnRemove()
    self:NukeHighlighter()

end

function ENT:Place()
    local door = self.nearestDoor
    LockDoorAndRunAFunctionWhenTheDoorIsUsed( door, self.player, DoorOnUsedInitial )
    door:EmitSound( "doors/door_locked2.wav", 80 )

    SafeRemoveEntity( self )

end
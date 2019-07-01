
-- Getters/setters --

function ENT:IsPossessionEnabled()
  return self:GetNWBool("DrGBasePossessionEnabled")
end

function ENT:GetPossessor()
  return self:GetNW2Entity("DrGBasePossessor")
end
function ENT:IsPossessed()
  return IsValid(self:GetPossessor())
end
function ENT:IsPossessor(ent)
  return self:GetPossessor() == ent
end

function ENT:CurrentViewPreset()
  if not self:IsPossessed() then return -1 end
  if #self.PossessionViews == 0 then return -1 end
  local current = self:GetNW2Int("DrGBasePossessionView", 1)
  return current, self.PossessionViews[current]
end
function ENT:CycleViewPresets()
  if SERVER then
    local current = self:CurrentViewPreset()
    if current == -1 then return end
    current = current + 1
    if current > #self.PossessionViews then current = 1 end
    self:SetNW2Int("DrGBasePossessionView", current)
  elseif self:IsPossessedByLocalPlayer() then
    net.Start("DrGBasePossessionCycleViewPresets")
    net.WriteEntity(self)
    net.WriteEntity(LocalPlayer())
    net.SendToServer()
  end
end

-- Functions --

function ENT:PossessorView()
  if not self:IsPossessed() then return end
  local current, preset = self:CurrentViewPreset()
  local center = self:WorldSpaceCenter()
  local eyes = self:GetPossessor():EyeAngles()
  local angles = Angle(-eyes.p, eyes.y + 180, 0)
  if current == -1 then
    return center, angles
  else
    if preset.invertpitch then
      angles.p = -angles.p
    end
    if preset.invertyaw then
      angles.y = -angles.y
    end
    if preset.eyepos then
      center = self:EyePos()
    elseif isstring(preset.bone) then
      local boneid = self:LookupBone(preset.bone)
      if boneid ~= nil then
        center = self:GetBonePosition(boneid)
      end
    end
    local offset = preset.offset or Vector(0, 0, 0)
    local forward = -Angle(0, angles.y, 0):Forward()
    local right = Angle(0, angles.y + 90, 0):Forward()
    local up = Angle(-90, 0, 0):Forward()
    local origin = center +
    forward*offset.x*self:GetModelScale() +
    right*offset.y*self:GetModelScale() +
    up*offset.z*self:GetModelScale()
    local tr1 = util.TraceLine({
      start = center,
      endpos = origin,
      collisiongroup = COLLISION_GROUP_IN_VEHICLE
    })
    if tr1.HitWorld then origin = tr1.HitPos + tr1.Normal*-10 end
    local distance = preset.distance or 1
    if distance < 1 then distance = 1 end
    local endpos = origin + angles:Forward()*distance*self:GetModelScale()
    local tr2 = util.TraceLine({
      start = origin,
      endpos = endpos,
      collisiongroup = COLLISION_GROUP_IN_VEHICLE
    })
    if tr2.HitWorld then endpos = tr2.HitPos + tr2.Normal*-10 end
    local viewangle = (tr2.Normal*-1):Angle()
    return endpos, viewangle
  end
end
function ENT:PossessorTrace(options)
  if not self:IsPossessed() then return end
  local origin, angles = self:PossessorView()
  options = options or {}
  options.filter = options.filter or {}
  table.insert(options.filter, self)
  if self:HasWeapon() then
    table.insert(options.filter, self:GetWeapon())
  end
  options.start = origin
  options.endpos = origin + angles:Forward()*999999999
  return util.TraceLine(options)
end
function ENT:PossessorNormal()
  if not self:IsPossessed() then return end
  local origin, angles = self:PossessorView()
  return angles:Forward()
end
function ENT:PossessorForward()
  if not self:IsPossessed() then return end
  local normal = self:PossessorNormal()
  normal.z = 0
  return normal:GetNormalized()
end
function ENT:PossessorRight()
  if not self:IsPossessed() then return end
  local forward = self:PossessorForward()
  forward:Rotate(Angle(0, -90, 0))
  return forward
end
function ENT:PossessorUp()
  return Vector(0, 0, 1)
end

-- Hooks --

function ENT:OnPossessed() end
function ENT:OnDispossessed() end

-- Handlers --

function ENT:_InitPossession()
  if SERVER then
    self:SetPossessionEnabled(self.PossessionEnabled)
  else
    self:SetNWVarProxy("DrGBasePossessor", function(self, name, old, new)
      if not IsValid(old) and IsValid(new) then self:OnPossessed(new)
      elseif IsValid(old) and not IsValid(new) then self:OnDispossessed(old) end
    end)
  end
end

function ENT:_HandlePossession(cor)
  if not self:IsPossessed() then return end
  local possessor = self:GetPossessor()
  if cor and self:OnPossession() then return end
  if SERVER and not cor then
    if possessor:KeyPressed(IN_USE) then
      self:Dispossess(true)
      return true
    elseif possessor:KeyPressed(IN_ZOOM) then
      self:CycleViewPresets()
      return true
    elseif possessor:KeyDown(IN_ZOOM) then
      possessor:StopZooming()
    end
  end
  if cor then
    local f = possessor:KeyDown(IN_FORWARD)
    local b = possessor:KeyDown(IN_BACK)
    local l = possessor:KeyDown(IN_MOVELEFT)
    local r = possessor:KeyDown(IN_MOVERIGHT)
    local forward = f and not b
    local backward = b and not f
    local right = r and not l
    local left = l and not r
    if self.PossessionMovement == POSSESSION_MOVE_COMPASS then
      self:PossessionFaceForward()
      if forward then self:Approach(self:GetPos() + self:PossessorForward())
      elseif backward then self:Approach(self:GetPos() - self:PossessorForward()) end
      if right then self:Approach(self:GetPos() + self:PossessorRight())
      elseif left then self:Approach(self:GetPos() - self:PossessorRight()) end
    elseif self.PossessionMovement == POSSESSION_MOVE_FORWARD then
      local direction = self:GetPos()
      if forward then direction = direction + self:PossessorForward()
      elseif backward then direction = direction - self:PossessorForward() end
      if right then direction = direction + self:PossessorRight()
      elseif left then direction = direction - self:PossessorRight() end
      if direction ~= self:GetPos() then self:MoveTowards(direction)
      else self:PossessionFaceForward() end
    else self:PossessionControls(forward, backward, right, left) end
    if self.ClimbLadders and navmesh.IsLoaded() then
      local ladders = navmesh.GetNearestNavArea(self:GetPos()):GetLadders()
      for i, ladder in ipairs(ladders) do
        if self.ClimbLadderUp then
          if self:GetHullRangeSquaredTo(ladder:GetBottom()) < self.LaddersUpDistance^2 then
            self:ClimbLadderUp(ladder)
            break
          end
        elseif self.ClimbLaddersDown then
          if self:GetHullRangeSquaredTo(ladder:GetTop()) < self.LaddersDownDistance^2 then
            self:ClimbLadderDown(ladder)
            break
          end
        end
      end
    end
  end
  for key, binds in pairs(self.PossessionBinds) do
    for i, bind in ipairs(binds) do
      if CLIENT and not bind.client then continue end
      if SERVER and ((not cor and bind.coroutine) or (cor and not bind.coroutine)) then continue end
      if bind.onkeypressed == nil then bind.onkeypressed = function() end end
      if bind.onkeydown == nil then bind.onkeydown = function() end end
      if bind.onkeyup == nil then bind.onkeyup = function() end end
      if bind.onkeydownlast == nil then bind.onkeydownlast = function() end end
      if bind.onkeyreleased == nil then bind.onkeyreleased = function() end end
      if possessor:KeyPressed(key) then bind.onkeypressed(self, possessor) end
      if possessor:KeyDown(key) then bind.onkeydown(self, possessor) else bind.onkeyup(self, possessor) end
      if possessor:KeyDownLast(key) then bind.onkeydownlast(self, possessor) end
      if possessor:KeyReleased(key) then bind.onkeyreleased(self, possessor) end
    end
  end
end

if SERVER then
  util.AddNetworkString("DrGBasePossessionCycleViewPresets")

  -- Getters/setters --

  function ENT:SetPossessionEnabled(bool)
    self:SetNWBool("DrGBasePossessionEnabled", bool)
    if not bool and self:IsPossessed() then self:Dispossess() end
  end

  -- Functions --

  function ENT:Possess(ply)
    if not self:IsPossessionEnabled() then return "disabled" end
    if self:IsPossessed() then return "already possessed" end
    if not IsValid(ply) then return "invalid" end
    if not ply:IsPlayer() then return "not player" end
    if not ply:Alive() then return "not alive" end
    if ply:InVehicle() then return "in vehicle" end
    if ply:DrG_IsPossessing() then return "already possessing" end
    if not self:CanPossess(ply) then return "not allowed" end
    self:SetNW2Entity("DrGBasePossessor", ply)
    ply:SetNW2Entity("DrGBasePossessing", self)
    ply:SetNW2Vector("DrGBasePrePossessPos", ply:GetPos())
    ply:SetNW2Angle("DrGBasePrePossessAngle", ply:GetAngles())
    ply:SetNW2Angle("DrGBasePrePossessEyes", ply:EyeAngles())
    ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    ply:SetNoTarget(true)
    ply:SetNoDraw(true)
    self:UpdateEnemy()
    self:SetNW2Int("DrGBasePossessionView", 1)
    self:BehaviourTreeEvent("Possessed", ply)
    self:OnPossessed(ply)
    return "ok"
  end

  function ENT:Dispossess()
    if not self:IsPossessed() then return "not possessed" end
    local ply = self:GetPossessor()
    if not self:CanDispossess(ply) then return "not allowed" end
    self:SetNW2Entity("DrGBasePossessor", nil)
    ply:SetNW2Entity("DrGBasePossessing", nil)
    ply:SetPos(ply:GetNW2Vector("DrGBasePrePossessPos"))
    ply:SetAngles(ply:GetNW2Angle("DrGBasePrePossessAngle"))
    ply:SetEyeAngles(ply:GetNW2Angle("DrGBasePrePossessEyes"))
    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    ply:SetNoTarget(false)
    ply:SetNoDraw(true)
    self:UpdateEnemy()
    self:OnDispossessed(ply)
    return "ok"
  end

  function ENT:PossessionFaceForward()
    if not self:IsPossessed() then return end
    return self:FaceTowards(self:GetPos() + self:PossessorNormal())
  end

  -- Hooks --

  function ENT:CanPossess() return true end
  function ENT:CanDispossess() return true end
  function ENT:OnPossession() end
  function ENT:PossessionControls(forward, backward, right, left) end

  -- Handlers --

  local function MoveEnt(ply, ent)
    if not ply:DrG_IsPossessing() then return end
    local tr = ply:DrG_Possessing():PossessorTrace()
    ent:SetPos(tr.HitPos)
  end
  local function MoveEntModel(ply, model, ent)
    MoveEnt(ply, ent)
  end
  hook.Add("PlayerSpawnedEffect", "DrGBasePlayerPossessingSpawnedEffect", MoveEntModel)
  hook.Add("PlayerSpawnedNPC", "DrGBasePlayerPossessingSpawnedNPC", MoveEnt)
  hook.Add("PlayerSpawnedProp", "DrGBasePlayerPossessingSpawnedProp", MoveEntModel)
  hook.Add("PlayerSpawnedRagdoll", "DrGBasePlayerPossessingSpawnedRagdoll", MoveEntModel)
  hook.Add("PlayerSpawnedSENT", "DrGBasePlayerPossessingSpawnedSENT", MoveEnt)
  hook.Add("PlayerSpawnedSWEP", "DrGBasePlayerPossessingSpawnedSWEP", MoveEnt)
  hook.Add("PlayerSpawnedVehicle", "DrGBasePlayerPossessingSpawnedVehicle", MoveEnt)

  net.Receive("DrGBasePossessionCycleViewPresets", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    local ply = net.ReadEntity()
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ent:IsPossessed() and ent:GetPossessor() == ply then
      ent:CycleViewPresets()
    end
  end)

else

  -- Getters/setters --

  function ENT:IsPossessedByLocalPlayer()
    return self:IsPossessor(LocalPlayer())
  end

  -- Functions --

  -- Hooks --

  function ENT:PossessionHUD() end
  hook.Add("HUDPaint", "DrGBasePossessionHUD", function()
    local possessing = LocalPlayer():DrG_Possessing()
    if not IsValid(possessing) then return end
    local hookres = possessing:PossessionHUD()
    if hookres then return end
    DrGBase.DrawPossessionHUD(possessing)
  end)

  function ENT:PossessionRender() end
  hook.Add("RenderScreenspaceEffects", "DrGBasePossessionDraw", function()
    local possessing = LocalPlayer():DrG_Possessing()
    if not IsValid(possessing) then return end
    possessing:PossessionRender()
  end)

  function ENT:PossessionHalos() end
  hook.Add("PreDrawHalos", "DrGBasePossessionHalos", function()
    local possessing = LocalPlayer():DrG_Possessing()
    if not IsValid(possessing) then return end
    possessing:PossessionHalos()
  end)

  -- Handlers --

end

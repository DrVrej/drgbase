
-- Convars --

local AvoidObstacles = CreateConVar("drgbase_avoid_obstacles", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED})
local MultSpeed = CreateConVar("drgbase_multiplier_speed", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED})

-- Getters/setters --

function ENT:GetSpeed()
  return self:GetNW2Float("DrGBaseSpeed")
end

function ENT:Speed(scale)
  local speed = self:GetVelocity():Length()
  if scale then return math.Round(speed*self:GetScale())
  else return math.Round(speed) end
end
function ENT:SpeedSqr(scale)
  if not scale then return math.Round(self:GetVelocity():LengthSqr())
  else return math.Round((self:GetVelocity()/self:GetScale()):LengthSqr()) end
end
function ENT:IsSpeedMore(speed, scale)
  return speed^2 < self:SpeedSqr(scale)
end
function ENT:IsSpeedLess(speed, scale)
  return speed^2 > self:SpeedSqr(scale)
end
function ENT:IsSpeedEqual(speed, scale)
  return speed^2 == self:SpeedSqr(scale)
end
function ENT:IsSpeedMoreEqual(speed, scale)
  return self:IsSpeedEqual(speed, scale) or self:IsSpeedMore(speed, scale)
end
function ENT:IsSpeedLessEqual(speed, scale)
  return self:IsSpeedEqual(speed, scale) or self:IsSpeedLess(speed, scale)
end

function ENT:GetMovement()
  if not self:IsMoving() then return Vector(0, 0, 0) end
  local dir = self:GetVelocity():Angle()
  local mv = (self:GetAngles()-dir):Forward()
  return Vector(math.Round(mv.x, 2), math.Round(mv.y, 2), -math.Round(mv.z, 2))
end

function ENT:IsMoving()
  return not self:GetVelocity():IsZero()
end
function ENT:IsMovingUp()
  return self:GetMovement().z > 0
end
function ENT:IsMovingDown()
  return self:GetMovement().z < 0
end
function ENT:IsMovingForward()
  return self:GetMovement().x > 0
end
function ENT:IsMovingBackward()
  return self:GetMovement().x < 0
end
function ENT:IsMovingRight()
  return self:GetMovement().y > 0
end
function ENT:IsMovingLeft()
  return self:GetMovement().y < 0
end
function ENT:IsMovingForwardLeft()
  return self:IsMovingForward() and self:IsMovingLeft()
end
function ENT:IsMovingForwardRight()
  return self:IsMovingForward() and self:IsMovingRight()
end
function ENT:IsMovingBackwardLeft()
  return self:IsMovingBackward() and self:IsMovingLeft()
end
function ENT:IsMovingBackwardRight()
  return self:IsMovingBackward() and self:IsMovingRight()
end

function ENT:IsTurning()
  return self:GetAngles().y ~= self._DrGBaseLastAngle.y
end
function ENT:IsTurningLeft()
  if not self:IsTurning() then return false end
  return math.AngleDifference(self:GetAngles().y, self._DrGBaseLastAngle.y) > 0
end
function ENT:IsTurningRight()
  if not self:IsTurning() then return false end
  return math.AngleDifference(self:GetAngles().y, self._DrGBaseLastAngle.y) < 0
end

function ENT:IsClimbing()
  return self:GetNW2Bool("DrGBaseClimbing")
end
function ENT:IsClimbingUp()
  return self:IsClimbing() and not self:IsClimbingDown()
end
function ENT:IsClimbingDown()
  return self:IsClimbing() and self:GetNW2Bool("DrGBaseClimbingDown")
end

-- Functions --

-- Hooks --

-- Handlers --

function ENT:_InitMovements()
  if SERVER then self:LoopTimer(0.1, self.UpdateSpeed) end
  self._DrGBaseLastAngle = self:GetAngles()
end

function ENT:_HandleMovements()
  local angles = self:GetAngles()
  self:Timer(0.1, function()
    self._DrGBaseLastAngle = angles
  end)
end

if SERVER then

  -- Getters/setters --

  function ENT:SetSpeed(speed)
    self.loco:SetDesiredSpeed(speed*self:GetScale())
  end

  function ENT:IsRunning()
    if self:IsMoving() then
      local run = false
      if self:IsPossessed() then
        run = self:GetPossessor():KeyDown(IN_SPEED)
      else run = self:ShouldRun() end
      return run
    else return false end
  end

  function ENT:IsClimbingLadder(ladder)
    if IsValid(ladder) then
      return self:IsClimbingLadder() and ladder == self._DrGBaseClimbLadder
    else
      if not self:IsClimbing() then return false end
      return IsValid(self._DrGBaseClimbLadder), self._DrGBaseClimbLadder
    end
  end
  function ENT:IsClimbingLedge()
    return self:IsClimbing() and not IsValid(self._DrGBaseClimbLadder)
  end

  -- Functions --

  function ENT:Approach(pos, nb)
    if isentity(pos) then pos = pos:GetPos() end
    self.loco:Approach(pos, nb or 1)
  end
  function ENT:FaceTowards(pos)
    if isentity(pos) then pos = pos:GetPos() end
    self.loco:FaceTowards(pos)
  end
  function ENT:FaceInstant(pos)
    if isentity(pos) then pos = pos:GetPos() end
    local angle = (pos - self:GetPos()):Angle()
    self:SetAngles(Angle(0, angle.y, 0))
  end
  function ENT:FaceTo(toface)
    while true do
      local pos = toface
      if isentity(pos) then
        if not IsValid(pos) then return end
        pos = pos:GetPos()
      end
      local angle = (pos - self:GetPos()):Angle()
      if math.NormalizeAngle(math.Round(self:GetAngles().y)) == math.NormalizeAngle(math.Round(angle.y)) then return end
      self:FaceTowards(pos)
      self:YieldCoroutine(true)
    end
  end
  function ENT:FaceEnemy()
    if self:HasEnemy() then self:FaceTowards(self:GetEnemy()) end
  end

  function ENT:MoveTowards(pos)
    if isentity(pos) then pos = pos:GetPos() end
    self:FaceTowards(pos)
    self:Approach(pos)
  end
  function ENT:MoveAwayFrom(pos, face)
    if isentity(pos) then pos = pos:GetPos() end
    local away = self:GetPos()*2 - pos
    if face then
      self:FaceTowards(pos)
      self:Approach(away)
    else self:MoveTowards(away) end
  end

  function ENT:MoveForward()
    self:Approach(self:GetPos() + self:GetForward())
  end
  function ENT:MoveBackward()
    self:Approach(self:GetPos() - self:GetForward())
  end
  function ENT:MoveRight()
    self:Approach(self:GetPos() + self:GetRight())
  end
  function ENT:MoveLeft()
    self:Approach(self:GetPos() - self:GetRight())
  end

  -- Coroutine --

  function ENT:FollowPath(pos, tolerance, generator)
    if isentity(pos) then pos = pos:GetPos() end
    tolerance = isnumber(tolerance) and tolerance or 20
    local selfpos = self:GetPos()
    if navmesh.IsLoaded() and self:GetGroundEntity():IsWorld() and
    navmesh.GetNearestNavArea(self:GetPos()):Contains(self:GetPos()) then
      pos = navmesh.GetNearestNavArea(pos):GetClosestPointOnArea(pos) or pos
      local path = self:GetPath()
      path:SetMinLookAheadDistance(300)
      path:SetGoalTolerance(tolerance)
      if IsValid(path) then
        local tol = (tolerance*(path:LastSegment().distanceFromStart-path:GetCurrentGoal().distanceFromStart))/100
        if tol < tolerance then tol = tolerance end
        if path:GetEnd():DistToSqr(pos) > tol^2 then
          path:Compute(self, pos, generator)
        end
      else path:Compute(self, pos, generator) end
      if not IsValid(path) then return "unreachable" end
      local ledge = self:FindLedge()
      local current = path:GetCurrentGoal()
      local ladder = current.ladder
      if current.type == 4 then
        if not self.ClimbLaddersUp then return "unreachable" end
        if self:GetHullRangeSquaredTo(ladder:GetBottom()) < self.LaddersUpDistance^2 then
          self:ClimbLadderUp(ladder)
          path:Invalidate()
          return "ladder_up", ladder
        elseif not self:AvoidObstacles(true) then
          self:MoveTowards(current.pos)
          return "moving", ladder
        else return "obstacle" end
      elseif current.type == 5 then
        if not self.ClimbLaddersDown then
          local drop = ladder:GetTop().z - ladder:GetBottom().z
          if drop <= self.loco:GetDeathDropHeight() then
            if not self:AvoidObstacles(true) then
              self:MoveTowards(self:GetPos() + current.forward)
              if self.loco:IsStuck() then
                self:HandleStuck()
                return "stuck", ladder
              else return "moving", ladder end
            else return "obstacles" end
          else return "unreachable" end
        elseif self:GetHullRangeSquaredTo(ladder:GetTop()) < self.LaddersDownDistance^2 then
          self:ClimbLadderDown(ladder)
          path:Invalidate()
          return "ladder_down", ladder
        elseif not self:AvoidObstacles(true) then
          self:MoveTowards(current.pos)
          if self.loco:IsStuck() then
            self:HandleStuck()
            return "stuck", ladder
          else return "moving", ladder end
        else return "obstacles" end
      elseif isvector(ledge) then
        self:ClimbLedge(ledge)
        path:Invalidate()
        return "ledge", ledge
      elseif not self._DrGBaseLastComputeSuccess and
      path:GetCurrentGoal().distanceFromStart == path:LastSegment().distanceFromStart then
        return "unreachable"
      elseif not self:AvoidObstacles(true) then
        path:Update(self)
        if not IsValid(path) then return "reached"
        elseif self.loco:IsStuck() then
          self:HandleStuck()
          return "stuck"
        else return "moving" end
      else return "obstacles" end
    else
      local ledge = self:FindLedge()
      if isvector(ledge) then
        self:ClimbLedge(ledge)
        return "ledge"
      elseif not self:AvoidObstacles(true) then
        if self:GetHullRangeSquaredTo(pos) > tolerance^2 then
          self:MoveTowards(pos)
          if self.loco:IsStuck() then
            self:HandleStuck()
            return "stuck"
          else return "moving" end
        else return "reached" end
      else return "obstacles" end
    end
  end

  function ENT:GoTo(pos, tolerance, generator)
    if isentity(pos) then pos = pos:GetPos() end
    while true do
      local res = self:FollowPath(pos, tolerance, generator)
      if res == "reached" then return true
      elseif res == "unreachable" then
        return false
      else self:YieldCoroutine(true) end
    end
  end

  function ENT:ChaseEntity(ent, tolerance, generator)
    if not isentity(ent) then return false end
    while IsValid(ent) do
      local res = self:FollowPath(pos, tolerance, generator)
      if res == "reached" then return true
      elseif res == "unreachable" then
        return false
      else self:YieldCoroutine(true) end
    end
    return false
  end

  -- Climbing --

  -- Ladders
  function ENT:ClimbLadder(ladder, down, callback)
    if self:IsClimbing() then return end
    local height = math.abs(ladder:GetTop().z - ladder:GetBottom().z)
    local res = self:OnStartClimbing(ladder, height, down)
    if res == false then return end
    self:SetNW2Bool("DrGBaseClimbing", true)
    self:SetNW2Bool("DrGBaseClimbingDown", down)
    self._DrGBaseClimbLadder = ladder
    if res ~= true then
      local offset = self:CalcOffset(self.ClimbOffset)*self:GetScale()
      offset.z = 0
      local lastHeight = self:GetPos().z
      local lastTime = CurTime()
      while not self:IsDying() do
        self:FaceTowards(self:GetPos() - ladder:GetNormal())
        local pos
        if down then
          pos = ladder:GetPosAtHeight(lastHeight - self:GetSpeed()*self:GetScale()*(CurTime()-lastTime))
          self:SetPos(pos + offset)
          if ladder:GetBottom().z - pos.z <= 0 then break end
          local remaining = (ladder:GetBottom().z - pos.z)/self:GetScale()
          if self:OnClimbing(ladder, remaining, true) then break end
          if isfunction(callback) and callback(self, ladder, remaining, true) then break end
        else
          pos = ladder:GetPosAtHeight(lastHeight + self:GetSpeed()*self:GetScale()*(CurTime()-lastTime))
          self:SetPos(pos + offset)
          if ladder:GetTop().z - pos.z <= 0 then break end
          local remaining = (ladder:GetTop().z - pos.z)/self:GetScale()
          if self:OnClimbing(ladder, remaining, false) then break end
          if isfunction(callback) and callback(self, ladder, remaining, false) then break end
        end
        lastHeight = pos.z
        lastTime = CurTime()
        self:YieldCoroutine(false)
      end
      local pos = self:GetPos()
      if down then
        self:OnStopClimbing(ladder, ladder:GetBottom().z - pos.z, true)
      else self:OnStopClimbing(ladder, ladder:GetTop().z - pos.z, false) end
    else self:CustomClimbing(ladder, height, down) end
    self:SetNW2Bool("DrGBaseClimbing", false)
    self._DrGBaseClimbLadder = nil
    self:SetVelocity(Vector(0, 0, 0))
  end
  function ENT:ClimbLadderUp(ladder)
    return self:ClimbLadder(ladder, false)
  end
  function ENT:ClimbLadderDown(ladder)
    return self:ClimbLadder(ladder, true)
  end

  -- Ledges
  local function IsEntityClimbable(self, ent)
    if not IsValid(ent) then return false end
    return ent:GetClass() == "func_lod" or
    (self.ClimbProps and ent:GetClass() == "prop_physics" and ent:IsOnGround())
  end
  function ENT:FindLedge()
    if not self.ClimbLedges then return end
    local normal = self:IsMoving() and self:GetVelocity() or self:GetForward()
    local hull = self:TraceHull(normal:GetNormalized()*self.LedgeDetectionDistance, {step = true})
    if not hull.Hit then return end
    --if IsValid(hull.Entity) then print(hull.Entity, hull.Entity:GetCollisionGroup(), IsValid(hull.Entity)) end
    if hull.HitWorld or IsEntityClimbable(self, hull.Entity) then
      local up = self:TraceHull(self:GetUp()*999999).HitPos
      local height = up.z - self:GetPos().z
      local i = 1
      local tr = {Hit = true, HitNonWorld = true}
      local precision = 5
      while true do
        if i*precision > height then return end
        tr = self:TraceHull(self:GetForward()*self.LedgeDetectionDistance*3, {
          start = self:GetPos() + Vector(0, 0, i*precision)
        })
        if not tr.Hit then break end
        if IsValid(tr.Entity) and not IsEntityClimbable(self, tr.Entity) then return end
        i = i+1
      end
      local tr2 = self:TraceHull(self:GetUp()*-999, {
        start = tr.HitPos
      })
      if tr2.HitPos.z - self:GetPos().z > self.ClimbLedgesMaxHeight then return end
      local trRad = self:TraceHullRadial(999, 360, {
        collisiongroup = COLLISION_GROUP_DEBRIS,
        maxs = Vector(0.5, 0.5, self:Height()),
        mins = Vector(-0.5, -0.5, self:GetStepHeight())
      })
      local pos = self:GetPos()
      local mins, maxs = self:GetCollisionBounds()
      mins.z = maxs.z
      local ledge = self:TraceLine(trRad[1].Normal*mins:Distance(maxs)/1.41, {
        collisiongroup = COLLISION_GROUP_DEBRIS,
        start = Vector(pos.x, pos.y, tr2.HitPos.z - 1)
      }).HitPos
      local height = ledge.z - self:GetPos().z
      if math.Clamp(height, self.ClimbLedgesMinHeight, self.ClimbLedgesMaxHeight) == height then
        return ledge
      end
    end
  end
  function ENT:ClimbLedge(ledge, callback)
    if self:IsClimbing() then return end
    local height = math.abs(ledge.z - self:GetPos().z)
    local res = self:OnStartClimbing(ledge, height, false)
    if res == false then return end
    self:SetNW2Bool("DrGBaseClimbing", true)
    self:SetNW2Bool("DrGBaseClimbingDown", false)
    if res ~= true then
      local offset = self:CalcOffset(self.ClimbOffset)*self:GetScale()
      offset.z = 0
      local lastPos = self:GetPos()
      local lastTime = CurTime()
      while not self:IsDying() do
        self:FaceTowards(ledge)
        if not self:TraceHull(self:GetForward()*self.LedgeDetectionDistance*2).Hit then
          self:SetNW2Bool("DrGBaseClimbing", false)
          self:SetVelocity(Vector(0, 0, 0))
          return
        end
        local pos = lastPos + lastPos:DrG_Direction(ledge):GetNormalized()*self:GetSpeed()*self:GetScale()*(CurTime()-lastTime)
        if pos.z > ledge.z then pos.z = ledge.z end
        self:SetPos(pos + offset)
        local remaining = math.abs(ledge.z - self:GetPos().z)/self:GetScale()
        if remaining == 0 then break end
        if self:OnClimbing(ledge, remaining, false) then break end
        if isfunction(callback) and callback(self, ledge, remaining, false) then break end
        lastPos = pos
        lastTime = CurTime()
        self:YieldCoroutine(false)
      end
      self:OnStopClimbing(ledge, math.abs(ledge.z - self:GetPos().z), false)
    else self:CustomClimbing(ledge, height, false) end
    self:SetNW2Bool("DrGBaseClimbing", false)
    self:SetVelocity(Vector(0, 0, 0))
  end

  function ENT:AvoidObstacles(forwardOnly)
    if not AvoidObstacles:GetBool() then return false end
    local hulls = self:CollisionHulls(nil, forwardOnly)
    if forwardOnly then
      if hulls.NorthWest.Hit and hulls.NorthEast.Hit then
        direction = "N"
        self:MoveBackward()
      elseif hulls.NorthWest.Hit then
        direction = "NW"
        self:MoveBackward()
        self:MoveRight()
      elseif hulls.NorthEast.Hit then
        direction = "NE"
        self:MoveBackward()
        self:MoveLeft()
      else return false end
      return true, direction
    else
      local nbHit = 0
      for k, tr in pairs(hulls) do
        if tr.Hit then nbHit = nbHit+1 end
      end
      if nbHit == 3 then
        if not hulls.NorthWest.Hit then
          direction = "SE"
          self:MoveForward()
          self:MoveLeft()
        elseif not hulls.NorthEast.Hit then
          direction = "SW"
          self:MoveForward()
          self:MoveRight()
        elseif not hulls.SouthEast.Hit then
          direction = "NW"
          self:MoveBackward()
          self:MoveRight()
        elseif not hulls.SouthWest.Hit then
          direction = "NE"
          self:MoveBackward()
          self:MoveLeft()
        end
      elseif nbHit == 2 then
        if hulls.NorthWest.Hit and hulls.NorthEast.Hit then
          direction = "N"
          self:MoveBackward()
        elseif hulls.NorthEast.Hit and hulls.SouthEast.Hit then
          direction = "E"
          self:MoveLeft()
        elseif hulls.SouthEast.Hit and hulls.SouthWest.Hit then
          direction = "S"
          self:MoveForward()
        elseif hulls.SouthWest.Hit and hulls.NorthWest.Hit then
          direction = "W"
          self:MoveRight()
        end
      elseif nbHit == 1 then
        if hulls.SouthEast.Hit then
          direction = "SE"
          self:MoveForward()
          self:MoveLeft()
        elseif hulls.SouthEast.Hit then
          direction = "SW"
          self:MoveForward()
          self:MoveRight()
        elseif hulls.NorthWest.Hit then
          direction = "NW"
          self:MoveBackward()
          self:MoveRight()
        elseif hulls.NorthEast.Hit then
          direction = "SE"
          self:MoveBackward()
          self:MoveLeft()
        end
      elseif nbHit == 0 then return false end
      return true, direction or "ALL"
    end
  end

  -- Update --

  function ENT:OnWalkframes()
    return self.UseWalkframes
  end

  function ENT:UpdateSpeed()
    if self:OnWalkframes(self:GetSequenceName(self:GetSequence())) then
      local speed = 0
      local seq = self:GetSequence()
      if self:IsClimbing() then
        local success, vec, angles = self:GetSequenceMovement(seq, 0, 1)
        if success then
          local height = vec.z
          local duration = self:SequenceDuration(seq)
          speed = height/duration
        end
      else speed = self:GetSequenceGroundSpeed(seq) end
      if speed ~= 0 then self.loco:SetDesiredSpeed(speed*MultSpeed:GetFloat())
      else self.loco:SetDesiredSpeed(1) end
    else
      local speed = self:OnUpdateSpeed()
      if isnumber(speed) then
        self:SetSpeed(math.Clamp(speed*MultSpeed:GetFloat(), 0, math.huge))
      end
    end
  end
  function ENT:OnUpdateSpeed()
    if self:IsClimbing() then return self.ClimbSpeed
    elseif self:IsRunning() then return self.RunSpeed
    else return self.WalkSpeed end
  end

  -- Hooks --

  function ENT:OnStartClimbing() end
  function ENT:OnClimbing(...)
    return self:WhileClimbing(...)
  end
  function ENT:WhileClimbing() end
  function ENT:OnStopClimbing() end
  function ENT:CustomClimbing() end

  function ENT:HandleStuck()
    self.loco:ClearStuck()
  end

  -- Handlers --

else

  -- Getters/setters --

  -- Functions --

  -- Hooks --

  -- Handlers --

end

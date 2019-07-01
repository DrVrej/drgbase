ENT.Base = "drgbase_entity"
ENT.IsDrGProjectile = true

-- Misc --
ENT.PrintName = "Projectile"
ENT.Category = "DrGBase"
ENT.Models = {}
ENT.ModelScale = 1

-- Physics --
ENT.Gravity = true
ENT.Physgun = false
ENT.Gravgun = false
ENT.Collisions = true

-- Contact --
ENT.OnContactDelay = 0
ENT.OnContactDelete = -1
ENT.OnContactDecals = {}

-- Sounds --
ENT.LoopSounds = {}
ENT.OnContactSounds = {}
ENT.OnRemoveSounds = {}

-- Effects --
ENT.AttachEffects = {}
ENT.OnContactEffects = {}
ENT.OnRemoveEffects = {}

-- Misc --
DrGBase.IncludeFile("meta.lua")

-- Handlers --

hook.Add("PhysgunPickup", "DrGBaseProjectilePhysgun", function(ply, ent)
  if ent.IsDrGProjectile then return ent.Physgun or false end
end)

if SERVER then
  AddCSLuaFile()

  function ENT:SpawnFunction(ply, tr, class)
    if not tr.Hit then return end
    local pos = tr.HitPos + tr.HitNormal*16
    local ent = ents.Create(class)
    ent:SetOwner(ply)
    ent:SetPos(pos)
    ent:Spawn()
    ent:Activate()
	  return ent
  end

  function ENT:Initialize()
    if #self.Models > 0 then
      self:SetModel(self.Models[math.random(#self.Models)])
    else
      self:SetModel("models/props_junk/watermelon01.mdl")
      self:SetNoDraw(true)
    end
    self:SetModelScale(self.ModelScale)
    self._DrGBaseFilterOwner = true
    self._DrGBaseFilterAllies = true
    self:SetUseType(SIMPLE_USE)
    -- sounds/effects --
    self:CallOnRemove("DrGBaseOnRemoveSoundsEffects", function(self)
      if #self.OnRemoveSounds > 0 then
        self:EmitSound(self.OnRemoveSounds[math.random(#self.OnRemoveSounds)])
      end
      if #self.OnRemoveEffects > 0 then
        ParticleEffect(self.OnRemoveEffects[math.random(#self.OnRemoveEffects)], self:GetPos(), self:GetAngles())
      end
    end)
    if #self.LoopSounds > 0 then
      self._DrGBaseLoopingSound = self:StartLoopingSound(self.LoopSounds[math.random(#self.LoopSounds)])
      self:CallOnRemove("DrGBaseStopLoopingSound", function(self)
        self:StopLoopingSound(self._DrGBaseLoopingSound)
      end)
    end
    if #self.AttachEffects > 0 then
      self:ParticleEffect(self.AttachEffects[math.random(#self.AttachEffects)], true)
    end
    -- physics --
    self:_BaseInitialize()
    self:CustomInitialize()
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetTrigger(true)
    if not self.Collisions then
      self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    end
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
      phys:Wake()
      phys:EnableDrag(false)
      phys:EnableGravity(tobool(self.Gravity))
    end
  end
  function ENT:_BaseInitialize() end
  function ENT:CustomInitialize() end

  function ENT:Think()
    self:_BaseThink()
    self:CustomThink()
  end
  function ENT:_BaseThink() end
  function ENT:CustomThink() end

  -- Collisions --

  local function Contact(self, ent)
    if not isnumber(self._DrGBaseLastContact) or CurTime() > self._DrGBaseLastContact + self.OnContactDelay then
      self._DrGBaseLastContact = CurTime()
      if #self.OnContactSounds > 0 then
        self:EmitSound(self.OnContactSounds[math.random(#self.OnContactSounds)])
      end
      if #self.OnContactEffects > 0 then
        ParticleEffect(self.OnContactEffects[math.random(#self.OnContactEffects)], self:GetPos(), self:GetAngles())
      end
      self:OnContact(ent)
      if self.OnContactDelete == 0 then
        self:Remove()
      elseif self.OnContactDelete > 0 then
        self:Timer(self.OnContactDelete, self.Remove)
      end
    end
  end

  function ENT:PhysicsCollide(data)
    if not data.HitEntity:IsWorld() then return end
    if not self:Filter(data.HitEntity) then return end
    if #self.OnContactDecals > 0 then
      util.Decal(self.OnContactDecals[math.random(#self.OnContactDecals)], data.HitPos+data.HitNormal, data.HitPos-data.HitNormal)
    end
    Contact(self, data.HitEntity)
  end
  function ENT:Touch(ent)
    if ent:IsWeapon() and IsValid(ent:GetOwner()) then
      local owner = ent:GetOwner()
      if not self:Filter(owner) then return end
      Contact(self, owner)
    elseif self:Filter(ent) then
      Contact(self, ent)
    end
  end
  function ENT:OnContact() end

  -- Filter --

  function ENT:Filter(ent)
    if not ent:IsWorld() and not IsValid(ent) then return false end
    local owner = self:GetOwner()
    if IsValid(owner) then
      if self:FilterOwner() and owner == ent then return false end
      if owner.IsDrGNextbot and self:FilterAllies() and owner:IsAlly(ent) then return false end
    end
    return self:OnFilter(ent) or false
  end
  function ENT:OnFilter(ent) return true end

  function ENT:FilterOwner(bool)
    if bool == nil then return self._DrGBaseFilterOwner
    else self._DrGBaseFilterOwner = tobool(bool) end
  end
  function ENT:FilterAllies(bool)
    if bool == nil then return self._DrGBaseFilterAllies
    else self._DrGBaseFilterAllies = tobool(bool) end
  end

  -- Helpers --

  function ENT:AimAt(target, speed, feet)
    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then return Vector(0, 0, 0) end
    if not phys:IsGravityEnabled() then
      if isentity(target) then
        local aimAt = feet and target:GetPos() or target:WorldSpaceCenter()
        local dist = self:GetPos():Distance(aimAt)
        return self:AimAt(aimAt + target:GetVelocity()*(dist/speed), speed, feet)
      else
        local vec = self:GetPos():DrG_Direction(target):GetNormalized()*speed
        phys:SetVelocity(vec)
        return vec
      end
    else
      return self:ThrowAt(target, {
        magnitude = speed, recursive = true, maxmagnitude = speed
      }, feet)
    end
  end
  function ENT:ThrowAt(target, options, feet)
    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then return Vector(0, 0, 0) end
    if isentity(target) then
      local aimAt = feet and target:GetPos() or target:WorldSpaceCenter()
      local vec, info = self:GetPos():DrG_CalcTrajectory(aimAt, options)
      return self:ThrowAt(aimAt + target:GetVelocity()*info.duration, options, feet)
    else return phys:DrG_Trajectory(target, options) end
  end

  function ENT:DealDamage(ent, value, type)
    local dmg = DamageInfo()
    dmg:SetDamage(value)
    dmg:SetDamageForce(self:GetVelocity())
    dmg:SetDamageType(type or DMG_DIRECT)
    if IsValid(self:GetOwner()) then
      dmg:SetAttacker(self:GetOwner())
    else dmg:SetAttacker(self) end
    dmg:SetInflictor(self)
    ent:TakeDamageInfo(dmg)
  end
  function ENT:RadiusDamage(value, type, range, filter)
    local owner = self:GetOwner()
    if not isfunction(filter) then filter = function(ent)
      if ent == owner then return false end
      if not IsValid(owner) or not owner.IsDrGNextbot then return true end
      return not owner:IsAlly(ent)
    end end
    for i, ent in ipairs(ents.FindInSphere(self:GetPos(), range)) do
      if not IsValid(ent) then continue end
      if not filter(ent) then continue end
      self:DealDamage(ent, value*math.Clamp((range-self:GetPos():Distance(ent:GetPos()))/range, 0, 1), type)
    end
  end

  function ENT:Explosion(damage, range, filter)
    local explosion = ents.Create("env_explosion")
    if IsValid(explosion) then
      explosion:Spawn()
      explosion:SetPos(self:GetPos())
      explosion:SetKeyValue("iMagnitude", 0)
      explosion:SetKeyValue("iRadiusOverride", 0)
      explosion:Fire("Explode", 0, 0)
    else
      local fx = EffectData()
      fx:SetOrigin(self:GetPos())
      util.Effect("Explosion", fx)
    end
    self:RadiusDamage(damage, DMG_BLAST, range, filter)
  end

  -- Handlers --

  hook.Add("GravGunPickupAllowed", "DrGBaseProjectileGravgun", function(ply, ent)
    if ent.IsDrGProjectile then return ent.Gravgun or false end
  end)

else

  function ENT:Initialize()
    if self._DrGBaseInitialized then return end
    self._DrGBaseInitialized = true
    self:_BaseInitialize()
    self:CustomInitialize()
  end
  function ENT:_BaseInitialize() end
  function ENT:CustomInitialize() end

  function ENT:Think()
    self:_BaseThink()
    self:CustomThink()
  end
  function ENT:_BaseThink() end
  function ENT:CustomThink() end

  function ENT:Draw()
    self:DrawModel()
    self:_BaseDraw()
    self:CustomDraw()
  end
  function ENT:_BaseDraw() end
  function ENT:CustomDraw() end

end

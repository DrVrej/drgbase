
function BT.HasEnemyOrRefresh()
  return function(self, data)
    if self:HasEnemy() then return true end
    return IsValid(self:RefreshEnemy())
  end
end

function BT.EnemyTooClose()
  return function(self, data)
    return self:IsInRange(self:GetEnemy(), self.EnemyTooClose)
  end
end
function BT.MoveAwayFromEnemy()
  return function(self, data)
    local res = self:OnAvoidEnemy(self:GetEnemy())
    if res == nil then
      self:MoveAwayFrom(self:GetEnemy(), true)
      return true
    else return res end
  end
end

function BT.EnemyTooFar()
  return function(self, data)
    local enemy = self:GetEnemy()
    return not self:IsInRange(enemy, self.EnemyTooFar) or not self:VisibleVec(enemy:WorldSpaceCenter())
  end
end
function BT.MoveCloserToEnemy()
  return function(self, data)
    local res = self:OnChaseEnemy(self:GetEnemy())
    if res == nil then
      return self:MoveCloserTo(self:GetEnemy()) ~= "unreachable"
    else return res end
  end
end

function BT.CheckAttackRange()
  return function(self, data)
    local enemy = self:GetEnemy()
    return self:IsInRange(enemy, self.AttackRange) and self:VisibleVec(enemy:WorldSpaceCenter())
  end
end

function BT.InAttackRange()
  return function(self, data)
    self:OnAttack(self:GetEnemy())
    return true
  end
end

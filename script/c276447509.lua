--Peropero Cerperus (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Battle damage
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_BATTLE_DAMAGE)
	e1:SetRange(LOCATION_GRAVE)
	e1:SetCondition(s.bcon)
	e1:SetCost(Cost.SelfBanish)
	e1:SetTarget(s.destg)
	e1:SetOperation(s.desop)
	c:RegisterEffect(e1)
	--Effect damage from a monster's effect
	local e2=e1:Clone()
	e2:SetCode(EVENT_DAMAGE)
	e2:SetProperty(EFFECT_FLAG_DELAY)
	e2:SetCondition(s.econ)
	c:RegisterEffect(e2)
end
function s.bcon(e,tp,eg,ep,ev,re,r,rp)
	if ep~=tp then return false end
	local a,d=Duel.GetAttacker(),Duel.GetAttackTarget()
	local mc=(a and a:IsControler(1-tp) and a) or (d and d:IsControler(1-tp) and d) or nil
	e:SetLabelObject(mc)
	return mc~=nil
end
function s.econ(e,tp,eg,ep,ev,re,r,rp)
	if ep~=tp or r&REASON_EFFECT==0 or not (re and re:IsMonsterEffect()) then return false end
	local rc=re:GetHandler()
	if not (rc:IsLocation(LOCATION_MZONE) and rc:IsControler(1-tp)) then return false end
	e:SetLabelObject(rc)
	return true
end
function s.destg(e,tp,eg,ep,ev,re,r,rp,chk)
	local mc=e:GetLabelObject()
	if chk==0 then return mc and mc:IsLocation(LOCATION_MZONE) and mc:IsControler(1-tp) end
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,mc,1,0,0)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local mc=e:GetLabelObject()
	if mc and mc:IsLocation(LOCATION_MZONE) and mc:IsControler(1-tp) then Duel.Destroy(mc,REASON_EFFECT) end
end

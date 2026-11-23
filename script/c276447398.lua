--D/D Count Surveyor (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	Pendulum.AddProcedure(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SET_ATTACK_FINAL)
	e1:SetRange(LOCATION_PZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetCondition(s.batcon)
	e1:SetTarget(s.battg)
	e1:SetValue(function(e) return Duel.GetMatchingGroup(Card.IsFaceup,e:GetHandlerPlayer(),0,LOCATION_MZONE,nil):GetSum(Card.GetBaseAttack) end)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_SET_DEFENSE_FINAL)
	e2:SetValue(function(e) return Duel.GetMatchingGroup(Card.IsFaceup,e:GetHandlerPlayer(),0,LOCATION_MZONE,nil):GetSum(Card.GetBaseDefense) end)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_DESTROY)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_BATTLED)
	e3:SetRange(LOCATION_PZONE)
	e3:SetCondition(s.descon)
	e3:SetOperation(s.desop)
	c:RegisterEffect(e3)
end
s.listed_series={SET_DD}
function s.pair(tp)
	local a,d=Duel.GetAttacker(),Duel.GetAttackTarget()
	if not a or not d then return nil end
	if a:IsControler(tp) then a,d=a,d else a,d=d,a end
	if a:IsControler(tp) and a:IsFaceup() and a:IsSetCard(SET_DD) and d:IsControler(1-tp) then return a,d end
	return nil
end
function s.batcon(e)
	local ph=Duel.GetCurrentPhase()
	return (ph==PHASE_DAMAGE or ph==PHASE_DAMAGE_CAL) and s.pair(e:GetHandlerPlayer())~=nil
end
function s.battg(e,c)
	local _,d=s.pair(e:GetHandlerPlayer())
	return c==d
end
function s.descon(e,tp,eg,ep,ev,re,r,rp)
	local _,d=s.pair(tp)
	return d and d:IsStatus(STATUS_BATTLE_DESTROYED)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local _,d=s.pair(tp)
	local g=Duel.GetMatchingGroup(aux.TRUE,tp,0,LOCATION_MZONE,d)
	if #g>0 then Duel.Destroy(g,REASON_EFFECT) end
end

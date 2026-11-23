--Shinato, King of a Higher Plane (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	c:EnableReviveLimit()
	--Halve the opponent's LP after destroying a Defense Position monster
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DAMAGE+CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCondition(s.hlcon)
	e1:SetOperation(s.hlop)
	c:RegisterEffect(e1)
	--Gain LP equal to the battle damage it inflicts
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_RECOVER)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_BATTLE_DAMAGE)
	e2:SetCondition(function(e,tp,eg,ep,ev,re,r,rp) return ep==1-tp end)
	e2:SetOperation(function(e,tp,eg,ep,ev,re,r,rp) Duel.Recover(tp,ev,REASON_EFFECT) end)
	c:RegisterEffect(e2)
end
s.listed_names={60365591}
function s.hlcon(e,tp,eg,ep,ev,re,r,rp)
	local bc=e:GetHandler():GetBattleTarget()
	return bc and bc:IsPreviousPosition(POS_DEFENSE) and bc:IsPreviousControler(1-tp)
end
function s.hlop(e,tp,eg,ep,ev,re,r,rp)
	local d=math.floor(Duel.GetLP(1-tp)/2)
	if d<=0 then return end
	local dmg=Duel.Damage(1-tp,d,REASON_EFFECT)
	if dmg>0 then Duel.Recover(tp,dmg,REASON_EFFECT) end
end

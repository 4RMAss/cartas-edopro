--魔性の月
--Mystical Moon (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	--Beast monsters (and, while "Umi" is on the field, Fish, Sea Serpent, Thunder and Aqua monsters)
	--gain ATK/DEF equal to 30% of their original ATK/DEF
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_UPDATE_ATTACK)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetTarget(s.target)
	e2:SetValue(s.atkval)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EFFECT_UPDATE_DEFENSE)
	e3:SetValue(s.defval)
	c:RegisterEffect(e3)
end
s.listed_names={CARD_UMI}
function s.target(e,c)
	if not c:IsFaceup() then return false end
	if c:IsRace(RACE_BEAST) then return true end
	return Duel.IsEnvironment(CARD_UMI) and c:IsRace(RACE_FISH|RACE_SEASERPENT|RACE_THUNDER|RACE_AQUA)
end
function s.atkval(e,c)
	return math.floor(c:GetBaseAttack()*3/10)
end
function s.defval(e,c)
	return math.floor(c:GetBaseDefense()*3/10)
end

--Performapal Card Gardna (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	Pendulum.AddProcedure(c)
	--Gains the DEF of all other "Performapal Card Gardna" on the field
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetCode(EFFECT_UPDATE_DEFENSE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCondition(function() return not s.busy end)
	e1:SetValue(s.defval)
	c:RegisterEffect(e1)
end
s.listed_names={37256334}
--While the sum is calculated this effect is not applied (each copy adds the DEF it has without it)
s.busy=false
function s.deffilter(c)
	return c:IsFaceup() and c:IsCode(37256334)
end
function s.defval(e,c)
	s.busy=true
	local v=Duel.GetMatchingGroup(s.deffilter,0,LOCATION_MZONE,LOCATION_MZONE,c):GetSum(Card.GetDefense)
	s.busy=false
	return v
end

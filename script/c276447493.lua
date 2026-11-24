--Sonata the Melodious Diva (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetCondition(function(e,c)
		if c==nil then return true end
		local tp=c:GetControler()
		return Duel.GetLocationCount(tp,LOCATION_MZONE)>0 and Duel.IsExistingMatchingCard(function(tc) return tc:IsFaceup() and tc:IsSetCard(SET_MELODIOUS) end,tp,LOCATION_MZONE,0,1,nil)
	end)
	c:RegisterEffect(e1)
end
s.listed_series={SET_MELODIOUS}

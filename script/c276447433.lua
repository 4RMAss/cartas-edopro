--Fluffal Bear (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetCode(EFFECT_FUSION_SUBSTITUTE)
	e1:SetValue(function(e,fc) return fc and fc:IsSetCard(SET_FRIGHTFUR) end)
	c:RegisterEffect(e1)
end
s.listed_series={SET_FRIGHTFUR}

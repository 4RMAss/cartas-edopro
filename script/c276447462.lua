--Elemental HERO Poison Rose (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	c:EnableUnsummonable()
	--Can only be Special Summoned with "Rose Bud"
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetCode(EFFECT_SPSUMMON_CONDITION)
	e0:SetValue(function(e,se) return se and se:GetHandler():IsCode(25090294) end)
	c:RegisterEffect(e0)
	--Your opponent's monsters can only attack this card
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_SELECT_BATTLE_TARGET)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetValue(function(e,c) return c~=e:GetHandler() end)
	c:RegisterEffect(e1)
end
s.listed_names={25090294}

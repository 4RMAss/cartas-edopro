--Horned Saurus (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	c:EnableReviveLimit()
	Fusion.AddProcMix(c,true,true,50834074,45894482)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_DIRECT_ATTACK)
	e1:SetCondition(function(e) local c=e:GetHandler() return c:IsSummonType(SUMMON_TYPE_FUSION) and c:IsStatus(STATUS_SPSUMMON_TURN) end)
	c:RegisterEffect(e1)
end
s.listed_names={50834074,45894482}

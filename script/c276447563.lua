--Sword of Dagla (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	aux.AddEquipProcedure(c)
	--The equipped monster gains 500 ATK
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(500)
	c:RegisterEffect(e1)
end

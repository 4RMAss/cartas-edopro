--超重武者タマ－C
--Superheavy Samurai Battleball (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en los scripts oficiales de Project Ignis (EDOPro), con licencia AGPL-3.0.
local s,id=GetID()
function s.initial_effect(c)
	--You can use 1 Machine monster your opponent controls as Synchro Material together with this card
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SYNCHRO_MATERIAL)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetTarget(s.mattg)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_SYNCHRO_MATERIAL_CUSTOM)
	e2:SetOperation(s.matcheck)
	c:RegisterEffect(e2)
end
function s.mattg(e,c)
	return c:IsFaceup() and c:IsRace(RACE_MACHINE)
end
--The opponent's Machine can only be used together with this card, and only 1 of them
function s.matcheck(e,tg,ntg,sg,lv,sc,tp)
	local p=e:GetHandlerPlayer()
	if tp~=p then return true,false end
	return sg:IsContains(e:GetHandler()) and sg:FilterCount(Card.IsControler,nil,1-p)<=1,false
end

--Script: 4RMAss · Anime Server by 4RMAss
--Pot of Jewels
--Hermana de "Spell Books from the Pot", pero el robo es solo para quien la activa.
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCategory(CATEGORY_DRAW)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsPlayerCanDraw(tp,4) end
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,4)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	Duel.Draw(tp,4,REASON_EFFECT)
end

--Stinging Swordsman (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_DAMAGE)
	e1:SetCondition(function(e,tp,eg,ep) return ep~=tp and Duel.GetAttackTarget()==nil end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		local g=Duel.GetMatchingGroup(Card.IsAbleToHand,tp,0,LOCATION_SZONE|LOCATION_FZONE,nil)
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,g,#g,0,0)
	end)
	e1:SetOperation(function(e,tp)
		local g=Duel.GetMatchingGroup(function(c) return c:IsSpellTrap() and c:IsAbleToHand() end,tp,0,LOCATION_ONFIELD,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
end

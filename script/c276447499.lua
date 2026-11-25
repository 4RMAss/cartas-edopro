--Ancient Lamp (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_ATTACK_ANNOUNCE)
	e1:SetCondition(function(e,tp) return Duel.GetAttacker():IsControler(1-tp) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local a=Duel.GetAttacker()
		if chk==0 then return a:IsRelateToBattle() end
		Duel.SetTargetCard(a)
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,math.max(a:GetAttack(),0))
	end)
	e1:SetOperation(function(e,tp)
		local a=Duel.GetAttacker()
		if Duel.NegateAttack() and a and a:IsRelateToBattle() and a:IsFaceup() then
			Duel.Damage(1-tp,math.max(a:GetAttack(),0),REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e1)
end

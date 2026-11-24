--Performage Damage Juggler (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DISABLE)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_CHAINING)
	e1:SetRange(LOCATION_HAND)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return re:IsMonsterEffect() and Duel.IsChainDisablable(ev)
			and (aux.damcon1(e,tp,eg,ep,ev,re,r,rp) or aux.damcon1(e,1-tp,eg,ep,ev,re,r,rp))
	end)
	e1:SetCost(Cost.SelfDiscard)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DISABLE,eg,1,0,0)
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if not Duel.NegateEffect(ev) then return end
		local rc=re:GetHandler()
		if rc:IsRelateToEffect(re) and rc:IsLocation(LOCATION_MZONE) and rc:IsFaceup() then
			rc:NegateEffects(e:GetHandler(),RESET_EVENT|RESETS_STANDARD)
		end
	end)
	c:RegisterEffect(e1)
end

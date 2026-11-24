--Carrierroid (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_REMOVE)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_CHAINING)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCondition(s.condition)
	e1:SetCost(s.cost)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
function s.tgfilter(c,tp)
	return c:IsControler(tp) and c:IsOnField() and c:IsSpellTrap()
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	if rp~=1-tp or not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) or not re:IsHasCategory(CATEGORY_DESTROY) then return false end
	local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	return g and g:IsExists(s.tgfilter,1,nil,tp)
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
	Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS):Filter(s.tgfilter,nil,tp)
	if chk==0 then return g:IsExists(Card.IsAbleToRemove,1,nil) end
	Duel.SetOperationInfo(0,CATEGORY_REMOVE,g,1,0,0)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS):Filter(s.tgfilter,nil,tp):Filter(Card.IsRelateToEffect,nil,re)
	if #g==0 then return end
	local tc=g:GetFirst()
	if #g>1 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
		tc=g:Select(tp,1,1,nil):GetFirst()
	end
	if Duel.Remove(tc,tc:GetPosition(),REASON_EFFECT|REASON_TEMPORARY)>0 then
		--while banished, the card keeps applying its effects as if it were still on the field
		if tc:IsFaceup() then s.keepeffects(tc) end
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
		e1:SetCountLimit(1)
		e1:SetLabel(Duel.GetTurnCount()+(Duel.IsTurnPlayer(tp) and 3 or 2))
		e1:SetLabelObject(tc)
		e1:SetCondition(function(e) return Duel.GetTurnCount()>=e:GetLabel() end)
		e1:SetOperation(function(e) Duel.ReturnToField(e:GetLabelObject()) e:Reset() end)
		Duel.RegisterEffect(e1,tp)
	end
end
function s.keepeffects(tc)
	for _,te in ipairs({tc:GetOwnEffects()}) do
		if te:GetOwner()==tc and not te:IsHasType(EFFECT_TYPE_ACTIVATE)
			and te:GetRange()&(LOCATION_ONFIELD|LOCATION_FZONE|LOCATION_PZONE)~=0 then
			local ce=te:Clone()
			ce:SetRange(LOCATION_REMOVED)
			ce:SetReset(RESET_EVENT|RESETS_STANDARD)
			tc:RegisterEffect(ce,true)
		end
	end
end

--リバース・オブ・リバース
--Reverse of Reverse (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script (oficial) de Project Ignis (EDOPro), con licencia AGPL-3.0.
local s,id=GetID()
function s.initial_effect(c)
	--Activate: activate 1 of your opponent's face-down Spells/Traps as if it were your own
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--You must control no other cards and have no cards in your hand
function s.alone(c,tp)
	if Duel.GetFieldGroupCount(tp,LOCATION_HAND,0)>0 then return false end
	return not Duel.IsExistingMatchingCard(aux.TRUE,tp,LOCATION_ONFIELD,0,1,c)
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return s.alone(e:GetHandler(),tp)
end
function s.filter(c)
	return c:IsFacedown() and c:GetSequence()<5
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_SZONE) and chkc:IsControler(1-tp) and s.filter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.filter,tp,0,LOCATION_SZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEDOWN)
	Duel.SelectTarget(tp,s.filter,tp,0,LOCATION_SZONE,1,1,nil)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not s.alone(c,tp) then return end
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) or not tc:IsFacedown() or not tc:IsControler(1-tp) then return end
	Duel.ConfirmCards(tp,tc)
	if not tc:IsSpellTrap() or tc:IsType(TYPE_FIELD) then return end
	local oseq=tc:GetSequence()
	--take it to your field, as if it were your own card
	if Duel.GetLocationCount(tp,LOCATION_SZONE)<=0
		or not Duel.MoveToField(tc,tp,tp,LOCATION_SZONE,POS_FACEDOWN,true) then return end
	local te=tc:GetActivateEffect()
	local condition,cost,target,operation
	if te then
		condition=te:GetCondition()
		cost=te:GetCost()
		target=te:GetTarget()
		operation=te:GetOperation()
	end
	local chk=te and te:GetCode()==EVENT_FREE_CHAIN and te:IsActivatable(tp)
		and (not condition or condition(te,tp,eg,ep,ev,re,r,rp))
		and (not cost or cost(te,tp,eg,ep,ev,re,r,rp,0))
		and (not target or target(te,tp,eg,ep,ev,re,r,rp,0))
	if not chk then
		--it cannot be activated at this time: return it face-down to its original zone
		Duel.MoveToField(tc,tp,1-tp,LOCATION_SZONE,POS_FACEDOWN,true,1<<oseq)
		return
	end
	Duel.ChangePosition(tc,POS_FACEUP)
	Duel.Hint(HINT_CARD,0,tc:GetOriginalCode())
	if not tc:IsType(TYPE_CONTINUOUS|TYPE_EQUIP) then
		tc:CancelToGrave(false)
	end
	tc:CreateEffectRelation(te)
	Duel.ClearTargetCard()
	local prop=e:GetProperty()
	e:SetProperty(te:GetProperty())
	if cost then cost(te,tp,eg,ep,ev,re,r,rp,1) end
	if target~=te:GetTarget() then target=te:GetTarget() end
	if target then target(te,tp,eg,ep,ev,re,r,rp,1) end
	local g=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
	if g then
		for tg in g:Iter() do tg:CreateEffectRelation(te) end
	end
	if tc:IsHasEffect(EFFECT_REMAIN_FIELD) then
		tc:SetStatus(STATUS_LEAVE_CONFIRMED,false)
	end
	if operation~=te:GetOperation() then operation=te:GetOperation() end
	if operation then operation(te,tp,eg,ep,ev,re,r,rp) end
	tc:ReleaseEffectRelation(te)
	if g then
		for tg in g:Iter() do tg:ReleaseEffectRelation(te) end
	end
	e:SetProperty(prop)
end

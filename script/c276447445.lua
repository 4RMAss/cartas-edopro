--Mystical Refpanel (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Activate: negate an opponent's Spell Card and seal it in this card
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DISABLE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--Apply the effect of the sealed Spell Card as your own, then send this card to the GY
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_FREE_CHAIN)
	e2:SetRange(LOCATION_SZONE)
	e2:SetHintTiming(TIMING_END_PHASE,TIMINGS_CHECK_MONSTER_E|TIMING_END_PHASE)
	e2:SetCondition(s.usecon)
	e2:SetTarget(s.usetg)
	e2:SetOperation(s.useop)
	c:RegisterEffect(e2)
end
s.sealed={}
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return rp==1-tp and re:IsHasType(EFFECT_TYPE_ACTIVATE) and re:IsSpellEffect() and Duel.IsChainDisablable(ev)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_DISABLE,eg,1,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not Duel.NegateEffect(ev) or not c:IsRelateToEffect(e) then return end
	local sc=re:GetHandler()
	--This card remains on the field with the Spell Card sealed in it
	c:CancelToGrave()
	s.sealed[c]=sc
	c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,EFFECT_FLAG_CLIENT_HINT,1,0,aux.Stringid(id,2))
	c:SetHint(CHINT_CARD,sc:GetOriginalCode())
end
function s.usecon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	return c:HasFlagEffect(id) and s.sealed[c]~=nil and not c:IsStatus(STATUS_CHAINING)
end
function s.usetg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local c=e:GetHandler()
	local sc=s.sealed[c]
	if chkc then
		local te=e:GetLabelObject()
		local tg=te and te:GetTarget()
		return tg~=nil and tg(e,tp,eg,ep,ev,re,r,rp,0,chkc)
	end
	if chk==0 then return sc~=nil and sc:CheckActivateEffect(false,true,false)~=nil end
	local te,ceg,cep,cev,cre,cr,crp=sc:CheckActivateEffect(false,true,true)
	Duel.ClearTargetCard()
	e:SetCategory(te:GetCategory())
	e:SetProperty(te:GetProperty())
	local tg=te:GetTarget()
	if tg then tg(e,tp,ceg,cep,cev,cre,cr,crp,1) end
	te:SetLabelObject(e:GetLabelObject())
	e:SetLabelObject(te)
end
function s.useop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local te=e:GetLabelObject()
	if te then
		e:SetLabelObject(te:GetLabelObject())
		local op=te:GetOperation()
		if op then op(e,tp,eg,ep,ev,re,r,rp) end
	end
	e:SetCategory(0)
	e:SetProperty(0)
	s.sealed[c]=nil
	c:ResetFlagEffect(id)
	if c:IsRelateToEffect(e) and c:IsOnField() then
		Duel.BreakEffect()
		Duel.SendtoGrave(c,REASON_EFFECT)
	end
end

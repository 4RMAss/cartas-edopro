--Odin's Eye (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DISABLE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.dbfilter(c)
	return c:IsFaceup() and c:IsRace(RACE_DIVINE)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.dbfilter,tp,LOCATION_MZONE,0,1,nil)
		and (Duel.GetFieldGroupCount(tp,0,LOCATION_HAND)>0 or Duel.IsExistingMatchingCard(Card.IsFacedown,tp,0,LOCATION_ONFIELD,1,nil)) end
	--cannot be negated while you control a face-up Divine-Beast monster
	local ch=Duel.GetCurrentChain()
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_INACTIVATE)
	e1:SetLabel(ch+1)
	e1:SetValue(function(e,ct) return ct==e:GetLabel() and Duel.IsExistingMatchingCard(s.dbfilter,e:GetHandlerPlayer(),LOCATION_MZONE,0,1,nil) end)
	e1:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e1,tp)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_CANNOT_DISEFFECT)
	Duel.RegisterEffect(e2,tp)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local g=Duel.GetMatchingGroup(s.dbfilter,tp,LOCATION_MZONE,0,nil)
	if #g==0 then return end
	for tc in g:Iter() do
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_DISABLE)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
		tc:RegisterEffect(e1)
		local e2=e1:Clone()
		e2:SetCode(EFFECT_DISABLE_EFFECT)
		tc:RegisterEffect(e2)
	end
	local hg=Duel.GetFieldGroup(tp,0,LOCATION_HAND)
	local sg=Duel.GetMatchingGroup(Card.IsFacedown,tp,0,LOCATION_ONFIELD,nil)
	local op=Duel.SelectEffect(tp,{#hg>0,aux.Stringid(id,0)},{#sg>0,aux.Stringid(id,1)})
	if op==1 then
		Duel.ConfirmCards(tp,hg)
		Duel.ShuffleHand(1-tp)
	elseif op==2 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_CONFIRM)
		local tc=sg:Select(tp,1,1,nil)
		Duel.ConfirmCards(tp,tc)
	end
end

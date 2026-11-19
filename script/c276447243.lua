--ナイトメア・シャッフル
--Nightmare Shuffle (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Activate: Set 1 random card from your GY in a Spell & Trap Zone adjacent to this card
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_LIMIT_ZONE)
	e1:SetValue(s.zones)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--During your Standby Phase: switch the Set card with 1 random card from your GY
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCountLimit(1)
	e2:SetCondition(s.swapcon)
	e2:SetOperation(s.swapop)
	c:RegisterEffect(e2)
	--When you activate the Set card: send this card to the GY
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_CHAINING)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCondition(s.sendcon)
	e3:SetOperation(s.sendop)
	c:RegisterEffect(e3)
end
--Zones where this card can be placed so that it has an unused adjacent Spell & Trap Zone
function s.zones(e,tp,eg,ep,ev,re,r,rp)
	local z=0
	for i=0,4 do
		if Duel.CheckLocation(tp,LOCATION_SZONE,i)
			and ((i>0 and Duel.CheckLocation(tp,LOCATION_SZONE,i-1)) or (i<4 and Duel.CheckLocation(tp,LOCATION_SZONE,i+1))) then
			z=z|(1<<i)
		end
	end
	return z
end
--Unused Spell & Trap Zones adjacent to this card (as a zone mask)
function s.adjzone(c,tp)
	if not c:IsLocation(LOCATION_SZONE) then return 0 end
	local seq=c:GetSequence()
	if seq>4 then return 0 end
	local z=0
	if seq>0 and Duel.CheckLocation(tp,LOCATION_SZONE,seq-1) then z=z|(1<<(seq-1)) end
	if seq<4 and Duel.CheckLocation(tp,LOCATION_SZONE,seq+1) then z=z|(1<<(seq+1)) end
	return z
end
--The card currently Set by this card's effect
function s.getset(c,tp)
	if not c:IsLocation(LOCATION_SZONE) then return nil end
	local fid=c:GetFieldID()
	return Duel.GetMatchingGroup(function(sc) return sc:IsFacedown() and sc:GetFlagEffectLabel(id)==fid end,
		tp,LOCATION_SZONE,0,nil):GetFirst()
end
--Set a card from the GY face-down in the given zone(s) and link it to this card
function s.place(c,tp,sc,zone)
	if zone==0 or not Duel.MoveToField(sc,tp,tp,LOCATION_SZONE,POS_FACEDOWN,true,zone) then return false end
	if sc:IsSpellTrap() then
		sc:SetStatus(STATUS_SET_TURN,true)
		Duel.RaiseEvent(sc,EVENT_SSET,nil,REASON_EFFECT,tp,tp,0)
	end
	sc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1,c:GetFieldID())
	return true
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then
		if Duel.GetFieldGroupCount(tp,LOCATION_GRAVE,0)==0 then return false end
		if c:IsLocation(LOCATION_SZONE) then return s.adjzone(c,tp)~=0 end
		return s.zones(e,tp)~=0
	end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	local zone=s.adjzone(c,tp)
	local g=Duel.GetFieldGroup(tp,LOCATION_GRAVE,0)
	if zone==0 or #g==0 then return end
	local sc=g:RandomSelect(tp,1):GetFirst()
	s.place(c,tp,sc,zone)
end
function s.swapcon(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsTurnPlayer(tp) and s.getset(e:GetHandler(),tp)~=nil
end
function s.swapop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) or c:IsFacedown() then return end
	local tc=s.getset(c,tp)
	local g=Duel.GetFieldGroup(tp,LOCATION_GRAVE,0)
	if not tc or #g==0 then return end
	local sc=g:RandomSelect(tp,1):GetFirst()
	local zone=1<<tc:GetSequence()
	if Duel.SendtoGrave(tc,REASON_EFFECT)==0 or not tc:IsLocation(LOCATION_GRAVE) then return end
	s.place(c,tp,sc,zone)
end
function s.sendcon(e,tp,eg,ep,ev,re,r,rp)
	local rc=re:GetHandler()
	return rp==tp and re:IsHasType(EFFECT_TYPE_ACTIVATE) and rc:GetFlagEffectLabel(id)==e:GetHandler():GetFieldID()
end
function s.sendop(e,tp,eg,ep,ev,re,r,rp)
	Duel.SendtoGrave(e:GetHandler(),REASON_EFFECT)
end

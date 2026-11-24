--Cursed Twin Dolls (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--LP gain
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_TO_GRAVE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e2:SetOperation(s.recop)
	c:RegisterEffect(e2)
	--The other player's Graveyard disappears: their cards cannot be sent to the Graveyard at all
	--(effects that would send them there, like milling the Deck, do nothing)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetProperty(EFFECT_FLAG_SET_AVAILABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e3:SetCode(EFFECT_CANNOT_TO_GRAVE)
	e3:SetRange(LOCATION_SZONE)
	e3:SetTargetRange(LOCATION_ALL,LOCATION_ALL)
	e3:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e3:SetTarget(s.nogytarget)
	c:RegisterEffect(e3)
	--If one of their cards is destroyed, it is banished instead of going to the Graveyard
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD)
	e4:SetProperty(EFFECT_FLAG_SET_AVAILABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e4:SetCode(EFFECT_TO_GRAVE_REDIRECT)
	e4:SetRange(LOCATION_SZONE)
	e4:SetTargetRange(LOCATION_ALL,LOCATION_ALL)
	e4:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e4:SetTarget(function(e,c) return s.nogytarget(e,c) and c:IsReason(REASON_DESTROY) end)
	e4:SetValue(LOCATION_REMOVED)
	c:RegisterEffect(e4)
end
--flag label = player who gains LP; the other player has no Graveyard
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	local op=Duel.SelectOption(1-tp,aux.Stringid(id,0),aux.Stringid(id,1))
	local gain=(op==0) and 1-tp or tp
	c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1,gain)
	--the player without Graveyard cannot send cards from the Deck to the Graveyard either (milling does nothing)
	local nogy=1-gain
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(EFFECT_CANNOT_DISCARD_DECK)
	e1:SetRange(LOCATION_SZONE)
	e1:SetTargetRange(nogy==tp and 1 or 0,nogy==tp and 0 or 1)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD)
	c:RegisterEffect(e1)
end
function s.recop(e,tp,eg,ep,ev,re,r,rp)
	local p=e:GetHandler():GetFlagEffectLabel(id)
	if p then Duel.Recover(p,#eg*200,REASON_EFFECT) end
end
function s.nogytarget(e,c)
	local p=e:GetHandler():GetFlagEffectLabel(id)
	return p and c:GetOwner()==1-p
end

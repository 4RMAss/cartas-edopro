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
	--The other player's Graveyard disappears
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetProperty(EFFECT_FLAG_SET_AVAILABLE+EFFECT_FLAG_IGNORE_RANGE+EFFECT_FLAG_IGNORE_IMMUNE)
	e3:SetCode(EFFECT_TO_GRAVE_REDIRECT)
	e3:SetRange(LOCATION_SZONE)
	e3:SetTargetRange(0xff,0xff)
	e3:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e3:SetTarget(s.rmtarget)
	e3:SetValue(LOCATION_REMOVED)
	c:RegisterEffect(e3)
end
--flag label = player who gains LP; the other player has no Graveyard
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	local op=Duel.SelectOption(1-tp,aux.Stringid(id,0),aux.Stringid(id,1))
	local gain=(op==0) and 1-tp or tp
	c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1,gain)
	local g=Duel.GetFieldGroup(1-gain,LOCATION_GRAVE,0)
	if #g>0 then Duel.Remove(g,POS_FACEUP,REASON_EFFECT) end
end
function s.recop(e,tp,eg,ep,ev,re,r,rp)
	local p=e:GetHandler():GetFlagEffectLabel(id)
	if p then Duel.Recover(p,#eg*200,REASON_EFFECT) end
end
function s.rmtarget(e,c)
	local p=e:GetHandler():GetFlagEffectLabel(id)
	return p and c:GetOwner()==1-p
end

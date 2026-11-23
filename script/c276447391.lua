--Contract Laundering (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DISABLE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(function() return Duel.GetFlagEffect(0,id)>0 end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	aux.GlobalCheck(s,function()
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_CHAINING)
		ge1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
			if re:IsHasType(EFFECT_TYPE_ACTIVATE) and re:GetHandler():IsSetCard(SET_DARK_CONTRACT) then
				Duel.RegisterFlagEffect(0,id,RESET_PHASE|PHASE_END,0,1)
			end
		end)
		Duel.RegisterEffect(ge1,0)
	end)
end
s.listed_series={SET_DARK_CONTRACT}
function s.filter(c)
	return c:IsFaceup() and c:IsSetCard(SET_DARK_CONTRACT)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_SZONE,0,1,nil) end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local g=Duel.GetMatchingGroup(s.filter,tp,LOCATION_SZONE,0,nil)
	if #g==0 then return end
	local fid=c:GetFieldID()
	for tc in g:Iter() do
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_DISABLE)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
		tc:RegisterEffect(e1)
		local e2=e1:Clone()
		e2:SetCode(EFFECT_DISABLE_EFFECT)
		tc:RegisterEffect(e2)
		tc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1,fid)
	end
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_PHASE+PHASE_END)
	e3:SetCountLimit(1)
	e3:SetLabel(fid)
	e3:SetOperation(s.desop)
	e3:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e3,tp)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetMatchingGroup(function(c) return c:GetFlagEffectLabel(id)==e:GetLabel() end,tp,LOCATION_SZONE,0,nil)
	if #g==0 then return end
	Duel.Hint(HINT_CARD,0,id)
	local ct=Duel.Destroy(g,REASON_EFFECT)
	if ct>0 then Duel.Draw(tp,ct,REASON_EFFECT) end
end

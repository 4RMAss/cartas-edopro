--Pendulum Match (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_ACTIVATE)
	e0:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e0)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetRange(LOCATION_SZONE)
	e1:SetCountLimit(1)
	e1:SetHintTiming(0,TIMINGS_CHECK_MONSTER|TIMING_MAIN_END)
	e1:SetCondition(function() return Duel.IsMainPhase() end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.exfilter,tp,LOCATION_EXTRA,0,1,nil,e,tp) end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_EXTRA)
	end)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
function s.exfilter(c,e,tp)
	return c:IsFaceup() and c:IsType(TYPE_PENDULUM) and c:IsCanBeSpecialSummoned(e,0,tp,false,false) and Duel.GetLocationCountFromEx(tp,tp,nil,c)>0
end
function s.dkfilter(c,e,p,sc)
	return c:IsType(TYPE_PENDULUM) and c:GetLeftScale()==sc and c:IsCanBeSpecialSummoned(e,0,p,false,false)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	local g=Duel.GetMatchingGroup(s.exfilter,tp,LOCATION_EXTRA,0,nil,e,tp)
	if #g==0 then return end
	local sc=g:RandomSelect(tp,1):GetFirst()
	local sg=Group.CreateGroup()
	if Duel.SpecialSummon(sc,0,tp,tp,false,false,POS_FACEUP)>0 then sg:AddCard(sc) end
	local p=1-tp
	local og=Duel.GetMatchingGroup(s.dkfilter,p,LOCATION_DECK,0,nil,e,p,sc:GetLeftScale())
	if #og>0 and Duel.GetLocationCount(p,LOCATION_MZONE)>0 and Duel.SelectYesNo(p,aux.Stringid(id,1)) then
		Duel.Hint(HINT_SELECTMSG,p,HINTMSG_SPSUMMON)
		local oc=og:Select(p,1,1,nil):GetFirst()
		if Duel.SpecialSummon(oc,0,p,p,false,false,POS_FACEUP)>0 then sg:AddCard(oc) end
	end
	if #sg==0 then return end
	for tc in sg:Iter() do tc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1) end
	sg:KeepAlive()
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e1:SetCountLimit(1)
	e1:SetOperation(function()
		local dg=sg:Filter(function(tc) return tc:GetFlagEffect(id)>0 end,nil)
		if #dg>0 then Duel.Hint(HINT_CARD,0,id) Duel.Destroy(dg,REASON_EFFECT) end
		sg:DeleteGroup()
	end)
	e1:SetReset(RESET_PHASE|PHASE_END,2)
	Duel.RegisterEffect(e1,tp)
end

--Mask Change (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOGRAVE+CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetHintTiming(0,TIMINGS_CHECK_MONSTER|TIMING_END_PHASE)
	
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_series={SET_HERO,SET_MASKED_HERO}
function s.tfilter(c,mc,e,tp)
	local lv=c:GetLevel()
	return c:IsSetCard(SET_MASKED_HERO) and c:IsAttribute(mc:GetAttribute()) and lv>mc:GetLevel() and lv<=mc:GetLevel()+2
		and Duel.GetLocationCountFromEx(tp,tp,mc,c)>0 and c:IsCanBeSpecialSummoned(e,0,tp,true,false)
end
function s.filter(c,e,tp)
	return c:IsFaceup() and c:IsSetCard(SET_HERO) and c:IsAbleToGrave()
		and Duel.IsExistingMatchingCard(s.tfilter,tp,LOCATION_EXTRA,0,1,nil,c,e,tp)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_MZONE,0,1,nil,e,tp) end
	Duel.SetOperationInfo(0,CATEGORY_TOGRAVE,nil,1,tp,LOCATION_MZONE)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_EXTRA)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local mc=Duel.SelectMatchingCard(tp,s.filter,tp,LOCATION_MZONE,0,1,1,nil,e,tp):GetFirst()
	if not mc then return end
	local att,lv=mc:GetAttribute(),mc:GetLevel()
	if Duel.SendtoGrave(mc,REASON_EFFECT)==0 or not mc:IsLocation(LOCATION_GRAVE) then return end
	local g=Duel.GetMatchingGroup(function(c)
		local l=c:GetLevel()
		return c:IsSetCard(SET_MASKED_HERO) and c:IsAttribute(att) and l>lv and l<=lv+2
			and Duel.GetLocationCountFromEx(tp,tp,nil,c)>0 and c:IsCanBeSpecialSummoned(e,0,tp,true,false)
	end,tp,LOCATION_EXTRA,0,nil)
	if #g==0 then return end
	Duel.BreakEffect()
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local sc=g:Select(tp,1,1,nil):GetFirst()
	if Duel.SpecialSummon(sc,0,tp,tp,true,false,POS_FACEUP)>0 then sc:CompleteProcedure() end
end

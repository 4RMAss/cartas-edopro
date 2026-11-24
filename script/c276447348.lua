--Toy Box (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_REMOVE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--Special Summon 1 stored monster
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_FREE_CHAIN)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCountLimit(1)
	e2:SetHintTiming(0,TIMING_END_PHASE|TIMINGS_CHECK_MONSTER)
	e2:SetTarget(s.sptg)
	e2:SetOperation(s.spop)
	c:RegisterEffect(e2)
	--Send to the GY when empty
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_ADJUST)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCondition(s.emptycon)
	e3:SetOperation(function(e) Duel.SendtoGrave(e:GetHandler(),REASON_EFFECT) end)
	c:RegisterEffect(e3)
end
s.listed_series={SET_TOY}
--"Toy" monsters: the "Toy" archetype plus every version of "Toy Soldier" (manga/anime ones have no archetype code)
local TOY_SOLDIERS={65504487,511000005,511002635,511600241}
function s.istoy(c)
	return c:IsSetCard(SET_TOY) or c:IsCode(table.unpack(TOY_SOLDIERS))
end
function s.rmfilter(c)
	return s.istoy(c) and c:IsMonster() and (c:IsLocation(LOCATION_HAND) or c:IsFaceup()) and c:IsAbleToRemove(c:GetControler(),POS_FACEDOWN)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.rmfilter,tp,LOCATION_HAND|LOCATION_MZONE,0,1,nil) end
	Duel.SetOperationInfo(0,CATEGORY_REMOVE,nil,1,tp,LOCATION_HAND|LOCATION_MZONE)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
	local g=Duel.SelectMatchingCard(tp,s.rmfilter,tp,LOCATION_HAND|LOCATION_MZONE,0,1,2,nil)
	if #g==0 then return end
	Duel.HintSelection(g:Filter(Card.IsOnField,nil))
	if Duel.Remove(g,POS_FACEDOWN,REASON_EFFECT)>0 then
		for tc in Duel.GetOperatedGroup():Iter() do
			tc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1,c:GetFieldID())
		end
		c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1)
	end
end
function s.stored(c,fid)
	return c:IsLocation(LOCATION_REMOVED) and c:GetFlagEffectLabel(id)==fid
end
function s.spfilter(c,e,tp,fid)
	return s.stored(c,fid) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.sptg(e,tp,eg,ep,ev,re,r,rp,chk)
	local fid=e:GetHandler():GetFieldID()
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_REMOVED,0,1,nil,e,tp,fid) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_REMOVED)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) or Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_REMOVED,0,1,1,nil,e,tp,c:GetFieldID())
	if #g>0 then Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP) end
end
function s.emptycon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	return c:GetFlagEffect(id)>0 and c:IsFaceup()
		and not Duel.IsExistingMatchingCard(s.stored,tp,LOCATION_REMOVED,0,1,nil,c:GetFieldID())
end

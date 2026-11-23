--Red-Eyes Transmigration (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_names={19025379,CARD_REDEYES_B_DRAGON}
function s.rfilter(c,e,tp)
	return c:IsCode(19025379) and c:IsCanBeSpecialSummoned(e,SUMMON_TYPE_RITUAL,tp,false,true)
end
function s.mfilter(c)
	return c:IsReleasableByEffect() and (c:IsCode(CARD_REDEYES_B_DRAGON) or c:IsRace(RACE_WARRIOR))
		and (c:IsLocation(LOCATION_HAND) or c:IsFaceup())
end
function s.matcheck(sg,e,tp,mg,rc)
	return sg:IsExists(Card.IsCode,1,nil,CARD_REDEYES_B_DRAGON) and sg:IsExists(Card.IsRace,1,nil,RACE_WARRIOR)
		and sg:IsExists(function(c) return c:IsCode(CARD_REDEYES_B_DRAGON) and sg:IsExists(Card.IsRace,1,c,RACE_WARRIOR) end,1,nil)
		and Duel.GetMZoneCount(tp,sg)>0
end
function s.matgroup(tp,rc)
	return Duel.GetMatchingGroup(s.mfilter,tp,LOCATION_HAND|LOCATION_MZONE,0,rc)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then
		local rg=Duel.GetMatchingGroup(s.rfilter,tp,LOCATION_HAND,0,nil,e,tp)
		for rc in rg:Iter() do
			if aux.SelectUnselectGroup(s.matgroup(tp,rc),e,tp,2,2,s.matcheck,0) then return true end
		end
		return false
	end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local rc=Duel.SelectMatchingCard(tp,function(c) return s.rfilter(c,e,tp) and aux.SelectUnselectGroup(s.matgroup(tp,c),e,tp,2,2,s.matcheck,0) end,tp,LOCATION_HAND,0,1,1,nil):GetFirst()
	if not rc then return end
	local mat=aux.SelectUnselectGroup(s.matgroup(tp,rc),e,tp,2,2,s.matcheck,1,tp,HINTMSG_RELEASE)
	if #mat<2 then return end
	rc:SetMaterial(mat)
	Duel.ReleaseRitualMaterial(mat)
	Duel.BreakEffect()
	Duel.SpecialSummon(rc,SUMMON_TYPE_RITUAL,tp,tp,false,true,POS_FACEUP)
	rc:CompleteProcedure()
end

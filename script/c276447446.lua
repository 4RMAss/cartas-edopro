--Magical Hats (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_POSITION+CATEGORY_SPECIAL_SUMMON+CATEGORY_TOKEN)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetHintTiming(0,TIMING_ATTACK|TIMING_BATTLE_START|TIMINGS_CHECK_MONSTER)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_series={SET_MAGICIAN,SET_DARK_MAGICIAN,SET_MAGICIAN_GIRL}
s.listed_names={276447447}
function s.magfilter(c)
	return c:IsFaceup() and (c:IsSetCard(SET_MAGICIAN) or c:IsSetCard(SET_DARK_MAGICIAN) or c:IsSetCard(SET_MAGICIAN_GIRL))
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsExistingMatchingCard(s.magfilter,tp,LOCATION_MZONE,0,1,nil)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_POSITION,Duel.GetMatchingGroup(Card.IsFaceup,tp,LOCATION_MZONE,0,nil),0,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local g=Duel.GetMatchingGroup(function(tc) return tc:IsFaceup() and tc:IsCanTurnSet() end,tp,LOCATION_MZONE,0,nil)
	if #g>0 then Duel.ChangePosition(g,POS_FACEDOWN_DEFENSE) end
	local fd=Duel.GetMatchingGroupCount(Card.IsFacedown,tp,LOCATION_MZONE,0,nil)
	local ct=math.min(4-fd,Duel.GetLocationCount(tp,LOCATION_MZONE))
	if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ct=math.min(ct,1) end
	if ct>0 and Duel.IsPlayerCanSpecialSummonMonster(tp,276447447,0,TYPES_TOKEN,0,0,1,RACE_SPELLCASTER,ATTRIBUTE_DARK,POS_FACEDOWN_DEFENSE) then
		for i=1,ct do
			local tk=Duel.CreateToken(tp,276447447)
			if Duel.SpecialSummonStep(tk,0,tp,tp,false,false,POS_FACEDOWN_DEFENSE) then
				--An empty hat that is targeted by a card effect is destroyed
				local e1=Effect.CreateEffect(c)
				e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
				e1:SetCode(EVENT_BECOME_TARGET)
				e1:SetOperation(function(ee) Duel.Destroy(ee:GetHandler(),REASON_EFFECT) end)
				e1:SetReset(RESET_EVENT|RESETS_STANDARD)
				tk:RegisterEffect(e1,true)
			end
		end
		Duel.SpecialSummonComplete()
	end
	local sg=Duel.GetMatchingGroup(Card.IsFacedown,tp,LOCATION_MZONE,0,nil)
	if #sg>1 then Duel.ShuffleSetCard(sg) end
end

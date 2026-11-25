--Tin Balloons (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOKEN)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return rp==1-tp and re:IsMonsterEffect() and re:GetHandler():IsType(TYPE_XYZ)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetLocationCount(1-tp,LOCATION_MZONE,tp)>0
			and Duel.IsPlayerCanSpecialSummonMonster(tp,276447518,0,TYPES_TOKEN,0,0,1,RACE_MACHINE,ATTRIBUTE_EARTH,POS_FACEUP,1-tp) end
		Duel.SetOperationInfo(0,CATEGORY_TOKEN,nil,1,0,0)
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,0,0)
	end)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_names={276447518}
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ct=Duel.GetLocationCount(1-tp,LOCATION_MZONE,tp)
	if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ct=math.min(ct,1) end
	if ct<=0 or not Duel.IsPlayerCanSpecialSummonMonster(tp,276447518,0,TYPES_TOKEN,0,0,1,RACE_MACHINE,ATTRIBUTE_EARTH,POS_FACEUP,1-tp) then return end
	local g=Group.CreateGroup()
	for i=1,ct do
		local tk=Duel.CreateToken(tp,276447518)
		if Duel.SpecialSummonStep(tk,0,tp,1-tp,false,false,POS_FACEUP) then g:AddCard(tk) end
	end
	Duel.SpecialSummonComplete()
	if #g==0 then return end
	g:KeepAlive()
	--End Phase: destroy the Tokens, then 1 Defense Position monster loses 500 DEF per Token destroyed
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_END)
	e1:SetCountLimit(1)
	e1:SetOperation(function()
		local tg=g:Filter(Card.IsOnField,nil)
		Duel.Hint(HINT_CARD,0,id)
		local n=Duel.Destroy(tg,REASON_EFFECT)
		local dg=Duel.GetMatchingGroup(Card.IsDefensePos,tp,0,LOCATION_MZONE,nil)
		if n>0 and #dg>0 then
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
			local tc=dg:Select(tp,1,1,nil):GetFirst()
			local e2=Effect.CreateEffect(c)
			e2:SetType(EFFECT_TYPE_SINGLE)
			e2:SetCode(EFFECT_UPDATE_DEFENSE)
			e2:SetValue(-500*n)
			e2:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END|RESET_OPPO_TURN,Duel.IsTurnPlayer(tp) and 2 or 1)
			tc:RegisterEffect(e2)
		end
		g:DeleteGroup()
	end)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
end

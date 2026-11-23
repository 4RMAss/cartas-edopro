--Multiplication of Ants (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOKEN)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(function(e,tp) return Duel.IsExistingMatchingCard(s.antfilter,tp,LOCATION_MZONE,0,1,nil) end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_names={511002428,22493812}
function s.antfilter(c)
	return c:IsFaceup() and c:IsAttackPos() and c:IsCode(511002428)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsPlayerCanSpecialSummonMonster(tp,22493812,0,TYPES_TOKEN,500,1200,4,RACE_INSECT,ATTRIBUTE_EARTH) end
	Duel.SetOperationInfo(0,CATEGORY_TOKEN,nil,1,0,0)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ct=math.min(10,Duel.GetLocationCount(tp,LOCATION_MZONE))
	if ct<=0 or not Duel.IsPlayerCanSpecialSummonMonster(tp,22493812,0,TYPES_TOKEN,500,1200,4,RACE_INSECT,ATTRIBUTE_EARTH) then return end
	if ct>1 and Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ct=1 end
	local g=Group.CreateGroup()
	for i=1,ct do
		local token=Duel.CreateToken(tp,22493812)
		if Duel.SpecialSummonStep(token,0,tp,tp,false,false,POS_FACEUP_ATTACK) then
			local e1=Effect.CreateEffect(c)
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(EFFECT_CANNOT_ATTACK)
			e1:SetReset(RESET_EVENT|RESETS_STANDARD)
			token:RegisterEffect(e1,true)
			g:AddCard(token)
		end
	end
	Duel.SpecialSummonComplete()
	if #g==0 then return end
	g:KeepAlive()
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_PHASE+PHASE_END)
	e2:SetCountLimit(1)
	e2:SetLabelObject(g)
	e2:SetOperation(function(e)
		local tg=e:GetLabelObject():Filter(Card.IsOnField,nil)
		if #tg>0 then Duel.SendtoGrave(tg,REASON_EFFECT) end
		e:GetLabelObject():DeleteGroup()
		e:Reset()
	end)
	Duel.RegisterEffect(e2,tp)
end

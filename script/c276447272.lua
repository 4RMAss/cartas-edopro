--Counterattack! (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetHintTiming(0,TIMING_BATTLE_PHASE|TIMING_BATTLE_END)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	aux.GlobalCheck(s,function()
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_BATTLED)
		ge1:SetOperation(s.checkop)
		Duel.RegisterEffect(ge1,0)
	end)
end
function s.checkop(e,tp,eg,ep,ev,re,r,rp)
	local d=Duel.GetAttackTarget()
	if d then Duel.RegisterFlagEffect(d:GetControler(),id,RESET_PHASE|PHASE_END,0,1) end
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsTurnPlayer(1-tp) and Duel.IsBattlePhase() and Duel.GetFlagEffect(tp,id)>0
		and not Duel.IsDamageStep()
end
--A battle needs at least one Attack Position monster: a Defense Position monster uses its DEF
function s.ofilter(c,a)
	return c:IsFaceup() and (a:IsAttackPos() or c:IsAttackPos())
end
function s.mfilter(c,tp)
	return c:IsFaceup() and Duel.IsExistingMatchingCard(s.ofilter,tp,0,LOCATION_MZONE,1,nil,c)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.mfilter,tp,LOCATION_MZONE,0,1,nil,tp) end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	local a=Duel.SelectMatchingCard(tp,s.mfilter,tp,LOCATION_MZONE,0,1,1,nil,tp):GetFirst()
	if not a then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	local d=Duel.SelectMatchingCard(tp,s.ofilter,tp,0,LOCATION_MZONE,1,1,nil,a):GetFirst()
	if not d then return end
	Duel.HintSelection(Group.FromCards(a,d))
	if a:IsAttackPos() then
		--your monster attacks: against a Defense Position monster its DEF is used
		Duel.CalculateDamage(a,d)
	else
		--your monster is in Defense Position: the opponent's monster battles into its DEF
		Duel.CalculateDamage(d,a)
	end
end

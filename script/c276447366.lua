--Nordic Relic Brisingamen (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_DAMAGE_STEP)
	e1:SetHintTiming(TIMING_DAMAGE_STEP,TIMING_DAMAGE_STEP|TIMING_END_PHASE)
	e1:SetCondition(aux.StatChangeDamageStepCondition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return false end
	if chk==0 then return Duel.IsExistingTarget(Card.IsFaceup,tp,LOCATION_MZONE,0,1,nil)
		and Duel.IsExistingTarget(Card.IsFaceup,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	local g=Duel.SelectTarget(tp,Card.IsFaceup,tp,LOCATION_MZONE,0,1,1,nil)
	e:SetLabelObject(g:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,Card.IsFaceup,tp,0,LOCATION_MZONE,1,1,nil)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=e:GetLabelObject()
	local g=Duel.GetTargetCards(e)
	local oc=g:Filter(aux.TRUE,tc):GetFirst()
	if not (tc and oc and g:IsContains(tc)) or tc:IsFacedown() or oc:IsFacedown() then return end
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_SET_ATTACK_FINAL)
	e1:SetValue(oc:GetBaseAttack())
	e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
	tc:RegisterEffect(e1)
	--If your selected monster destroys an opponent's monster by battle and sends it to the GY this turn:
	--inflict damage equal to its ATK (also when your monster is destroyed in that same battle)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_BATTLE_DESTROYED)
	e2:SetLabelObject(tc)
	e2:SetOperation(s.damop)
	e2:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e2,tp)
end
function s.damfilter(c,tc,tp)
	return c:GetReasonCard()==tc and c:IsLocation(LOCATION_GRAVE) and c:IsPreviousControler(1-tp)
end
function s.damop(e,tp,eg,ep,ev,re,r,rp)
	local g=eg:Filter(s.damfilter,nil,e:GetLabelObject(),tp)
	local dmg=0
	for bc in g:Iter() do dmg=dmg+math.max(bc:GetPreviousAttackOnField(),0) end
	if dmg>0 then
		Duel.Hint(HINT_CARD,0,id)
		Duel.Damage(1-tp,dmg,REASON_EFFECT)
	end
end

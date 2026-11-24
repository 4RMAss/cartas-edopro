--Last Counter (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_BATTLE_DESTROYED)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCondition(function(e,tp,eg) return eg:IsExists(Card.IsPreviousControler,1,nil,tp) end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_series={SET_NUMBER}
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local dc=eg:Filter(Card.IsPreviousControler,nil,tp):GetFirst()
	local bc=dc and dc:GetReasonCard()
	if chkc then return chkc==bc end
	if chk==0 then return bc and bc:IsControler(1-tp) and bc:IsLocation(LOCATION_MZONE) and bc:IsFaceup() and bc:IsCanBeEffectTarget(e) end
	Duel.SetTargetCard(bc)
	Duel.SetOperationInfo(0,CATEGORY_ATKCHANGE,bc,1,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	local prev=tc:GetAttack()
	local base=tc:GetBaseAttack()
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_SET_ATTACK_FINAL)
	e1:SetValue(0)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
	tc:RegisterEffect(e1)
	local g=Duel.GetMatchingGroup(function(nc) return nc:IsFaceup() and nc:IsSetCard(SET_NUMBER) end,tp,LOCATION_MZONE,0,nil)
	if #g>0 and prev>0 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
		local nc=g:Select(tp,1,1,nil):GetFirst()
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_UPDATE_ATTACK)
		e2:SetValue(prev)
		e2:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
		nc:RegisterEffect(e2)
	end
	--Remember whether that monster is destroyed during this Battle Phase
	local destroyed=false
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_DESTROYED)
	e3:SetOperation(function(_,_,deg) if Duel.IsBattlePhase() and deg:IsContains(tc) then destroyed=true end end)
	e3:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e3,tp)
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e4:SetCountLimit(1)
	e4:SetOperation(function()
		if destroyed then
			Duel.Hint(HINT_CARD,0,id)
			Duel.Damage(tp,base,REASON_EFFECT)
		end
	end)
	e4:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e4,tp)
end

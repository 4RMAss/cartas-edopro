--Performapal Seal Eel (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	Pendulum.AddProcedure(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DISABLE+CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_PZONE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsNegatableMonster() end
		if chk==0 then return Duel.IsExistingTarget(Card.IsNegatableMonster,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_NEGATE)
		local g=Duel.SelectTarget(tp,Card.IsNegatableMonster,tp,LOCATION_MZONE,LOCATION_MZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_DISABLE,g,1,0,0)
	end)
	e1:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup() and not tc:IsDisabled()) then return end
		Duel.NegateRelatedChain(tc,RESET_TURN_SET)
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_DISABLE)
		e1:SetReset(RESETS_STANDARD_PHASE_END)
		tc:RegisterEffect(e1)
		local e2=e1:Clone()
		e2:SetCode(EFFECT_DISABLE_EFFECT)
		e2:SetValue(RESET_TURN_SET)
		tc:RegisterEffect(e2)
		Duel.AdjustInstantly(tc)
		if tc:IsDisabled() then
			local fe=tc:GetFlagEffectLabel(id+tp)
			if fe and fe>0 then Duel.Recover(tp,fe,REASON_EFFECT) end
		end
	end)
	c:RegisterEffect(e1)
	--Remember the effect damage each monster inflicted to each player this turn
	aux.GlobalCheck(s,function()
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_DAMAGE)
		ge1:SetOperation(s.record)
		Duel.RegisterEffect(ge1,0)
	end)
end
function s.record(e,tp,eg,ep,ev,re,r,rp)
	if r&REASON_EFFECT==0 or not re then return end
	local rc=re:GetHandler()
	if not (rc and rc:IsLocation(LOCATION_MZONE)) then return end
	local cur=rc:GetFlagEffectLabel(id+ep)
	if cur then rc:SetFlagEffectLabel(id+ep,cur+ev)
	else rc:RegisterFlagEffect(id+ep,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1,ev) end
end

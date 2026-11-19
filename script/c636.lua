--Script: 4RMAss · Anime Server by 4RMAss
--パワー・コンバーター
--equipo con el patron clasico oficial (inline, sin depender de proc_equip)
local function LocalEquipProc(c,p,f,eqlimit,cost,tg,op,con,prop)
	local function eqfilter(tc,e,tp,player)
		return tc:IsFaceup() and (player==nil or tc:IsControler(player))
			and (not f or f(tc,e,tp))
	end
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_EQUIP)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	if not EFFECT_FLAG_CONTINUOUS_TARGET then EFFECT_FLAG_CONTINUOUS_TARGET=0 end
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_CONTINUOUS_TARGET+(prop or 0))
	if con then e1:SetCondition(con) end
	if cost then e1:SetCost(cost) end
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		local player=nil
		if p==0 then player=tp elseif p==1 then player=1-tp end
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and eqfilter(chkc,e,tp,player) end
		if chk==0 then
			return Duel.IsExistingTarget(function(tc) return eqfilter(tc,e,tp,player) end,
				tp,LOCATION_MZONE,LOCATION_MZONE,1,nil)
		end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_EQUIP)
		local g=Duel.SelectTarget(tp,function(tc) return eqfilter(tc,e,tp,player) end,
			tp,LOCATION_MZONE,LOCATION_MZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_EQUIP,e:GetHandler(),1,0,0)
		if tg then tg(e,tp,eg,ep,ev,re,r,rp,g and g:GetFirst()) end
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		local ec=e:GetHandler()
		local tc=Duel.GetFirstTarget()
		if ec:IsRelateToEffect(e) and tc and tc:IsRelateToEffect(e) and tc:IsFaceup() then
			Duel.Equip(tp,ec,tc)
		end
		if op then op(e,tp,eg,ep,ev,re,r,rp) end
	end)
	c:RegisterEffect(e1)
	--limite de equipo
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_EQUIP_LIMIT)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	if eqlimit~=nil then
		e2:SetValue(eqlimit)
	elseif f then
		e2:SetValue(function(e,tc) return f(tc,e,e:GetHandlerPlayer()) end)
	else
		e2:SetValue(1)
	end
	c:RegisterEffect(e2)
	return e1
end
function c636.initial_effect(c)
	LocalEquipProc(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(636,0))
	e1:SetCategory(CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetRange(LOCATION_SZONE)
	e1:SetCondition(c636.lpcon)
	e1:SetCost(c636.lpcost)
	e1:SetOperation(c636.lpop)
	c:RegisterEffect(e1)
end
function c636.lpcon(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetCurrentPhase()~=PHASE_DAMAGE or not Duel.IsDamageCalculated()
end
function c636.lpcost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return e:GetHandler():IsAbleToGraveAsCost() end
	Duel.SendtoGrave(e:GetHandler(),REASON_COST)
end
function c636.lpop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ec=c:GetPreviousEquipTarget()
	local lp=ec:GetAttack()
	if Duel.Recover(tp,lp,REASON_EFFECT)>0 then
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(0)
		e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
		ec:RegisterEffect(e1)
	end
end

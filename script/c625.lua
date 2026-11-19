--Script: 4RMAss · Anime Server by 4RMAss
--ストイック・チャレンジ
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
function c625.eqlimit(e,c)
	return e:GetLabelObject()==c
end
function c625.damval(e,re,dam,r,rp,rc)
	if bit.band(r,REASON_BATTLE)~=0 and rc==e:GetHandler():GetEquipTarget() and rc:GetBattleTarget()~=nil then
		return dam*2
	else return dam end
end
function c625.detop(e,tp,eg,ep,ev,re,r,rp)
	if Duel.GetTurnPlayer()==1-tp then return end
	local c=e:GetHandler()
	local tc=c:GetEquipTarget()
	local ct=c:GetTurnCounter()
	ct=ct+1
	c:SetTurnCounter(ct)
	if ct==2 then
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
		e1:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
		e1:SetCode(EVENT_PHASE+PHASE_END)
		e1:SetCountLimit(1)
		e1:SetRange(LOCATION_SZONE)
		e1:SetLabelObject(tc)
		e1:SetOperation(c625.desop)
		e1:SetReset(RESET_PHASE+PHASE_END+RESET_SELF_TURN,1)
		Duel.RegisterEffect(e1,tp)
	end
end
function c625.desop(e,tp,eg,ep,ev,re,r,rp)
	local tc=e:GetLabelObject()
	Duel.Hint(HINT_CARD,0,625)
		Duel.Destroy(tc,REASON_EFFECT)
end
function c625.initial_effect(c)
	LocalEquipProc(c,nil,c625.eqfilter,nil,nil,nil,c625.eqoperation)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(625,0))
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(c625.condition)
	e1:SetTarget(c625.target)
	e1:SetOperation(c625.activate)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CHANGE_DAMAGE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e2:SetTargetRange(0,1)
	e2:SetValue(c625.damval)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_EQUIP)
	e3:SetCode(EFFECT_CANNOT_TRIGGER)
	c:RegisterEffect(e3)
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(625,1))
	e4:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_PHASE+PHASE_END)
	e4:SetRange(LOCATION_SZONE)
	e4:SetCountLimit(1)
	e4:SetOperation(c625.detop)
	c:RegisterEffect(e4)
end
function c625.eqfilter(c,e,tp)
	return c:IsFaceup() and c:IsType(TYPE_XYZ) and c:GetControler()==tp
end
function c625.eqoperation(e,tp,eg,ep,ev,re,r,rp)
	e:GetHandler():SetTurnCounter(0)
end
function c625.filter(c)
	return c:IsFaceup() and c:IsType(TYPE_XYZ) and c:GetOverlayCount()>0
end
function c625.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsExistingMatchingCard(c625.filter,e:GetHandlerPlayer(),LOCATION_ONFIELD,0,1,nil)
end
function c625.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_ONFIELD) and chkc:IsControler(tp) and c625.filter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(c625.filter,tp,LOCATION_ONFIELD,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,c625.filter,tp,LOCATION_ONFIELD,0,1,1,nil)
end
function c625.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	e:GetHandler():SetTurnCounter(0)
	if tc:IsRelateToEffect(e) and tc:IsFaceup() then
		local ct=tc:GetOverlayCount()
		tc:RemoveOverlayCard(tp,ct,ct,REASON_EFFECT)
		Duel.Equip(tp,c,tc)
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_EQUIP_LIMIT)
		e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
		e1:SetReset(RESET_EVENT+RESETS_STANDARD)
		e1:SetValue(c625.eqlimit)
		e1:SetLabelObject(tc)
		c:RegisterEffect(e1)
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_EQUIP)
		e2:SetCode(EFFECT_UPDATE_ATTACK)
		e2:SetRange(LOCATION_SZONE)
		e2:SetValue(ct*600)
		e2:SetReset(RESET_EVENT+RESETS_STANDARD)
		c:RegisterEffect(e2)
		local e3=Effect.CreateEffect(c)
		e3:SetType(EFFECT_TYPE_EQUIP)
		e3:SetCode(EFFECT_DISABLE)
		e3:SetRange(LOCATION_SZONE)
		c:RegisterEffect(e3)
	end
end

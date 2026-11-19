--Script: 4RMAss · Anime Server by 4RMAss
--D/D Savant Einstein
--ディーディーまどうけんじゃアルベルト
local s,id=GetID()
function s.initial_effect(c)
	--Pendulum
	Pendulum.AddProcedure(c)
	--[Efecto de Pendulo] Una vez por turno: selecciona 1 carta en cualquier Zona de Pendulo;
	--devuelvela a la mano, y no se puede colocar en la Zona de Pendulo el resto del turno.
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(1105) --system string de EDOPro: "Send to Hand"
	e1:SetCategory(CATEGORY_TOHAND)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_PZONE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCountLimit(1,id)
	e1:SetTarget(s.thtg)
	e1:SetOperation(s.thop)
	c:RegisterEffect(e1)
	--[Efecto de Monstruo] Cuando un monstruo del adversario declara un ataque: puedes mandar
	--esta carta de tu mano al Cementerio; Coloca 1 Magia/Trampa de tu mano, activable este turno.
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(1159) --system string de EDOPro: "S/T Set"
	--FIELD, no SINGLE: con SINGLE el motor exige que el evento afecte a la propia carta,
	--y estando en la mano nunca se cumple. Es el patron de Battle Fader.
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_ATTACK_ANNOUNCE)
	e2:SetRange(LOCATION_HAND)
	e2:SetCondition(s.setcon)
	e2:SetCost(s.setcost)
	e2:SetTarget(s.settg)
	e2:SetOperation(s.setop)
	c:RegisterEffect(e2)
end
--== Efecto de Pendulo ==--
function s.thfilter(c)
	return c:IsAbleToHand()
end
function s.thtg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_PZONE) and s.thfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.thfilter,tp,LOCATION_PZONE,LOCATION_PZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
	local g=Duel.SelectTarget(tp,s.thfilter,tp,LOCATION_PZONE,LOCATION_PZONE,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,g,1,0,0)
end
function s.thop(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) then return end
	if Duel.SendtoHand(tc,nil,REASON_EFFECT)==0 then return end
	--"no se puede colocar en la Zona de Pendulo el resto del turno, aunque esta carta deje el campo":
	--colocar un Pendulo en su Zona es una activacion, asi que se le bloquea la activacion.
	--El efecto se registra en el duelo, no en esta carta, para que sobreviva si ella se va.
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_ACTIVATE)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetTargetRange(1,1)
	e1:SetLabelObject(tc)
	e1:SetValue(s.aclimit)
	e1:SetReset(RESET_PHASE+PHASE_END)
	Duel.RegisterEffect(e1,tp)
end
function s.aclimit(e,re,tp)
	return re:GetHandler()==e:GetLabelObject()
end
--== Efecto de Monstruo ==--
function s.setcon(e,tp,eg,ep,ev,re,r,rp)
	local a=Duel.GetAttacker()
	return a and a:IsControler(1-tp)
end
function s.setcost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return e:GetHandler():IsAbleToGraveAsCost() end
	Duel.SendtoGrave(e:GetHandler(),REASON_COST)
end
function s.setfilter(c)
	return c:IsSSetable()
end
function s.settg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.setfilter,tp,LOCATION_HAND,0,1,nil) end
end
function s.setop(e,tp,eg,ep,ev,re,r,rp)
	if Duel.GetLocationCount(tp,LOCATION_SZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SET)
	local g=Duel.SelectMatchingCard(tp,s.setfilter,tp,LOCATION_HAND,0,1,1,nil)
	local tc=g:GetFirst()
	if not tc then return end
	if Duel.SSet(tp,tc)==0 then return end
	--"esa carta Colocada se puede activar este turno"
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SET_AVAILABLE)
	if tc:IsTrap() then
		e1:SetCode(EFFECT_TRAP_ACT_IN_SET_TURN)
	else
		e1:SetCode(EFFECT_QP_ACT_IN_SET_TURN)
	end
	e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
	tc:RegisterEffect(e1)
end

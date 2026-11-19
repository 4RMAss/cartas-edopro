--Script: 4RMAss · Anime Server by 4RMAss
--モンスターBOX (Anime)
--Fairy Box (Anime)
--Script nuevo, escrito desde cero a partir del texto del anime (Yu-Gi-Oh! 068, 086, 087, 111):
--  "Todos los monstruos en Posición de Ataque de tu lado del campo se esconden en una caja
--   para entorpecer los ataques del rival."
--Cómo se ha llevado al juego:
--  - Magia Normal que se queda en el campo tras activarse (la caja).
--  - Cada vez que un monstruo del rival declara un ataque contra uno de tus monstruos en
--    Posición de Ataque, el rival tiene que adivinar dónde asoma: lanza una moneda y la
--    canta; si falla, ese ataque se anula.
--  - Si "Umi" está en el campo, la caja queda bajo el agua: los monstruos que no son de
--    AGUA salen de la caja y no están protegidos.
--  - Se destruye al final de la siguiente Battle Phase de tu adversario.
local s,id=GetID()
function s.initial_effect(c)
	--Activate: la carta se queda en el campo
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--los ataques contra monstruos escondidos: el rival debe adivinar
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_ATTACK_ANNOUNCE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCondition(s.atkcon)
	e2:SetOperation(s.atkop)
	c:RegisterEffect(e2)
end
s.listed_names={CARD_UMI}
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	c:CancelToGrave()
	--se destruye al final de la siguiente Battle Phase del adversario
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e1:SetRange(LOCATION_SZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(s.descon)
	e1:SetOperation(s.desop)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e1)
end
function s.descon(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsTurnPlayer(1-tp)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_CARD,0,id)
	Duel.Destroy(e:GetHandler(),REASON_EFFECT)
end
--¿el monstruo está escondido en la caja?
function s.hidden(c,tp)
	if not (c:IsControler(tp) and c:IsLocation(LOCATION_MZONE) and c:IsAttackPos()) then return false end
	--con "Umi" en el campo, los que no son de AGUA tienen que salir
	if Duel.IsEnvironment(CARD_UMI) and not c:IsAttribute(ATTRIBUTE_WATER) then return false end
	return true
end
function s.atkcon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local a=Duel.GetAttacker()
	local d=Duel.GetAttackTarget()
	return c:IsFaceup() and c:IsStatus(STATUS_EFFECT_ENABLED)
		and a and a:IsControler(1-tp) and d and s.hidden(d,tp)
end
function s.atkop(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_CARD,0,id)
	--el rival canta la moneda: si acierta, encuentra al monstruo; si no, el ataque falla
	if not Duel.CallCoin(1-tp) then
		Duel.NegateAttack()
	end
end

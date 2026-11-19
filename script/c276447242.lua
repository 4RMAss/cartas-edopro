--Script: 4RMAss · Anime Server by 4RMAss
--モンスターBOX (Anime)
--Fairy Box (Anime)
--Script escrito desde cero. Adaptación de 4RMAss del texto del anime
--(Yu-Gi-Oh! 068, 086, 087, 111):
--  - Magia Rápida que se queda boca arriba en el campo al activarse.
--  - Cada vez que un monstruo del rival declara un ataque, el rival declara un número
--    del 1 al 6 y se lanza un dado: si acierta, el ataque sigue; si no, se anula.
--  - Mientras "Umi" esté en el campo, este efecto queda negado.
--  - Se destruye al final de la Battle Phase del turno en que se activó (si se activa
--    después de esa Battle Phase, se destruye en la End Phase de ese mismo turno).
local s,id=GetID()
s.roll_dice=true
function s.initial_effect(c)
	--Activate: la carta se queda boca arriba en el campo
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--cuando el rival declara un ataque: dado
	local e2=Effect.CreateEffect(c)
	e2:SetCategory(CATEGORY_DICE)
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
	--se destruye al final de la Battle Phase de este turno...
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e1:SetRange(LOCATION_SZONE)
	e1:SetCountLimit(1)
	e1:SetOperation(s.desop)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
	c:RegisterEffect(e1)
	--...o en la End Phase si ya no queda Battle Phase en este turno
	local e2=e1:Clone()
	e2:SetCode(EVENT_PHASE+PHASE_END)
	c:RegisterEffect(e2)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsOnField() then return end
	Duel.Hint(HINT_CARD,0,id)
	Duel.Destroy(c,REASON_EFFECT)
end
function s.atkcon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local a=Duel.GetAttacker()
	return c:IsFaceup() and c:IsStatus(STATUS_EFFECT_ENABLED) and not c:IsDisabled()
		and a and a:IsControler(1-tp)
		--con "Umi" en el campo, el efecto está negado
		and not Duel.IsEnvironment(CARD_UMI)
end
function s.atkop(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_CARD,0,id)
	--el rival declara un número del 1 al 6
	Duel.Hint(HINT_SELECTMSG,1-tp,HINTMSG_NUMBER)
	local num=Duel.AnnounceNumber(1-tp,1,2,3,4,5,6)
	Duel.Hint(HINT_NUMBER,tp,num)
	--se lanza el dado: si acierta, puede atacar; si no, el ataque se anula
	local roll=Duel.TossDice(tp,1)
	if roll~=num then
		Duel.NegateAttack()
	end
end

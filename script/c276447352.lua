--Surprise Attack from Beyond (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
--Basado en el script del ID 319 (Surprise Attack From Beyond): en la End Phase, 1 monstruo invocado este turno
--hace un ataque sorpresa (sirve también para The Winged Dragon of Ra revivido y cualquier Bestia Divina)
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.condition)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
--Solo Main Phase 2
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetCurrentPhase()==PHASE_MAIN2
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	--End Phase attack (al empezar la End Phase, antes de que los monstruos revividos vuelvan al Cementerio)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE_START+PHASE_END)
	e1:SetCountLimit(1)
	e1:SetOperation(s.atkop)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
end
--Monstruos invocados este turno
function s.filter(c)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER) and
	(c:IsStatus(STATUS_SUMMON_TURN) or c:IsStatus(STATUS_SPSUMMON_TURN))
end
function s.atkop(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_MZONE,0,1,nil) then return end
	Duel.Hint(HINT_CARD,0,id)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACK)
	local g=Duel.SelectMatchingCard(tp,s.filter,tp,LOCATION_MZONE,0,1,1,nil)
	local tc=g:GetFirst()
	if not tc then return end
	local og=Duel.GetMatchingGroup(Card.IsFaceup,tp,0,LOCATION_MZONE,nil)
	--Si el rival tiene monstruos
	if #og>0 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACKTARGET)
		local tg=og:Select(tp,1,1,nil)
		local bc=tg:GetFirst()
		if not bc then return end
		local atk1=tc:GetAttack()
		local def=bc:IsDefensePos()
		local val2=def and bc:GetDefense() or bc:GetAttack()
		Duel.CalculateDamage(tc,bc)
		--Destrucción por batalla manual (contra un monstruo en Defensa se compara con su DEF)
		local dg=Group.CreateGroup()
		if atk1>val2 then
			dg:AddCard(bc)
		elseif atk1<val2 then
			if not def then dg:AddCard(tc) end
		elseif not def then
			dg:AddCard(tc)
			dg:AddCard(bc)
		end
		dg=dg:Filter(Card.IsLocation,nil,LOCATION_MZONE)
		if #dg>0 then Duel.Destroy(dg,REASON_BATTLE) end
	else
		--Ataque directo
		Duel.CalculateDamage(tc,nil)
	end
end

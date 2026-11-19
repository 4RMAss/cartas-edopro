--Script: 4RMAss · Anime Server by 4RMAss
--Surprise Attack From Beyond (Anime)

if not _FromCardsCompat then
_FromCardsCompat=true
local _oldFromCards=Group.FromCards
Group.FromCards=function(...)
	local t={}
	for _,v in ipairs({...}) do if v then table.insert(t,v) end end
	if #t==0 then return Group.CreateGroup() end
	return _oldFromCards(table.unpack(t))
end
end
function c319.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(c319.condition)
	e1:SetOperation(c319.operation)
	c:RegisterEffect(e1)
end

--Solo Main Phase 2
function c319.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetCurrentPhase()==PHASE_MAIN2
end

function c319.operation(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()

	--End Phase attack
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_END)
	e1:SetCountLimit(1)
	e1:SetOperation(c319.atkop)
	e1:SetReset(RESET_PHASE+PHASE_END)
	Duel.RegisterEffect(e1,tp)
end

--Monstruos invocados este turno
function c319.filter(c)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER) and
	(c:IsStatus(STATUS_SUMMON_TURN) or c:IsStatus(STATUS_SPSUMMON_TURN))
end

function c319.atkop(e,tp,eg,ep,ev,re,r,rp)

	if not Duel.IsExistingMatchingCard(c319.filter,tp,LOCATION_MZONE,0,1,nil) then return end

	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACK)
	local g=Duel.SelectMatchingCard(tp,c319.filter,tp,LOCATION_MZONE,0,1,1,nil)
	local tc=g:GetFirst()
	if not tc then return end

	local og=Duel.GetMatchingGroup(Card.IsFaceup,tp,0,LOCATION_MZONE,nil)

	--Si el rival tiene monstruos
	if #og>0 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACK)
		local tg=og:Select(tp,1,1,nil)
		local bc=tg:GetFirst()
		if not bc then return end

		local atk1=tc:GetAttack()
		local atk2=bc:GetAttack()

		Duel.CalculateDamage(tc,bc)

		--Destrucción por batalla manual
		if atk1>atk2 then
			Duel.Destroy(bc,REASON_BATTLE)
		elseif atk2>atk1 then
			Duel.Destroy(tc,REASON_BATTLE)
		else
			Duel.Destroy(Group.FromCards(tc,bc),REASON_BATTLE)
		end

	else
		--Ataque directo
		Duel.CalculateDamage(tc,nil)
	end

end
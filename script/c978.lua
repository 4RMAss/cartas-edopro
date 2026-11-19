--Script: 4RMAss · Anime Server by 4RMAss
--奇跡の銀河 (Modificado para ataque adicional en Main Phase 2)
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
function c978.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(23118924,0))
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(c978.condition)
	e1:SetOperation(c978.operation)
	c:RegisterEffect(e1)
end

--Solo se puede activar en Main Phase 2
function c978.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetTurnPlayer()==tp and Duel.GetCurrentPhase()==PHASE_MAIN2
end

function c978.operation(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	
	--Permitir ataque adicional inmediatamente
	if Duel.IsExistingMatchingCard(c978.filter,tp,LOCATION_MZONE,0,1,nil) then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACK)
		local g=Duel.SelectMatchingCard(tp,c978.filter,tp,LOCATION_MZONE,0,1,1,nil)
		local tc=g:GetFirst()
		
		if tc then
			c978.performattack(tc,tp)
		end
	end
end

--Filtro: cualquier monstruo boca arriba
function c978.filter(c)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER)
end

--Realizar el ataque
function c978.performattack(tc,tp)
	local og=Duel.GetMatchingGroup(Card.IsFaceup,tp,0,LOCATION_MZONE,nil)
	
	--Si el rival tiene monstruos
	if #og>0 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACK)
		local tg=og:Select(tp,1,1,nil)
		local bc=tg:GetFirst()
		
		if bc then
			local atk1=tc:GetAttack()
			local atk2=bc:GetAttack()
			
			--Calcular daño de batalla
			Duel.CalculateDamage(tc,bc)
			
			--Destrucción por batalla manual
			if atk1>atk2 then
				Duel.Destroy(bc,REASON_BATTLE)
			elseif atk2>atk1 then
				Duel.Destroy(tc,REASON_BATTLE)
			else
				--Si tienen el mismo ATK, ambos son destruidos
				Duel.Destroy(Group.FromCards(tc,bc),REASON_BATTLE)
			end
		end
	else
		--Ataque directo al jugador rival
		Duel.CalculateDamage(tc,nil)
	end
end
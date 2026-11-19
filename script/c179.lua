--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--光の護封剣 (Manga)
--Swords of Revealing Light (Manga)
--Adaptado del script OFICIAL c72302403. Diferencia segun el texto japones del manga:
--  - NO voltea boca arriba los monstruos boca abajo del rival al activarse.
--    Solo impide que el rival declare ataques durante 3 de sus turnos.
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.actcon)
	e1:SetTarget(s.target)
	c:RegisterEffect(e1)
	--cannot announce attack
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(0,LOCATION_MZONE)
	e2:SetCondition(s.atkcon)
	c:RegisterEffect(e2)
	--remain field
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e3:SetCode(EFFECT_REMAIN_FIELD)
	c:RegisterEffect(e3)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	local c=e:GetHandler()
	c:SetTurnCounter(0)
	--destroy
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetCode(EVENT_PHASE+PHASE_END)
	e1:SetCountLimit(1)
	e1:SetRange(LOCATION_SZONE)
	e1:SetCondition(s.descon)
	e1:SetOperation(s.desop)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END+RESET_OPPO_TURN,3)
	c:RegisterEffect(e1)
	c:RegisterFlagEffect(1082946,RESET_PHASE+PHASE_END+RESET_OPPO_TURN,0,3)
end
function s.descon(e,tp,eg,ep,ev,re,r,rp)
	return tp~=Duel.GetTurnPlayer()
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ct=c:GetTurnCounter()
	ct=ct+1
	c:SetTurnCounter(ct)
	if ct==3 then
		Duel.Destroy(c,REASON_RULE)
		c:ResetFlagEffect(1082946)
	end
end
--Restriccion de activacion pedida:
--  * en TU turno, solo en Main Phase 1 o Main Phase 2
--  * en el turno del RIVAL, solo durante la Battle Phase y con la carta ya en tu campo
--OJO: PHASE_BATTLE (0x80) no es toda la fase, es su paso final. La Battle Phase son
--cinco pasos seguidos, de PHASE_BATTLE_START a PHASE_BATTLE; por eso se compara el rango.
--Solo se puede activar mientras "Anime Mode (Creator Mode)" (600000238) o
--"Manga Mode (Creator Mode)" (189) este desterrada boca arriba: es la regla del
--manga que permite jugar estas Magias Normales como si fueran de Juego Rapido.
--Las dos cartas de modo se destierran boca arriba al empezar el duelo, asi que basta
--con buscarlas en la zona de desterradas de cualquiera de los dos jugadores.
local MODE_ANIME=600000238
local MODE_MANGA=189
function s.modefilter(c)
	return c:IsFaceup() and (c:IsCode(MODE_ANIME) or c:IsCode(MODE_MANGA))
end
function s.modeon()
	return Duel.IsExistingMatchingCard(s.modefilter,0,LOCATION_REMOVED,LOCATION_REMOVED,1,nil)
end
--en tu propio turno, como una Magia Normal: Main Phase y Cadena vacia.
--La velocidad de Juego Rapido queda para el turno del rival.
function s.ownturnok(tp)
	if Duel.GetTurnPlayer()~=tp then return true end
	local ph=Duel.GetCurrentPhase()
	return (ph==PHASE_MAIN1 or ph==PHASE_MAIN2) and Duel.GetCurrentChain()==0
end
function s.actcon(e,tp,eg,ep,ev,re,r,rp)
	if not s.ownturnok(tp) then return false end
	if not s.modeon() then return false end
	local ph=Duel.GetCurrentPhase()
	if Duel.GetTurnPlayer()==tp then
		return ph==PHASE_MAIN1 or ph==PHASE_MAIN2
	end
	return e:GetHandler():IsLocation(LOCATION_SZONE)
		and ph>=PHASE_BATTLE_START and ph<=PHASE_BATTLE
end
function s.atkcon(e)
	--el original comparaba GetType()==TYPE_SPELL para dejar de aplicarse si la carta
	--pasaba a ser monstruo. Ahora es Magia Rapida (0x10002), asi que esa igualdad seria
	--falsa SIEMPRE y el bloqueo no se aplicaria nunca. Se comprueba la intencion real.
	return not e:GetHandler():IsType(TYPE_MONSTER)
end

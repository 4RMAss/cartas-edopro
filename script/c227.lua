--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script de Project Ignis (EDOPro), con licencia AGPL-3.0.
--Loss of Strength (Manga)
--Version de juego rapido de "Loss of Strength" (511000727).
--En el manga estas Magias se juegan como rapidas porque alli rige una regla que lo
--permite; aqui esa regla no se puede implementar, asi que la carta es Quick-Play de
--serie y a cambio solo se puede activar mientras "Anime Mode (Creator Mode)" o
--"Manga Mode (Creator Mode)" este desterrada boca arriba, que es cuando esa regla
--estaria en vigor. El efecto es identico al de la carta base.
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
local ANIME_MODE=600000238
local MANGA_MODE=189
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.actcon)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--una de las dos cartas de modo, desterrada boca arriba, en cualquiera de los lados
function s.modefilter(c)
	return c:IsFaceup() and (c:IsCode(ANIME_MODE) or c:IsCode(MANGA_MODE))
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
	return Duel.IsExistingMatchingCard(s.modefilter,0,LOCATION_REMOVED,LOCATION_REMOVED,1,nil)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsFaceup() end
	if chk==0 then return Duel.IsExistingTarget(Card.IsFaceup,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,Card.IsFaceup,tp,LOCATION_MZONE,LOCATION_MZONE,1,1,nil)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc:IsFaceup() and tc:IsRelateToEffect(e) and not tc:IsImmuneToEffect(e) then
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(0)
		e1:SetReset(RESET_EVENT+RESETS_STANDARD)
		tc:RegisterEffect(e1)
		local e2=Effect.CreateEffect(e:GetHandler())
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_CANNOT_ATTACK)
		e2:SetReset(RESET_EVENT+RESETS_STANDARD-RESET_TURN_SET)
		tc:RegisterEffect(e2)
		local e3=Effect.CreateEffect(e:GetHandler())
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
		e3:SetRange(LOCATION_MZONE)
		e3:SetCode(EFFECT_CANNOT_BE_BATTLE_TARGET)
		e3:SetValue(1)
		e3:SetReset(RESET_EVENT+RESETS_STANDARD-RESET_TURN_SET)
		tc:RegisterEffect(e3)
		--direct attack
		local e4=Effect.CreateEffect(e:GetHandler())
		e4:SetType(EFFECT_TYPE_FIELD)
		e4:SetCode(EFFECT_DIRECT_ATTACK)
		e4:SetRange(LOCATION_MZONE)
		e4:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
		e4:SetTarget(s.dirtg)
		e4:SetReset(RESET_EVENT+RESETS_STANDARD-RESET_TURN_SET)
		tc:RegisterEffect(e4)
		tc:RegisterFlagEffect(id,RESET_EVENT+RESETS_STANDARD,0,1)
	end
end
function s.dirfilter(c)
	return c:GetFlagEffect(id)==0
end
function s.dirtg(e,c)
	return not Duel.IsExistingMatchingCard(s.dirfilter,c:GetControler(),0,LOCATION_MZONE,1,nil)
end

--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--ユニオン・アタック (Manga)
--Union Attack (Manga)
--Diferencias con el script OFICIAL c60399954:
--  (a) El texto del manga NO impide atacar a los demas monstruos. Por eso aqui no se
--      registra el EFFECT_CANNOT_ATTACK que el oficial pone en su Target.
--  (b) El aumento se aplica EN EL DAMAGE STEP, cuando el monstruo elegido ataca, y no
--      al empezar la Battle Phase. Se recalcula en cada batalla suya.
--  (c) Mientras dura el aumento, el monstruo lleva un efecto con codigo 21208154.
--      Ese es el marcador que "The Wicked Avatar" usa en su propio filtro
--      (s.filter: not c:IsHasEffect(21208154)) para decidir que monstruos cuenta al
--      calcular su ATK. Con el marcador puesto, Avatar NO cuenta a este monstruo, asi
--      que no se le sube por encima y Union Attack puede derrotarlo. Sin esto no hay
--      forma: el ATK de Avatar se recalcula tambien dentro del Damage Step.
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
local WICKED_AVATAR=21208154
function s.initial_effect(c)
	--atkup
	local e1=Effect.CreateEffect(c)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
--el aumento solo cuenta en la Battle Phase de este turno, asi que activarla en Main
--Phase 2 no haria nada. Se mantiene la restriccion del script oficial.
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetCurrentPhase()==PHASE_MAIN1
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and chkc:IsFaceup() end
	if chk==0 then return Duel.IsExistingTarget(Card.IsFaceup,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,Card.IsFaceup,tp,LOCATION_MZONE,0,1,1,nil)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc:IsFaceup() and tc:IsRelateToEffect(e) then
		--se queda a la espera: el aumento se calcula al atacar, en el Damage Step
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		e1:SetCode(EVENT_PRE_DAMAGE_CALCULATE)
		e1:SetRange(LOCATION_MZONE)
		e1:SetLabelObject(tc)
		e1:SetOperation(s.atkop)
		e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
		tc:RegisterEffect(e1)
		--no hace dano de batalla al rival en todo el turno
		local e2=Effect.CreateEffect(e:GetHandler())
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_NO_BATTLE_DAMAGE)
		e2:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
		tc:RegisterEffect(e2)
	end
end
function s.atkop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	--solo cuando el monstruo elegido es el ATACANTE
	if Duel.GetAttacker()~=c then return end
	local atk=0
	local g=Duel.GetMatchingGroup(Card.IsPosition,c:GetControler(),LOCATION_MZONE,0,c,POS_FACEUP_ATTACK)
	local tc=g:GetFirst()
	while tc do
		atk=atk+tc:GetAttack()
		tc=g:GetNext()
	end
	if atk<=0 then return end
	local e1=Effect.CreateEffect(e:GetOwner())
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(atk)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_DAMAGE)
	c:RegisterEffect(e1)
	--mientras dure el aumento, "The Wicked Avatar" no cuenta a este monstruo
	local e2=Effect.CreateEffect(e:GetOwner())
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(WICKED_AVATAR)
	e2:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_DAMAGE)
	c:RegisterEffect(e2)
end

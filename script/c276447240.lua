--Script: 4RMAss · Anime Server by 4RMAss
--Shadow of Eyes (Anime)
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	--activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.condition)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--change position + must attack (continuous)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCode(EFFECT_MUST_ATTACK)
	e2:SetTargetRange(0,LOCATION_MZONE)
	e2:SetCondition(s.econ)
	e2:SetTarget(s.atktg)
	c:RegisterEffect(e2)
	--cannot change position
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCode(EFFECT_CANNOT_CHANGE_POSITION)
	e3:SetTargetRange(0,LOCATION_MZONE)
	e3:SetCondition(s.econ)
	c:RegisterEffect(e3)
end
function s.cfilter(c)
	return c:IsFaceup() and c:IsSetCard(0x64) and c:IsType(TYPE_MONSTER)
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_MZONE,0,1,nil)
end
function s.econ(e)
	return Duel.IsExistingMatchingCard(s.cfilter,e:GetHandlerPlayer(),LOCATION_MZONE,0,1,nil)
end
function s.atktg(e,c)
	return c:IsFaceup() and c:IsPosition(POS_FACEUP_ATTACK)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	--cambiar todos los monstruos del rival a posicion de ataque (sin activar Flip)
	local g=Duel.GetMatchingGroup(Card.IsCanChangePosition,tp,0,LOCATION_MZONE,nil)
	local tc=g:GetFirst()
	while tc do
		if not tc:IsPosition(POS_FACEUP_ATTACK) then
			Duel.ChangePosition(tc,POS_FACEUP_ATTACK,POS_FACEUP_ATTACK,POS_FACEUP_ATTACK,POS_FACEUP_ATTACK,true)
		end
		tc=g:GetNext()
	end
end

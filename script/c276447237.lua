--Script: 4RMAss · Anime Server by 4RMAss
--Deck Destruction Virus (Custom)
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DECKDES)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_BATTLE_DESTROYED)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--"cuando un monstruo de Tipo Demonio de ATRIBUTO OSCURIDAD con 500 ATK o menos
--es destruido como resultado de una batalla"
function s.cfilter(c)
	return c:IsPreviousPosition(POS_FACEUP)
		and c:IsAttribute(ATTRIBUTE_DARK)
		and c:IsRace(RACE_FIEND)
		and c:GetPreviousAttackOnField()<=500
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return eg:IsExists(s.cfilter,1,nil)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsPlayerCanDiscardDeck(1-tp,10) end
	Duel.SetOperationInfo(0,CATEGORY_DECKDES,nil,0,1-tp,10)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	--"manda 10 cartas al azar del Deck de tu adversario al Cementerio".
	--El core no expone un descarte aleatorio del Deck; DiscardDeck manda desde
	--arriba, que sobre un Deck barajado es lo mismo en la practica.
	Duel.DiscardDeck(1-tp,10,REASON_EFFECT)
end

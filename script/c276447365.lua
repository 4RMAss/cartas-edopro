--Fenrir the Nordic Wolf (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_SPSUM_PARAM)
	e1:SetRange(LOCATION_HAND)
	e1:SetTargetRange(POS_FACEUP_DEFENSE,1)
	e1:SetCondition(s.spcon)
	c:RegisterEffect(e1)
	--Destroy this card if there are no face-up Divine-Beast monsters
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_SELF_DESTROY)
	e2:SetCondition(function(e) return not Duel.IsExistingMatchingCard(s.dbfilter,0,LOCATION_MZONE,LOCATION_MZONE,1,nil) end)
	c:RegisterEffect(e2)
	--Change Defense Position monsters to Attack Position during the Battle Phase
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_POSITION)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_PHASE_START+PHASE_BATTLE_START)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetOperation(s.posop)
	c:RegisterEffect(e3)
	--Battle damage is also inflicted to the other player
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_BATTLE_DAMAGE)
	e4:SetOperation(function(e,tp,eg,ep,ev,re,r,rp) Duel.Damage(1-ep,ev,REASON_EFFECT) end)
	c:RegisterEffect(e4)
end

function s.dbfilter(c)
	return c:IsFaceup() and c:IsRace(RACE_DIVINE)
end
function s.spcon(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.GetCurrentPhase()==PHASE_MAIN2 and Duel.GetLocationCount(1-tp,LOCATION_MZONE,tp)>0
		and Duel.IsExistingMatchingCard(s.dbfilter,tp,LOCATION_MZONE,0,1,nil)
end

function s.posop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetMatchingGroup(Card.IsDefensePos,tp,LOCATION_MZONE,0,nil)
	if #g>0 then Duel.ChangePosition(g,POS_FACEUP_ATTACK) end
end

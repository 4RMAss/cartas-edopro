--Shinato, King of a Higher Plane (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	c:EnableUnsummonable()
	--Can only be Special Summoned by its own effect
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetCode(EFFECT_SPSUMMON_CONDITION)
	e0:SetValue(function(e,se) return se and se:GetHandler()==e:GetHandler() end)
	c:RegisterEffect(e0)
	--When a "Shinato's Ark" is removed from your field: Special Summon this card from your hand
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,2))
	e3:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetProperty(EFFECT_FLAG_DELAY)
	e3:SetCode(EVENT_LEAVE_FIELD)
	e3:SetRange(LOCATION_HAND)
	e3:SetCondition(s.spcon)
	e3:SetTarget(s.sptg)
	e3:SetOperation(s.spop)
	c:RegisterEffect(e3)
	--Halve the opponent's LP after destroying a Defense Position monster
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DAMAGE+CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCondition(s.hlcon)
	e1:SetOperation(s.hlop)
	c:RegisterEffect(e1)
	--Gain LP equal to the battle damage it inflicts
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_RECOVER)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_BATTLE_DAMAGE)
	e2:SetCondition(function(e,tp,eg,ep,ev,re,r,rp) return ep==1-tp end)
	e2:SetOperation(function(e,tp,eg,ep,ev,re,r,rp) Duel.Recover(tp,ev,REASON_EFFECT) end)
	c:RegisterEffect(e2)
end
--"Shinato's Ark": the official Ritual Spell and the Deck Master version
local ARKS={60365591,153000017}
s.listed_names={60365591}
function s.arkfilter(c,tp)
	return c:IsCode(table.unpack(ARKS)) and c:IsPreviousControler(tp) and c:IsPreviousLocation(LOCATION_ONFIELD)
end
function s.spcon(e,tp,eg,ep,ev,re,r,rp)
	return eg:IsExists(s.arkfilter,1,nil,tp)
end
function s.sptg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0 and c:IsCanBeSpecialSummoned(e,0,tp,false,false) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,c,1,0,0)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) then Duel.SpecialSummon(c,0,tp,tp,false,false,POS_FACEUP) end
end
function s.hlcon(e,tp,eg,ep,ev,re,r,rp)
	local bc=e:GetHandler():GetBattleTarget()
	return bc and bc:IsPreviousPosition(POS_DEFENSE) and bc:IsPreviousControler(1-tp)
end
function s.hlop(e,tp,eg,ep,ev,re,r,rp)
	local d=math.floor(Duel.GetLP(1-tp)/2)
	if d<=0 then return end
	local dmg=Duel.Damage(1-tp,d,REASON_EFFECT)
	if dmg>0 then Duel.Recover(tp,dmg,REASON_EFFECT) end
end

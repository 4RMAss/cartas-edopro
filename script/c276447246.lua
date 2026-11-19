--魔法効果の矢
--Living Arrow (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Use "Polymerization" with a monster your opponent controls
	local e1=Fusion.CreateSummonEff({handler=c,extrafil=s.fextra,desc=aux.Stringid(id,0)})
	e1:SetCost(s.cost)
	c:RegisterEffect(e1)
	--Imperfect fusion: a Zombie (or "Mammoth Graveyard") you control rots an opponent's monster
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_TOGRAVE+CATEGORY_ATKCHANGE)
	e2:SetType(EFFECT_TYPE_ACTIVATE)
	e2:SetCode(EVENT_FREE_CHAIN)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetHintTiming(0,TIMINGS_CHECK_MONSTER_E)
	e2:SetCost(s.cost)
	e2:SetTarget(s.rottg)
	e2:SetOperation(s.rotop)
	c:RegisterEffect(e2)
end
s.listed_names={CARD_POLYMERIZATION,40374923}
s.listed_races={RACE_ZOMBIE}
--Cost: send 1 "Polymerization" from your hand to the GY
function s.costfilter(c)
	return c:IsCode(CARD_POLYMERIZATION) and c:IsAbleToGraveAsCost()
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.costfilter,tp,LOCATION_HAND,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local g=Duel.SelectMatchingCard(tp,s.costfilter,tp,LOCATION_HAND,0,1,1,nil)
	Duel.SendtoGrave(g,REASON_COST)
end
--● Fusion Summon using at least 1 face-up monster your opponent controls
function s.fextra(e,tp,mg)
	return Duel.GetMatchingGroup(Fusion.IsMonsterFilter(Card.IsFaceup),tp,0,LOCATION_MZONE,nil),s.fcheck
end
function s.fcheck(tp,sg,fc)
	return sg:IsExists(Card.IsControler,1,nil,1-tp)
end
--● Imperfect fusion
--"Mammoth Graveyard" is an undead monster in the manga
function s.undead(c)
	return c:IsRace(RACE_ZOMBIE) or c:IsCode(40374923)
end
function s.zfilter(c)
	return c:IsFaceup() and s.undead(c) and c:IsAbleToGrave()
end
function s.ofilter(c)
	return c:IsFaceup() and not c:IsRace(RACE_ZOMBIE)
end
function s.rottg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return false end
	if chk==0 then return Duel.IsExistingTarget(s.zfilter,tp,LOCATION_MZONE,0,1,nil)
		and Duel.IsExistingTarget(s.ofilter,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local g1=Duel.SelectTarget(tp,s.zfilter,tp,LOCATION_MZONE,0,1,1,nil)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,s.ofilter,tp,0,LOCATION_MZONE,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_TOGRAVE,g1,1,0,0)
end
function s.rotop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetTargetCards(e)
	local zc=g:Filter(Card.IsControler,nil,tp):GetFirst()
	local oc=g:Filter(Card.IsControler,nil,1-tp):GetFirst()
	if not zc or not s.undead(zc) then return end
	local atk=zc:GetBaseAttack()
	if Duel.SendtoGrave(zc,REASON_EFFECT)==0 or not zc:IsLocation(LOCATION_GRAVE) then return end
	if not oc or not oc:IsFaceup() or oc:IsRace(RACE_ZOMBIE) or atk<=0 then return end
	--During each of your End Phases, it loses ATK equal to the Zombie's original ATK
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetDescription(aux.Stringid(id,2))
	e1:SetProperty(EFFECT_FLAG_CLIENT_HINT)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_END)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetLabel(tp,atk)
	e1:SetCondition(s.rotcon)
	e1:SetOperation(s.rotdecay)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD)
	oc:RegisterEffect(e1)
end
function s.rotcon(e)
	local p=e:GetLabel()
	return Duel.GetTurnPlayer()==p
end
function s.rotdecay(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local _,atk=e:GetLabel()
	Duel.Hint(HINT_CARD,0,id)
	local e1=Effect.CreateEffect(e:GetOwner())
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(-atk)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD)
	c:RegisterEffect(e1)
end

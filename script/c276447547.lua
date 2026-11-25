--T.G. Striker (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
local BASE=1315120
function s.initial_effect(c)
	--Special Summon this card from your hand
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetCondition(s.spcon)
	c:RegisterEffect(e1)
	s.machine(c)
	s.halve(c)
	s.samereg(c)
end
s.listed_names={BASE}
function s.spcon(e,c)
	if c==nil then return true end
	return Duel.GetFieldGroupCount(c:GetControler(),LOCATION_MZONE,0)==0
		and Duel.GetFieldGroupCount(c:GetControler(),0,LOCATION_MZONE)>0
		and Duel.GetLocationCount(c:GetControler(),LOCATION_MZONE)>0
end

--This card is also treated as Machine-Type
function s.machine(c)
	local e=Effect.CreateEffect(c)
	e:SetType(EFFECT_TYPE_SINGLE)
	e:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e:SetCode(EFFECT_ADD_RACE)
	e:SetRange(LOCATION_MZONE)
	e:SetValue(RACE_MACHINE)
	c:RegisterEffect(e)
end
--When affected by the effect of your Spell/Trap that targets it (a Machine-Type monster): its original ATK/DEF become halved
function s.halve(c)
	local e=Effect.CreateEffect(c)
	e:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e:SetCode(EVENT_CHAIN_SOLVED)
	e:SetRange(LOCATION_MZONE)
	e:SetCondition(s.halvecon)
	e:SetOperation(s.halveop)
	c:RegisterEffect(e)
end
function s.halvecon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if rp~=tp or not re:IsSpellTrapEffect() or not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then return false end
	if Duel.GetChainInfo(ev,CHAININFO_DISABLE_REASON) then return false end
	if not (c:IsFaceup() and c:IsRace(RACE_MACHINE)) then return false end
	local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	return g~=nil and g:IsContains(c) and c:IsRelateToEffect(re)
end
function s.halveop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	Duel.Hint(HINT_CARD,0,id)
	local atk,def=c:GetBaseAttack()//2,c:GetBaseDefense()//2
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetCode(EFFECT_SET_BASE_ATTACK)
	e1:SetValue(atk)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_SET_BASE_DEFENSE)
	e2:SetValue(def)
	c:RegisterEffect(e2)
end
--That card cannot be used this turn
function s.lock(tc,c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_FORBIDDEN)
	e1:SetRange(0xff)
	e1:SetTargetRange(0x7f,0x7f)
	e1:SetTarget(function(e,c) return c==e:GetHandler() end)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
	tc:RegisterEffect(e1)
end

function s.samereg(c)
	local e=Effect.CreateEffect(c)
	e:SetDescription(aux.Stringid(id,1))
	e:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e:SetProperty(EFFECT_FLAG_DELAY)
	e:SetCode(EVENT_DESTROYED)
	e:SetTarget(s.thtg)
	e:SetOperation(s.thop)
	c:RegisterEffect(e)
end
function s.thfilter(c)
	return c:IsCode(BASE) and c:IsAbleToHand()
end
function s.thtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil) end
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
end
function s.thop(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
	local tc=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil):GetFirst()
	if tc and Duel.SendtoHand(tc,nil,REASON_EFFECT)>0 and tc:IsLocation(LOCATION_HAND) then
		Duel.ConfirmCards(1-tp,tc)
		s.lock(tc,e:GetHandler())
	end
end

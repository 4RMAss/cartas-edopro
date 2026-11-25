--T.G. Jet Falcon (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
local BASE=37300735
function s.initial_effect(c)
	--Inflict 500 damage
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(EVENT_BE_MATERIAL)
	e1:SetCondition(s.damcon)
	e1:SetTarget(s.damtg)
	e1:SetOperation(s.damop)
	c:RegisterEffect(e1)
	s.machine(c)
	s.halve(c)
end
function s.damcon(e,tp,eg,ep,ev,re,r,rp)
	return e:GetHandler():IsLocation(LOCATION_GRAVE) and r==REASON_SYNCHRO
end
function s.damtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetTargetPlayer(1-tp)
	Duel.SetTargetParam(500)
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,500)
end
function s.damop(e,tp,eg,ep,ev,re,r,rp)
	local p,d=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER,CHAININFO_TARGET_PARAM)
	Duel.Damage(p,d,REASON_EFFECT)
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

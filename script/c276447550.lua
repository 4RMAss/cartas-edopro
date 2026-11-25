--T.G. Cyber Magician (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
local BASE=64910482
function s.initial_effect(c)
	--The other non-Tuner Synchro Materials can be sent from your hand
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetCode(EFFECT_HAND_SYNCHRO)
	e1:SetLabel(64910482)
	e1:SetValue(s.synval)
	c:RegisterEffect(e1)
	s.machine(c)
	--When a Spell/Trap Card you control targets this card: you can halve its original ATK/DEF
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_CHAINING)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCondition(s.hvcon)
	e2:SetOperation(s.hvop)
	c:RegisterEffect(e2)
	--When destroyed: add 1 "T.G." monster from your Deck to your hand
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e3:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e3:SetProperty(EFFECT_FLAG_DELAY)
	e3:SetCode(EVENT_DESTROYED)
	e3:SetTarget(s.thtg)
	e3:SetOperation(s.thop)
	c:RegisterEffect(e3)
end
s.listed_series={SET_TG}
function s.synval(e,c,sc)
	if c:IsNotTuner(sc,e:GetHandlerPlayer()) and c:IsLocation(LOCATION_HAND) then
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_HAND_SYNCHRO+EFFECT_SYNCHRO_CHECK)
		e1:SetLabel(64910482)
		e1:SetTarget(s.synchktg)
		c:RegisterEffect(e1)
		return true
	else return false end
end
function s.chk2(c)
	if not c:IsHasEffect(EFFECT_HAND_SYNCHRO) or c:IsHasEffect(EFFECT_HAND_SYNCHRO+EFFECT_SYNCHRO_CHECK) then return false end
	for _,te in ipairs({c:GetCardEffect(EFFECT_HAND_SYNCHRO)}) do
		if te:GetLabel()==64910482 then return true end
	end
	return false
end
function s.synchktg(e,c,sg,tg,ntg,tsg,ntsg)
	if c then
		local res=tg:IsExists(s.chk2,1,c) or ntg:IsExists(s.chk2,1,c) or sg:IsExists(s.chk2,1,c)
		return res,Group.CreateGroup(),Group.CreateGroup()
	else
		return true
	end
end
function s.hvcon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsStatus(STATUS_BATTLE_DESTROYED) or rp~=tp or not re:IsSpellTrapEffect() then return false end
	if not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then return false end
	local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	return g~=nil and g:IsContains(c)
end
function s.hvop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) and c:IsFaceup() then s.halveop(e,tp,eg,ep,ev,re,r,rp) end
end
function s.thfilter(c)
	return c:IsMonster() and c:IsSetCard(SET_TG) and c:IsAbleToHand()
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
		--You cannot Summon it this turn
		for _,code in ipairs({EFFECT_CANNOT_SUMMON,EFFECT_CANNOT_MSET,EFFECT_CANNOT_SPECIAL_SUMMON}) do
			local e1=Effect.CreateEffect(e:GetHandler())
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(code)
			e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
			tc:RegisterEffect(e1)
		end
	end
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

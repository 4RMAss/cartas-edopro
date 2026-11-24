--Probability Change (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetCondition(s.condition)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--cards that toss coins / roll dice are marked by their scripts (toss_coin / roll_dice) or by their category
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	local rc=re:GetHandler()
	return re:IsHasCategory(CATEGORY_COIN|CATEGORY_DICE) or (rc and (rc.toss_coin or rc.roll_dice))
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_TOSS_DICE_NEGATE)
	e1:SetOperation(s.diceop)
	e1:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e1,tp)
	local e2=e1:Clone()
	e2:SetCode(EVENT_TOSS_COIN_NEGATE)
	e2:SetOperation(s.coinop)
	Duel.RegisterEffect(e2,tp)
end
function s.diceop(e,tp,eg,ep,ev,re,r,rp)
	if e:GetLabel()~=0 then return end
	e:SetLabel(1)
	Duel.Hint(HINT_CARD,0,id)
	--redo the roll: every die gets a new result, never the same as before
	local res={Duel.GetDiceResult()}
	for i=1,#res do
		local n=Duel.GetRandomNumber(1,5)
		if n>=res[i] then n=n+1 end
		res[i]=n
	end
	Duel.SetDiceResult(table.unpack(res))
end
function s.coinop(e,tp,eg,ep,ev,re,r,rp)
	if e:GetLabel()~=0 then return end
	e:SetLabel(1)
	Duel.Hint(HINT_CARD,0,id)
	local res={Duel.GetCoinResult()}
	for i=1,#res do res[i]=1-res[i] end
	Duel.SetCoinResult(table.unpack(res))
end

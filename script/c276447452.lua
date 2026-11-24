--Mirage Spell (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
local STATS={EFFECT_UPDATE_ATTACK,EFFECT_SET_ATTACK,EFFECT_SET_ATTACK_FINAL,EFFECT_SET_BASE_ATTACK,EFFECT_SET_BASE_ATTACK_FINAL,
	EFFECT_UPDATE_DEFENSE,EFFECT_SET_DEFENSE,EFFECT_SET_DEFENSE_FINAL,EFFECT_SET_BASE_DEFENSE,EFFECT_SET_BASE_DEFENSE_FINAL,
	EFFECT_SWAP_AD,EFFECT_SWAP_BASE_AD}
function s.stateffs(tc)
	local t={}
	for _,code in ipairs(STATS) do
		for _,ef in ipairs({tc:GetCardEffect(code)}) do t[ef]=true end
	end
	return t
end
function s.myface(c,tp)
	return c:IsControler(tp) and c:IsLocation(LOCATION_MZONE) and c:IsFaceup()
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	if rp~=1-tp or not re:IsHasCategory(CATEGORY_ATKCHANGE|CATEGORY_DEFCHANGE) then return false end
	if not Duel.IsExistingMatchingCard(Card.IsFaceup,tp,LOCATION_MZONE,0,1,nil) then return false end
	if re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then
		local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
		return g and g:IsExists(s.myface,1,nil,tp)
	end
	return true
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetPossibleOperationInfo(0,CATEGORY_RECOVER,nil,0,tp,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ch,snap=ev,{}
	--Right before the opponent's effect resolves: remember the stats of your monsters
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_CHAIN_SOLVING)
	e1:SetOperation(function(_,_,_,_,cev)
		if cev~=ch then return end
		for tc in Duel.GetMatchingGroup(Card.IsFaceup,tp,LOCATION_MZONE,0,nil):Iter() do
			snap[tc]={tc:GetAttack(),tc:GetDefense(),s.stateffs(tc)}
		end
	end)
	e1:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e1,tp)
	--After it resolves: undo the change and gain that much LP instead
	local e2=e1:Clone()
	e2:SetCode(EVENT_CHAIN_SOLVED)
	e2:SetOperation(function(_,_,_,_,cev)
		if cev~=ch then return end
		local gain=0
		for tc,v in pairs(snap) do
			if s.myface(tc,tp) then
				local d=math.abs(tc:GetAttack()-v[1])+math.abs(tc:GetDefense()-v[2])
				if d>0 then
					for ef in pairs(s.stateffs(tc)) do
						if not v[3][ef] then ef:Reset() end
					end
					gain=gain+d
				end
			end
		end
		if gain>0 then
			Duel.Hint(HINT_CARD,0,id)
			Duel.Recover(tp,gain,REASON_EFFECT)
		end
	end)
	Duel.RegisterEffect(e2,tp)
end

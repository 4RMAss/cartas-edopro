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
local STATS={EFFECT_UPDATE_ATTACK,EFFECT_SET_ATTACK,EFFECT_SET_ATTACK_FINAL,EFFECT_SET_BASE_ATTACK,
	EFFECT_UPDATE_DEFENSE,EFFECT_SET_DEFENSE,EFFECT_SET_DEFENSE_FINAL,EFFECT_SET_BASE_DEFENSE,
	EFFECT_SWAP_AD,EFFECT_SWAP_BASE_AD}
--1: change by an amount, 2: set the current value, 3: set the original value
local KIND={[EFFECT_UPDATE_ATTACK]={1,true},[EFFECT_SET_ATTACK]={2,true},[EFFECT_SET_ATTACK_FINAL]={2,true},
	[EFFECT_SET_BASE_ATTACK]={3,true},
	[EFFECT_UPDATE_DEFENSE]={1,false},[EFFECT_SET_DEFENSE]={2,false},[EFFECT_SET_DEFENSE_FINAL]={2,false},
	[EFFECT_SET_BASE_DEFENSE]={3,false}}
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
--How much the ATK/DEF of a monster you control would change with this effect (nil = unknown)
function s.amount(tc,ef,tp)
	local code=ef:GetCode()
	if code==EFFECT_SWAP_AD or code==EFFECT_SWAP_BASE_AD then return 2*math.abs(tc:GetAttack()-tc:GetDefense()) end
	local k=KIND[code]
	if not k then return nil end
	local v=ef:GetValue()
	if type(v)=='function' then
		local ok,res=pcall(v,ef,tc)
		if not ok or type(res)~='number' then return nil end
		v=res
	end
	if type(v)~='number' then return nil end
	local cur=k[2] and tc:GetAttack() or tc:GetDefense()
	if k[1]==1 then return v<0 and math.min(-v,cur) or v end
	if k[1]==2 then return math.abs(v-cur) end
	return math.abs(v-(k[2] and tc:GetBaseAttack() or tc:GetBaseDefense()))
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ch,st=ev,{gain=0,snap={}}
	local function unpatch()
		if st.orig then Card.RegisterEffect=st.orig st.orig=nil end
	end
	--While the opponent's effect resolves, the ATK/DEF changes it would apply to your monsters are not applied:
	--you gain that much LP instead
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_CHAIN_SOLVING)
	e1:SetOperation(function(_,_,_,_,cev)
		if cev~=ch or st.orig then return end
		for tc in Duel.GetMatchingGroup(Card.IsFaceup,tp,LOCATION_MZONE,0,nil):Iter() do
			st.snap[tc]={tc:GetAttack(),tc:GetDefense(),s.stateffs(tc)}
		end
		local orig=Card.RegisterEffect
		st.orig=orig
		Card.RegisterEffect=function(tc,ef,...)
			if tc and ef and s.myface(tc,tp) and KIND[ef:GetCode()] or (ef and (ef:GetCode()==EFFECT_SWAP_AD or ef:GetCode()==EFFECT_SWAP_BASE_AD) and tc and s.myface(tc,tp)) then
				if ef:GetOwnerPlayer()==1-tp then
					local d=s.amount(tc,ef,tp)
					if d then st.gain=st.gain+d return end
				end
			end
			return orig(tc,ef,...)
		end
	end)
	e1:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e1,tp)
	--After it resolves: undo any other change it made to your monsters, then gain the LP
	local e2=e1:Clone()
	e2:SetCode(EVENT_CHAIN_SOLVED)
	e2:SetOperation(function(_,_,_,_,cev)
		if cev~=ch then return end
		unpatch()
		for tc,v in pairs(st.snap) do
			if s.myface(tc,tp) then
				local a0,d0,found=tc:GetAttack(),tc:GetDefense(),false
				for ef in pairs(s.stateffs(tc)) do
					if not v[3][ef] and ef:GetOwnerPlayer()==1-tp then
						found=true
						if ef:IsHasType(EFFECT_TYPE_SINGLE) then
							ef:Reset()
						else
							local im=Effect.CreateEffect(c)
							im:SetType(EFFECT_TYPE_SINGLE)
							im:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
							im:SetCode(EFFECT_IMMUNE_EFFECT)
							im:SetValue(function(_,te) return te==ef end)
							im:SetReset(RESET_EVENT|RESETS_STANDARD)
							tc:RegisterEffect(im)
						end
					end
				end
				if found then st.gain=st.gain+math.abs(a0-tc:GetAttack())+math.abs(d0-tc:GetDefense()) end
			end
		end
		if st.gain>0 then
			Duel.Hint(HINT_CARD,0,id)
			Duel.Recover(tp,st.gain,REASON_EFFECT)
		end
	end)
	Duel.RegisterEffect(e2,tp)
	--Safety: never leave the patch on after the chain
	local e3=e1:Clone()
	e3:SetCode(EVENT_CHAIN_END)
	e3:SetOperation(function() unpatch() end)
	Duel.RegisterEffect(e3,tp)
end

--Script: 4RMAss · Anime Server by 4RMAss
--Elegant Egotist (Anime)
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	--activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
function s.cfilter(c)
	return c:IsFaceup() and c:IsSetCard(0x64) and c:IsType(TYPE_MONSTER)
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_MZONE,0,1,nil)
end
function s.tgfilter(c)
	return c:IsFaceup() and c:IsSetCard(0x64) and c:IsType(TYPE_MONSTER)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.tgfilter(chkc) end
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingTarget(s.tgfilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,s.tgfilter,tp,LOCATION_MZONE,0,1,1,nil)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) or not tc:IsFaceup() then return end
	local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
	if ft<=0 then return end
	local num=math.min(ft,2)
	local code=tc:GetOriginalCode()
	local tokens={}
	for i=1,num do
		if Duel.IsPlayerCanSpecialSummonMonster(tp,code,0x64,0x4011,tc:GetBaseAttack(),tc:GetBaseDefense(),tc:GetLevel(),tc:GetRace(),tc:GetAttribute()) then
			local token=Duel.CreateToken(tp,code)
			Duel.SpecialSummonStep(token,0,tp,tp,false,false,POS_FACEUP)
			tokens[#tokens+1]=token
		end
	end
	Duel.SpecialSummonComplete()
	--cannot attack this turn (target + summoned)
	local g=Group.CreateGroup()
	g:AddCard(tc)
	for _,t in ipairs(tokens) do g:AddCard(t) end
	local tcg=g:GetFirst()
	while tcg do
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_CANNOT_ATTACK)
		e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
		tcg:RegisterEffect(e1)
		tcg=g:GetNext()
	end
end

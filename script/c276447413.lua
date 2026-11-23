--Nightmare Tri-Mirror (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOKEN)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCondition(function(e,tp) return Duel.GetFlagEffect(1-tp,id)>0 end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	aux.GlobalCheck(s,function()
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_SPSUMMON_SUCCESS)
		ge1:SetOperation(s.checkop)
		Duel.RegisterEffect(ge1,0)
		local ge2=ge1:Clone()
		ge2:SetCode(EVENT_FLIP_SUMMON_SUCCESS)
		Duel.RegisterEffect(ge2,0)
	end)
end
s.token=276447441
function s.checkop(e,tp,eg,ep,ev,re,r,rp)
	for tc in eg:Iter() do
		Duel.RegisterFlagEffect(tc:GetSummonPlayer(),id,RESET_PHASE|PHASE_END,0,1)
	end
end
function s.cancopy(tc,tp)
	return Duel.IsPlayerCanSpecialSummonMonster(tp,s.token,0,TYPES_TOKEN,tc:GetTextAttack(),tc:GetTextDefense(),
		tc:GetOriginalLevel(),tc:GetOriginalRace(),tc:GetOriginalAttribute())
end
function s.filter(c,tp)
	return c:IsFaceup() and c:GetOriginalLevel()>0 and s.cancopy(c,tp)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.filter(chkc,tp) end
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingTarget(s.filter,tp,LOCATION_MZONE,0,1,nil,tp) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,s.filter,tp,LOCATION_MZONE,0,1,1,nil,tp)
	Duel.SetOperationInfo(0,CATEGORY_TOKEN,nil,1,0,0)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if not tc:IsRelateToEffect(e) or tc:IsFacedown() or not s.cancopy(tc,tp) then return end
	local ct=math.min(Duel.GetFlagEffect(1-tp,id),Duel.GetLocationCount(tp,LOCATION_MZONE))
	if ct>1 and Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ct=1 end
	local reset=RESET_EVENT|(RESETS_STANDARD&~RESET_TOFIELD)
	for i=1,ct do
		local token=Duel.CreateToken(tp,s.token)
		local vals={{EFFECT_SET_BASE_ATTACK,tc:GetTextAttack()},{EFFECT_SET_BASE_DEFENSE,tc:GetTextDefense()},
			{EFFECT_CHANGE_LEVEL,tc:GetOriginalLevel()},{EFFECT_CHANGE_RACE,tc:GetOriginalRace()},{EFFECT_CHANGE_ATTRIBUTE,tc:GetOriginalAttribute()}}
		for _,v in ipairs(vals) do
			local e1=Effect.CreateEffect(c)
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(v[1])
			e1:SetValue(v[2])
			e1:SetReset(reset)
			token:RegisterEffect(e1,true)
		end
		if Duel.SpecialSummonStep(token,0,tp,tp,false,false,POS_FACEUP) then
			local e2=Effect.CreateEffect(c)
			e2:SetDescription(3206)
			e2:SetType(EFFECT_TYPE_SINGLE)
			e2:SetProperty(EFFECT_FLAG_CLIENT_HINT)
			e2:SetCode(EFFECT_CANNOT_ATTACK)
			e2:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
			token:RegisterEffect(e2,true)
		end
	end
	Duel.SpecialSummonComplete()
end

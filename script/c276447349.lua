--Joyful Doom (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.atk(tc)
	local atk=0
	for mc in tc:GetMaterial():Iter() do atk=atk+math.max(mc:GetPreviousAttackOnField(),0) end
	return atk
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	local tc=eg:GetFirst()
	return ep==1-tp and tc:IsSummonType(SUMMON_TYPE_TRIBUTE) and #tc:GetMaterial()>0
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local atk=s.atk(eg:GetFirst())
	if chk==0 then return true end
	Duel.SetTargetPlayer(tp)
	Duel.SetTargetParam(atk)
	Duel.SetOperationInfo(0,CATEGORY_RECOVER,nil,0,tp,atk)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local p,d=Duel.GetChainInfo(0,CHAININFO_TARGET_PLAYER,CHAININFO_TARGET_PARAM)
	if d>0 then Duel.Recover(p,d,REASON_EFFECT) end
	--The ATK of the Tributed monsters is treated as 0: if the Summoned monster took its ATK from them
	--(e.g. "The Winged Dragon of Ra"), that ATK becomes 0
	local tc=eg:GetFirst()
	local sum=s.atk(tc)
	if sum<=0 or not (tc:IsFaceup() and tc:IsLocation(LOCATION_MZONE)) then return end
	local base=tc:GetBaseAttack()
	if base==tc:GetTextAttack() or base<sum then return end
	Duel.Hint(HINT_CARD,0,id)
	--Registered as the Summoned monster's own value, so it is not removed as another card's effect
	local e1=Effect.CreateEffect(tc)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_SET_BASE_ATTACK)
	e1:SetValue(base-sum)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD)
	tc:RegisterEffect(e1,true)
end

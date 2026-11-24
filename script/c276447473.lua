--Strain Spore (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Detect when this card becomes an Xyz Material (by Xyz Summon or attached by an effect)
	aux.GlobalCheck(s,function()
		s.seen={}
		local ge=Effect.GlobalEffect()
		ge:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge:SetCode(EVENT_ADJUST)
		ge:SetOperation(s.checkop)
		Duel.RegisterEffect(ge,0)
	end)
end
s.listed_names={276447474}
function s.checkop(e,tp,eg,ep,ev,re,r,rp)
	local now={}
	local g=Duel.GetOverlayGroup(0,1,1):Filter(Card.IsOriginalCode,nil,id)
	for c in g:Iter() do
		local xc=c:GetOverlayTarget()
		now[c]=xc
		if xc and s.seen[c]~=xc then
			s.seen[c]=xc
			s.apply(c,xc)
		end
	end
	for c in pairs(s.seen) do
		if not now[c] then s.seen[c]=nil end
	end
end

function s.apply(c,xc)
	local p=c:GetOwner()
	if Duel.GetLocationCount(p,LOCATION_MZONE)<=0
		or not Duel.IsPlayerCanSpecialSummonMonster(p,276447474,0,TYPES_TOKEN,0,0,1,RACE_FIEND,ATTRIBUTE_DARK) then return end
	Duel.Hint(HINT_CARD,0,id)
	local tk=Duel.CreateToken(p,276447474)
	if Duel.SpecialSummonStep(tk,0,p,p,false,false,POS_FACEUP_ATTACK) then
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_SET_BASE_ATTACK)
		e1:SetValue(math.max(xc:GetAttack(),0)+100)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)
		tk:RegisterEffect(e1,true)
	end
	Duel.SpecialSummonComplete()
end

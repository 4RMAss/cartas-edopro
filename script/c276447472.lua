--Strain Nuke (Manga)
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
	Duel.Hint(HINT_CARD,0,id)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_ATTACK_ALL)
	e1:SetTargetRange(LOCATION_MZONE,0)
	e1:SetTarget(function(e,tc) return tc:IsCode(276447474) end)
	e1:SetValue(1)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,p)
end

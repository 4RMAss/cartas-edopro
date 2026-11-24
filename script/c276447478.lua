--Performage Stilts Launcher (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Special Summon from the hand
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetCondition(function(e,c)
		if c==nil then return true end
		local tp=c:GetControler()
		return Duel.GetLocationCount(tp,LOCATION_MZONE)>0 and Duel.GetFieldGroupCount(tp,LOCATION_MZONE,LOCATION_MZONE)==0
	end)
	e1:SetOperation(function(e,tp)
		local e2=Effect.CreateEffect(e:GetHandler())
		e2:SetType(EFFECT_TYPE_FIELD)
		e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_OATH)
		e2:SetCode(EFFECT_CANNOT_SUMMON)
		e2:SetTargetRange(1,0)
		e2:SetReset(RESET_PHASE|PHASE_END)
		Duel.RegisterEffect(e2,tp)
		local e3=e2:Clone()
		e3:SetCode(EFFECT_CANNOT_MSET)
		Duel.RegisterEffect(e3,tp)
	end)
	c:RegisterEffect(e1)
	--Spell damage becomes the highest effect damage you took this turn
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,0))
	e4:SetType(EFFECT_TYPE_QUICK_O)
	e4:SetCode(EVENT_CHAINING)
	e4:SetRange(LOCATION_GRAVE)
	e4:SetCondition(s.damcon)
	e4:SetCost(Cost.SelfBanish)
	e4:SetOperation(s.damop)
	c:RegisterEffect(e4)
	aux.GlobalCheck(s,function()
		s.maxdam={[0]=0,[1]=0}
		s.turn=0
		local ge=Effect.GlobalEffect()
		ge:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge:SetCode(EVENT_DAMAGE)
		ge:SetOperation(function(_,_,_,dep,dev,_,dr)
			if s.turn~=Duel.GetTurnCount() then s.turn=Duel.GetTurnCount() s.maxdam={[0]=0,[1]=0} end
			if dr&REASON_EFFECT~=0 and dev>s.maxdam[dep] then s.maxdam[dep]=dev end
		end)
		Duel.RegisterEffect(ge,0)
	end)
end
function s.took(tp)
	return s.turn==Duel.GetTurnCount() and s.maxdam[tp] or 0
end
function s.damcon(e,tp,eg,ep,ev,re,r,rp)
	return rp==tp and re:IsHasType(EFFECT_TYPE_ACTIVATE) and re:IsActiveType(TYPE_SPELL)
		and aux.damcon1(e,1-tp,eg,ep,ev,re,r,rp) and s.took(tp)>0
end
function s.damop(e,tp,eg,ep,ev,re,r,rp)
	local val=s.took(tp)
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CHANGE_DAMAGE)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetTargetRange(0,1)
	e1:SetLabel(Duel.GetChainInfo(ev,CHAININFO_CHAIN_ID))
	e1:SetValue(function(e,re,dval,r,rp,rc)
		if Duel.GetCurrentChain()==0 or r&REASON_EFFECT==0 then return dval end
		return Duel.GetChainInfo(0,CHAININFO_CHAIN_ID)==e:GetLabel() and val or dval
	end)
	e1:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e1,tp)
end

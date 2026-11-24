--Power Shackle (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	--All monster effects are negated
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_DISABLE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetTarget(function(e,c) return c:IsType(TYPE_EFFECT) and c:GetFlagEffect(id)==0 end)
	c:RegisterEffect(e2)
	--Pay 500 LP to use the effects of a monster
	local eq=Effect.CreateEffect(c)
	eq:SetDescription(aux.Stringid(id,0))
	eq:SetType(EFFECT_TYPE_QUICK_O)
	eq:SetCode(EVENT_FREE_CHAIN)
	eq:SetRange(LOCATION_MZONE)
	eq:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	eq:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)==0 end)
	eq:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.CheckLPCost(tp,500) end
		Duel.PayLPCost(tp,500)
	end)
	eq:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) and c:IsFaceup() then
			c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,EFFECT_FLAG_CLIENT_HINT,1,0,aux.Stringid(id,1))
			Duel.AdjustInstantly(c)
		end
	end)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e3:SetRange(LOCATION_SZONE)
	e3:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e3:SetTarget(function(e,c) return c:IsFaceup() and c:IsType(TYPE_EFFECT) end)
	e3:SetLabelObject(eq)
	c:RegisterEffect(e3)
end

--Ancient Gear Fist (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Equip Spell: it stays equipped after its effect is used
	aux.AddEquipProcedure(c,0,nil,nil,nil,nil,s.activate,function() return Duel.IsPhase(PHASE_MAIN1) end)
	aux.GlobalCheck(s,function()
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_BATTLED)
		ge1:SetOperation(function()
			local a,d=Duel.GetAttacker(),Duel.GetAttackTarget()
			if a then Duel.RegisterFlagEffect(a:GetControler(),id,RESET_PHASE|PHASE_END,0,1) end
			if d then Duel.RegisterFlagEffect(d:GetControler(),id,RESET_PHASE|PHASE_END,0,1) end
		end)
		Duel.RegisterEffect(ge1,0)
	end)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.GetFlagEffect(tp,id)>0 and Duel.IsExistingMatchingCard(aux.TRUE,tp,0,LOCATION_MZONE,1,nil) end)
	e1:SetOperation(s.desop)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.SelectYesNo(tp,aux.Stringid(id,0)) then return end
	Duel.Hint(HINT_CARD,0,id)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
	local g=Duel.SelectMatchingCard(tp,aux.TRUE,tp,0,LOCATION_MZONE,1,1,nil)
	if #g>0 then
		Duel.HintSelection(g)
		Duel.Destroy(g,REASON_EFFECT)
	end
end

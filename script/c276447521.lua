--Performapal Barracuda (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	Pendulum.AddProcedure(c)
	--marker so the global check can find this card (its code is the alias)
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_SINGLE_RANGE+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetRange(LOCATION_PZONE|LOCATION_MZONE)
	e0:SetCode(id)
	c:RegisterEffect(e0)
	aux.GlobalCheck(s,function()
		s.last={}
		local ge=Effect.GlobalEffect()
		ge:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge:SetCode(EVENT_ADJUST)
		ge:SetOperation(s.adjop)
		Duel.RegisterEffect(ge,0)
	end)
end
s.listed_series={SET_PERFORMAPAL}
function s.boost(tc,da,dd,rc)
	if da~=0 then
		local e1=Effect.CreateEffect(rc)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(da)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)
		tc:RegisterEffect(e1,true)
	end
	if dd~=0 then
		local e2=Effect.CreateEffect(rc)
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_UPDATE_DEFENSE)
		e2:SetValue(dd)
		e2:SetReset(RESET_EVENT|RESETS_STANDARD)
		tc:RegisterEffect(e2,true)
	end
end
function s.adjop(e,tp,eg,ep,ev,re,r,rp)
	if s.busy then return end
	s.busy=true
	local cur={}
	for tc in Duel.GetMatchingGroup(Card.IsFaceup,0,LOCATION_MZONE,LOCATION_MZONE,nil):Iter() do
		local a,d=tc:GetAttack(),tc:GetDefense()
		local old=s.last[tc]
		if old and old[3]==tc:GetFieldID() and (a~=old[1] or d~=old[2]) then
			local da,dd=a-old[1],d-old[2]
			local p=tc:GetControler()
			local pz=Duel.GetMatchingGroup(function(bc) return bc:IsHasEffect(id) and not bc:IsDisabled() end,1-p,LOCATION_PZONE,0,nil):GetFirst()
			if pz then
				Duel.Hint(HINT_CARD,0,id)
				s.boost(tc,da,dd,pz)
				a,d=a+da,d+dd
			elseif da~=0 and tc:IsSetCard(SET_PERFORMAPAL) then
				local mz=Duel.GetMatchingGroup(function(bc) return bc:IsHasEffect(id) and bc:IsFaceup() and not bc:IsDisabled() and bc:GetFlagEffect(id)==0 end,p,LOCATION_MZONE,0,nil):GetFirst()
				if mz then
					mz:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1)
					Duel.Hint(HINT_CARD,0,id)
					s.boost(tc,da,0,mz)
					a=a+da
				end
			end
		end
		cur[tc]={a,d,tc:GetFieldID()}
	end
	s.last=cur
	s.busy=false
end

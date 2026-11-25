--D/D Count Surveyor (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	Pendulum.AddProcedure(c)
	--Los monstruos del rival tienen como ATK/DEF la suma del ATK/DEF de todos ellos
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SET_ATTACK_FINAL)
	e1:SetRange(LOCATION_PZONE)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetTarget(s.sumtg)
	e1:SetValue(s.atkval)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_SET_DEFENSE_FINAL)
	e2:SetValue(s.defval)
	c:RegisterEffect(e2)
	--Solo 1 de ellos puede atacar por turno
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
	e3:SetRange(LOCATION_PZONE)
	e3:SetTargetRange(0,LOCATION_MZONE)
	e3:SetCondition(function(e) return Duel.GetActivityCount(1-e:GetHandlerPlayer(),ACTIVITY_ATTACK)>0 end)
	e3:SetTarget(function(e,c) return c:GetAttackAnnouncedCount()==0 end)
	c:RegisterEffect(e3)
	--Si uno de ellos deja el campo, se destruyen los demás
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_LEAVE_FIELD_P)
	e4:SetRange(LOCATION_PZONE)
	e4:SetOperation(s.markop)
	c:RegisterEffect(e4)
	local e5=Effect.CreateEffect(c)
	e5:SetDescription(aux.Stringid(id,0))
	e5:SetCategory(CATEGORY_DESTROY)
	e5:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e5:SetCode(EVENT_LEAVE_FIELD)
	e5:SetRange(LOCATION_PZONE)
	e5:SetCondition(s.descon)
	e5:SetTarget(s.destg)
	e5:SetOperation(s.desop)
	c:RegisterEffect(e5)
	e4:SetLabelObject(e5)
	e5:SetLabelObject(e5)
end
--Mientras se calcula la suma, este efecto no se aplica (así se suma el ATK/DEF que tiene cada uno sin él)
s.busy=false
function s.sumtg(e,c)
	return not s.busy and c:IsFaceup()
end
function s.sum(e,f)
	s.busy=true
	local v=Duel.GetMatchingGroup(Card.IsFaceup,e:GetHandlerPlayer(),0,LOCATION_MZONE,nil):GetSum(f)
	s.busy=false
	return v
end
function s.atkval(e,c) return s.sum(e,Card.GetAttack) end
function s.defval(e,c) return s.sum(e,Card.GetDefense) end
--Los que destruye este mismo efecto no vuelven a activarlo (así no se destruyen los que llegaron después)
function s.leftfilter(c,tp,se)
	return c:IsControler(1-tp) and c:IsLocation(LOCATION_MZONE) and c:GetReasonEffect()~=se
end
function s.markop(e,tp,eg,ep,ev,re,r,rp)
	if not eg:IsExists(s.leftfilter,1,nil,tp,e:GetLabelObject()) then return end
	local g=Duel.GetMatchingGroup(aux.TRUE,tp,0,LOCATION_MZONE,eg)
	for tc in g:Iter() do
		tc:RegisterFlagEffect(id,RESET_EVENT|RESET_TOFIELD|RESET_LEAVE|RESET_TEMP_REMOVE|RESET_PHASE|PHASE_END,0,1)
	end
end
function s.prevfilter(c,tp,se)
	return c:IsPreviousLocation(LOCATION_MZONE) and c:IsPreviousControler(1-tp) and c:GetReasonEffect()~=se
end
function s.desfilter(c)
	return c:GetFlagEffect(id)>0
end
function s.descon(e,tp,eg,ep,ev,re,r,rp)
	return eg:IsExists(s.prevfilter,1,nil,tp,e:GetLabelObject())
end
function s.destg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	local g=Duel.GetMatchingGroup(s.desfilter,tp,0,LOCATION_MZONE,nil)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetMatchingGroup(s.desfilter,tp,0,LOCATION_MZONE,nil)
	for tc in g:Iter() do tc:ResetFlagEffect(id) end
	if #g>0 then Duel.Destroy(g,REASON_EFFECT) end
end

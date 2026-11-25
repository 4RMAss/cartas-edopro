--Second Reflector (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_ATTACK_ANNOUNCE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	aux.GlobalCheck(s,function()
		s.rec={}
		s.turn=-1
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_ATTACK_ANNOUNCE)
		ge1:SetOperation(s.record)
		Duel.RegisterEffect(ge1,0)
	end)
end
function s.record(e,tp,eg,ep,ev,re,r,rp)
	local a=Duel.GetAttacker()
	if not a then return end
	if s.turn~=Duel.GetTurnCount() then s.rec={} s.turn=Duel.GetTurnCount() end
	table.insert(s.rec,{a:GetFieldID(),a:GetAttack()})
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	local a=Duel.GetAttacker()
	if not (a and a:IsControler(1-tp) and s.turn==Duel.GetTurnCount()) then return false end
	local fid,atk=a:GetFieldID(),a:GetAttack()
	for _,v in ipairs(s.rec) do
		if v[1]~=fid and v[2]==atk then return true end
	end
	return false
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local a=Duel.GetAttacker()
	if chkc then return chkc==a end
	if chk==0 then return a:IsOnField() and a:IsCanBeEffectTarget(e) end
	Duel.SetTargetCard(a)
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,math.max(a:GetAttack(),0))
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if Duel.NegateAttack() and tc and tc:IsRelateToEffect(e) and tc:IsFaceup() then
		Duel.Damage(1-tp,math.max(tc:GetAttack(),0),REASON_EFFECT)
	end
end

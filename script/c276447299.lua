--Heroic Retribution Sword (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_EQUIP)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_BATTLE_DESTROYED)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--Destroy the first target at the start of the Damage Step
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_DESTROY+CATEGORY_DAMAGE)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_BATTLE_START)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCondition(s.descon)
	e2:SetOperation(s.desop)
	c:RegisterEffect(e2)
	--Destroy this card when the first target leaves the field
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_LEAVE_FIELD)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCondition(s.sdcon)
	e3:SetOperation(function(e) Duel.Destroy(e:GetHandler(),REASON_EFFECT) end)
	c:RegisterEffect(e3)
end
s.listed_series={SET_HEROIC_CHALLENGER}
function s.cfilter(c,tp)
	return c:IsPreviousControler(tp) and c:IsLocation(LOCATION_GRAVE) and c:IsSetCard(SET_HEROIC_CHALLENGER)
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	local tc=eg:Filter(s.cfilter,nil,tp):GetFirst()
	if not tc then return false end
	local rc=tc:GetReasonCard()
	e:SetLabelObject(rc)
	return rc and rc:IsControler(1-tp) and rc:IsOnField() and rc:IsRelateToBattle()
end
function s.eqfilter(c)
	return c:IsFaceup() and c:IsSetCard(SET_HEROIC_CHALLENGER)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return false end
	local rc=e:GetLabelObject()
	if chk==0 then return rc and rc:IsCanBeEffectTarget(e)
		and Duel.IsExistingTarget(s.eqfilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.SetTargetCard(rc)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_EQUIP)
	local g=Duel.SelectTarget(tp,s.eqfilter,tp,LOCATION_MZONE,0,1,1,nil)
	e:SetLabelObject(g:GetFirst())
	Duel.SetOperationInfo(0,CATEGORY_EQUIP,e:GetHandler(),1,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ec=e:GetLabelObject()
	local g=Duel.GetTargetCards(e)
	local bc=g:Filter(aux.TRUE,ec):GetFirst()
	if not c:IsRelateToEffect(e) or not ec or not g:IsContains(ec) or ec:IsFacedown() or not bc then return end
	if Duel.Equip(tp,c,ec) then
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_EQUIP_LIMIT)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)
		e1:SetValue(function(e,cc) return cc==ec end)
		c:RegisterEffect(e1)
		c:SetCardTarget(bc)
	end
end
function s.descon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local ec=c:GetEquipTarget()
	local bc=c:GetFirstCardTarget()
	if not ec or not bc then return false end
	local a,d=Duel.GetAttacker(),Duel.GetAttackTarget()
	return (a==ec and d==bc) or (a==bc and d==ec)
end
function s.desop(e,tp,eg,ep,ev,re,r,rp)
	local bc=e:GetHandler():GetFirstCardTarget()
	if not bc or not bc:IsRelateToBattle() then return end
	local atk=math.max(bc:GetAttack(),0)
	if Duel.Destroy(bc,REASON_EFFECT)>0 then
		Duel.Damage(1-tp,atk,REASON_EFFECT)
	end
end
function s.sdcon(e,tp,eg,ep,ev,re,r,rp)
	local bc=e:GetHandler():GetFirstCardTarget()
	return bc and eg:IsContains(bc)
end

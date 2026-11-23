--Heroic Challenger - War Hammer (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--Cannot be Special Summoned
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetCode(EFFECT_SPSUMMON_CONDITION)
	e0:SetValue(aux.FALSE)
	c:RegisterEffect(e0)
	--Destroy all Equip Cards, then equip the destroyed monster
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY+CATEGORY_EQUIP)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCondition(aux.bdgcon)
	e1:SetOperation(s.eqop)
	c:RegisterEffect(e1)
	--Gains ATK equal to the ATK of the monsters equipped to it
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetCode(EFFECT_UPDATE_ATTACK)
	e2:SetRange(LOCATION_MZONE)
	e2:SetValue(s.atkval)
	c:RegisterEffect(e2)
end
function s.atkval(e,c)
	local atk=0
	for tc in c:GetEquipGroup():Iter() do
		if tc:GetOriginalType()&TYPE_MONSTER~=0 and tc:GetTextAttack()>0 then atk=atk+tc:GetTextAttack() end
	end
	return atk
end
function s.eqop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local bc=c:GetBattleTarget()
	local eqg=c:GetEquipGroup()
	if #eqg>0 then Duel.Destroy(eqg,REASON_EFFECT) end
	if not (c:IsRelateToBattle() and c:IsFaceup() and bc and bc:IsLocation(LOCATION_GRAVE)) then return end
	if Duel.GetLocationCount(tp,LOCATION_SZONE)<=0 or bc:IsForbidden() then return end
	if not Duel.SelectYesNo(tp,aux.Stringid(id,1)) then return end
	Duel.BreakEffect()
	if Duel.Equip(tp,bc,c,false) then
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
		e1:SetCode(EFFECT_EQUIP_LIMIT)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)
		e1:SetValue(function(e,cc) return e:GetOwner()==cc end)
		bc:RegisterEffect(e1)
	end
end

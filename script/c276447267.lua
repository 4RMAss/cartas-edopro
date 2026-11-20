--超重武者装留ダブル・ホーン
--Superheavy Samurai Soulhorns (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en los scripts oficiales de Project Ignis (EDOPro), con licencia AGPL-3.0.
local s,id=GetID()
function s.initial_effect(c)
	--Equip / unequip
	s.soulproc(c,LOCATION_MZONE,POS_FACEUP_DEFENSE,true)
end
s.listed_series={SET_SUPERHEAVY_SAMURAI}
function s.eqbonus(c,tc)
	--While you have no Spells/Traps in your GY, it can make a second attack during each Battle Phase
	local e1=s.equipeff(c,EFFECT_EXTRA_ATTACK,1)
	e1:SetCondition(function(e)
		return not Duel.IsExistingMatchingCard(Card.IsSpellTrap,e:GetHandlerPlayer(),LOCATION_GRAVE,0,1,nil)
	end)
end

---------------------------------------------------------------------------
--Anime "Superheavy Samurai" Soul monsters: once per turn, either equip this card to a
--"Superheavy Samurai" monster you control, or unequip it and Special Summon it
---------------------------------------------------------------------------
function s.soulproc(c,range,sppos,once)
	s.sppos=sppos
	s.once=once
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_EQUIP)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetRange(range)
	e1:SetTarget(s.eqtg)
	e1:SetOperation(s.eqop)
	c:RegisterEffect(e1)
end
function s.eqfilter(c)
	return c:IsFaceup() and c:IsSetCard(SET_SUPERHEAVY_SAMURAI)
end
function s.usedturn(c)
	return s.once and c:GetFlagEffect(id)>0
end
function s.markturn(c)
	if s.once then
		c:RegisterFlagEffect(id,RESET_EVENT+(RESETS_STANDARD-RESET_TOFIELD-RESET_LEAVE)+RESET_PHASE+PHASE_END,0,1)
	end
end
function s.eqtg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local c=e:GetHandler()
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and chkc~=c and s.eqfilter(chkc) end
	if chk==0 then return not s.usedturn(c) and Duel.GetLocationCount(tp,LOCATION_SZONE)>0
		and Duel.IsExistingTarget(s.eqfilter,tp,LOCATION_MZONE,0,1,c) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_EQUIP)
	local g=Duel.SelectTarget(tp,s.eqfilter,tp,LOCATION_MZONE,0,1,1,c)
	Duel.SetOperationInfo(0,CATEGORY_EQUIP,g,1,0,0)
	s.markturn(c)
end
function s.eqop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) or (c:IsLocation(LOCATION_MZONE) and c:IsFacedown()) then return end
	local tc=Duel.GetFirstTarget()
	if Duel.GetLocationCount(tp,LOCATION_SZONE)<=0 or not tc or tc:IsControler(1-tp) or tc:IsFacedown()
		or not tc:IsRelateToEffect(e) then
		Duel.SendtoGrave(c,REASON_EFFECT)
		return
	end
	if not Duel.Equip(tp,c,tc,true) then return end
	--Equip limit
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_EQUIP_LIMIT)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetReset(RESET_EVENT|RESETS_STANDARD)
	e1:SetValue(s.eqlimit)
	e1:SetLabelObject(tc)
	c:RegisterEffect(e1)
	--Unequip it and Special Summon it
	if s.sppos then
		local e2=Effect.CreateEffect(c)
		e2:SetDescription(aux.Stringid(id,1))
		e2:SetCategory(CATEGORY_SPECIAL_SUMMON)
		e2:SetType(EFFECT_TYPE_IGNITION)
		e2:SetRange(LOCATION_SZONE)
		e2:SetCondition(function(e) return e:GetHandler():GetEquipTarget()~=nil end)
		e2:SetTarget(s.untg)
		e2:SetOperation(s.unop)
		e2:SetReset(RESET_EVENT|RESETS_STANDARD)
		c:RegisterEffect(e2)
	end
	s.eqbonus(c,tc)
end
function s.eqlimit(e,c)
	return c==e:GetLabelObject()
end
function s.untg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then return not s.usedturn(c) and Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and c:IsCanBeSpecialSummoned(e,0,tp,false,false,s.sppos) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,c,1,0,0)
	s.markturn(c)
end
function s.unop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) then
		Duel.SpecialSummon(c,0,tp,tp,false,false,s.sppos)
	end
end
--Equip effect that only applies while equipped by this card's effect
function s.equipeff(c,code,value)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(code)
	if value~=nil then e1:SetValue(value) end
	e1:SetReset(RESET_EVENT|RESETS_STANDARD)
	c:RegisterEffect(e1)
	return e1
end

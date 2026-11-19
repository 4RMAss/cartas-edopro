--Script: 4RMAss · Anime Server by 4RMAss
--The Seal of Orichalcos (Anime)
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
if not Card.ListsCode then
function Card.ListsCode(c,...) return false end
end
local FLAG_MOVED=id  -- marca para monstruos movidos a la zona S/T por este efecto
function s.initial_effect(c)
	--activate (once per duel)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetCountLimit(1,id+100000000,EFFECT_COUNT_CODE_DUEL)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--cannot be destroyed by card effects
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e2:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
	e2:SetValue(1)
	c:RegisterEffect(e2)
	--cannot be negated
	local e2b=Effect.CreateEffect(c)
	e2b:SetType(EFFECT_TYPE_SINGLE)
	e2b:SetCode(EFFECT_CANNOT_DISABLE)
	c:RegisterEffect(e2b)
	local e2c=e2b:Clone()
	e2c:SetCode(EFFECT_CANNOT_DISEFFECT)
	c:RegisterEffect(e2c)
	--your monsters gain 500 ATK
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetCode(EFFECT_UPDATE_ATTACK)
	e3:SetRange(LOCATION_SZONE)
	e3:SetTargetRange(LOCATION_MZONE,0)
	e3:SetValue(500)
	c:RegisterEffect(e3)
	--once per turn: move a monster MZONE<->SZONE (bidireccional)
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,0))
	e4:SetType(EFFECT_TYPE_IGNITION)
	e4:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e4:SetRange(LOCATION_SZONE)
	e4:SetCountLimit(1,id)
	e4:SetCondition(s.movecon)
	e4:SetTarget(s.movetg)
	e4:SetOperation(s.moveop)
	c:RegisterEffect(e4)
	--when a monster you control is destroyed and you have none: resummon the moved ones
	local e5=Effect.CreateEffect(c)
	e5:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e5:SetCode(EVENT_DESTROYED)
	e5:SetRange(LOCATION_SZONE)
	e5:SetProperty(EFFECT_FLAG_DELAY)
	e5:SetCountLimit(1,id+1)
	e5:SetCondition(s.rescon)
	e5:SetOperation(s.resop)
	c:RegisterEffect(e5)
end
s.listed_names={170000151,170000152,170000153}
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	--destroy your cards that list the Legendary Dragons as Fusion Material
	local g=Duel.GetMatchingGroup(s.desfilter,tp,LOCATION_MZONE+LOCATION_SZONE,0,nil)
	if g:GetCount()>0 then
		Duel.Destroy(g,REASON_EFFECT)
	end
end
function s.desfilter(c)
	if not c.ListsCode then return false end
	return c:ListsCode(170000151) or c:ListsCode(170000152) or c:ListsCode(170000153)
end
--------- mover MZONE <-> SZONE (bidireccional) ----------
function s.movecon(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsMainPhase()
end
function s.movefilter(c)
	--puede mover: un monstruo en MZONE, o uno ya movido que esta en SZONE (para regresarlo)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER)
end
function s.movetg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsControler(tp) and s.movefilter(chkc)
		and (chkc:IsLocation(LOCATION_MZONE) or (chkc:IsLocation(LOCATION_SZONE) and chkc:GetFlagEffect(FLAG_MOVED)>0)) end
	if chk==0 then
		local mz=Duel.IsExistingTarget(s.mzfilter,tp,LOCATION_MZONE,0,1,nil) and Duel.GetLocationCount(tp,LOCATION_SZONE)>0
		local sz=Duel.IsExistingTarget(s.szfilter,tp,LOCATION_SZONE,0,1,nil) and Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		return mz or sz
	end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	Duel.SelectTarget(tp,s.anyfilter,tp,LOCATION_MZONE+LOCATION_SZONE,0,1,1,nil)
end
function s.mzfilter(c)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER) and c:IsLocation(LOCATION_MZONE)
end
function s.szfilter(c)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER) and c:IsLocation(LOCATION_SZONE) and c:GetFlagEffect(FLAG_MOVED)>0
end
function s.anyfilter(c)
	return s.mzfilter(c) or s.szfilter(c)
end
function s.moveop(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) or not tc:IsFaceup() then return end
	if tc:IsLocation(LOCATION_MZONE) then
		--mover a la zona S/T y marcarlo
		if Duel.GetLocationCount(tp,LOCATION_SZONE)>0 then
			Duel.MoveToField(tc,tp,tp,LOCATION_SZONE,POS_FACEUP,true)
			tc:RegisterFlagEffect(FLAG_MOVED,RESET_EVENT+RESETS_STANDARD,0,1)
		end
	else
		--regresar a la Main Monster Zone (inverso)
		if Duel.GetLocationCount(tp,LOCATION_MZONE)>0 then
			Duel.MoveToField(tc,tp,tp,LOCATION_MZONE,POS_FACEUP,true)
			tc:ResetFlagEffect(FLAG_MOVED)
		end
	end
end
--------- rescate: si un monstruo es destruido y no quedan, traer los movidos ----------
function s.rescon(e,tp,eg,ep,ev,re,r,rp)
	--se destruyo un monstruo tuyo Y ahora no tienes monstruos en MZONE Y hay movidos en SZONE
	return Duel.GetFieldGroupCount(tp,LOCATION_MZONE,0)==0
		and Duel.IsExistingMatchingCard(s.szfilter,tp,LOCATION_SZONE,0,1,nil)
end
function s.resop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetMatchingGroup(s.szfilter,tp,LOCATION_SZONE,0,nil)
	local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
	if ft<=0 then return end
	if g:GetCount()>ft then
		g=g:Select(tp,ft,ft,nil)
	end
	local tc=g:GetFirst()
	while tc do
		Duel.MoveToField(tc,tp,tp,LOCATION_MZONE,POS_FACEUP,true)
		tc:ResetFlagEffect(FLAG_MOVED)
		tc=g:GetNext()
	end
end

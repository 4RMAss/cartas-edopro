--Script: 4RMAss · Anime Server by 4RMAss
--The Seal of Orichalcos (Anime)
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
local FLAG_MOVED=id  -- marca para monstruos movidos a la zona S/T por este efecto
local FLAG_TURN=id+300  -- marca para monstruos ya movidos este turno (no se pueden volver a mover hasta el final del turno)
--"The Fang of Critias", "The Eye of Timaeus" y "The Claw of Hermos" (oficiales; las
--versiones Anime los llevan como alias, así que IsCode las reconoce también)
local CARD_CRITIAS,CARD_TIMAEUS,CARD_HERMOS=11082056,1784686,46232525
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
	--mover monstruos entre la Zona de Monstruos y la de Magia/Trampa, y el rescate
	s.addmove(c)
	--registro global: Critias y Hermos no guardan sus materiales en la carta que crean,
	--así que se apunta aquí qué cartas mandaron al Cementerio para crearla
	aux.GlobalCheck(s,function()
		s.matmap={}
		local ge1=Effect.GlobalEffect()
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_TO_GRAVE)
		ge1:SetOperation(s.pendop)
		Duel.RegisterEffect(ge1,0)
		local ge2=ge1:Clone()
		ge2:SetCode(EVENT_CHAIN_SOLVED)
		ge2:SetOperation(s.mapop)
		Duel.RegisterEffect(ge2,0)
		local ge3=Effect.GlobalEffect()
		ge3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge3:SetCode(EVENT_ADJUST)
		ge3:SetOperation(s.grantop)
		Duel.RegisterEffect(ge3,0)
	end)
end
s.listed_names={CARD_CRITIAS,CARD_TIMAEUS,CARD_HERMOS}
--efectos de mover monstruos MZONE<->SZONE y de rescate; también se le dan a
--"Orichalcos Deuteros" y "Orichalcos Tritos" mientras estén boca arriba en la Zona de Campo
function s.addmove(c,reset)
	--move a monster MZONE<->SZONE (bidireccional); cada monstruo solo 1 vez por turno
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,0))
	e4:SetType(EFFECT_TYPE_IGNITION)
	e4:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e4:SetRange(LOCATION_SZONE)
	e4:SetCondition(s.movecon)
	e4:SetTarget(s.movetg)
	e4:SetOperation(s.moveop)
	if reset then e4:SetReset(reset) end
	c:RegisterEffect(e4)
	--when a monster you control is destroyed and you have none: resummon the moved ones
	local e5=Effect.CreateEffect(c)
	e5:SetDescription(aux.Stringid(id,1))
	e5:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e5:SetCode(EVENT_DESTROYED)
	e5:SetRange(LOCATION_SZONE)
	e5:SetProperty(EFFECT_FLAG_DELAY)
	e5:SetCountLimit(1,id+1)
	e5:SetCondition(s.rescon)
	e5:SetOperation(s.resop)
	if reset then e5:SetReset(reset) end
	c:RegisterEffect(e5)
end
--"Orichalcos Deuteros" y "Orichalcos Tritos" copian el script del Sello oficial, que no
--tiene estos efectos; aquí se les añaden cuando están boca arriba en la Zona de Campo
local CARD_DEUTEROS,CARD_TRITOS=110000100,110000101
local FLAG_GRANTED=id+200
function s.upfilter(c)
	return c:IsFaceup() and c:IsCode(CARD_DEUTEROS,CARD_TRITOS) and c:GetFlagEffect(FLAG_GRANTED)==0
end
function s.grantop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetMatchingGroup(s.upfilter,0,LOCATION_FZONE,LOCATION_FZONE,nil)
	for tc in g:Iter() do
		tc:RegisterFlagEffect(FLAG_GRANTED,RESET_EVENT|RESETS_STANDARD,0,1)
		s.addmove(tc,RESET_EVENT|RESETS_STANDARD)
	end
end
function s.isdragon(c)
	return c:IsCode(CARD_CRITIAS,CARD_TIMAEUS,CARD_HERMOS)
end
--¿la carta lleva a Timaeus, Critias o Hermos como Material de Fusión?
--(lista de materiales del script, o las marcas que usan Critias y Hermos)
function s.desfilter(c)
	if c.material_trap or c.hermos_filter then return true end
	return c:ListsCodeAsMaterial(CARD_CRITIAS,CARD_TIMAEUS,CARD_HERMOS)
end
------- registro de materiales de Critias / Hermos -------
function s.pendop(e,tp,eg,ep,ev,re,r,rp)
	if not re then return end
	local rc=re:GetHandler()
	if not rc or not s.isdragon(rc) then return end
	local g=eg:Filter(function(c) return c~=rc end,nil)
	if #g==0 then return end
	if s.pending then s.pending:DeleteGroup() end
	g:KeepAlive()
	s.pending=g
	s.pending_rc=rc
end
function s.newfusfilter(c)
	return c:IsPreviousLocation(LOCATION_EXTRA) and c:GetTurnID()==Duel.GetTurnCount()
		and s.desfilter(c) and not s.matmap[c:GetFieldID()]
end
function s.mapop(e,tp,eg,ep,ev,re,r,rp)
	if not s.pending or not re or re:GetHandler()~=s.pending_rc then return end
	local g=Duel.GetMatchingGroup(s.newfusfilter,0,LOCATION_ONFIELD,LOCATION_ONFIELD,nil)
	for tc in g:Iter() do
		local mg=s.pending:Clone()
		mg:KeepAlive()
		s.matmap[tc:GetFieldID()]=mg
	end
	s.pending:DeleteGroup()
	s.pending=nil
	s.pending_rc=nil
end
------- al activarse: destruir esas cartas y devolver el otro material -------
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local g=Duel.GetMatchingGroup(s.desfilter,tp,LOCATION_ONFIELD,0,c)
	if #g==0 then return end
	--antes de destruir, se apunta el otro Material de Fusión de cada una
	local mats=Group.CreateGroup()
	for tc in g:Iter() do
		local mg=tc:GetMaterial()
		if (not mg or #mg==0) and s.matmap then mg=s.matmap[tc:GetFieldID()] end
		if mg then
			for mc in mg:Iter() do
				if not s.isdragon(mc) then mats:AddCard(mc) end
			end
		end
	end
	if Duel.Destroy(g,REASON_EFFECT)==0 then return end
	--devolver al campo el otro Material de Fusión, si lo hay
	local mons=mats:Filter(s.retmonfilter,nil,e,tp)
	local sts=mats:Filter(s.retstfilter,nil)
	if #mons>0 then
		local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
		if ft>0 then
			if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ft=1 end
			if #mons>ft then
				Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
				mons=mons:Select(tp,ft,ft,nil)
			end
			Duel.BreakEffect()
			Duel.SpecialSummon(mons,0,tp,tp,true,false,POS_FACEUP)
		end
	end
	if #sts>0 and Duel.GetLocationCount(tp,LOCATION_SZONE)>0 then
		Duel.BreakEffect()
		Duel.SSet(tp,sts)
	end
end
function s.retmonfilter(c,e,tp)
	return c:IsLocation(LOCATION_GRAVE|LOCATION_REMOVED) and c:IsMonster()
		and (c:IsFaceup() or c:IsLocation(LOCATION_GRAVE))
		and c:IsCanBeSpecialSummoned(e,0,tp,true,false)
end
function s.retstfilter(c)
	return c:IsLocation(LOCATION_GRAVE|LOCATION_REMOVED) and c:IsSpellTrap()
		and (c:IsFaceup() or c:IsLocation(LOCATION_GRAVE)) and c:IsSSetable()
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
	if chkc then return chkc:IsControler(tp) and s.anyfilter(chkc) end
	if chk==0 then
		local mz=Duel.IsExistingTarget(s.mzmovefilter,tp,LOCATION_MZONE,0,1,nil) and Duel.GetLocationCount(tp,LOCATION_SZONE)>0
		local sz=Duel.IsExistingTarget(s.szmovefilter,tp,LOCATION_SZONE,0,1,nil) and Duel.GetLocationCount(tp,LOCATION_MZONE)>0
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
--un monstruo que ya se movió este turno no se puede volver a mover hasta el final del turno
function s.notmoved(c)
	return c:GetFlagEffect(FLAG_TURN)==0
end
function s.mzmovefilter(c)
	return s.mzfilter(c) and s.notmoved(c)
end
function s.szmovefilter(c)
	return s.szfilter(c) and s.notmoved(c)
end
function s.anyfilter(c)
	return s.mzmovefilter(c) or s.szmovefilter(c)
end
function s.markturn(c)
	c:RegisterFlagEffect(FLAG_TURN,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1)
end
function s.moveop(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) or not tc:IsFaceup() then return end
	if tc:IsLocation(LOCATION_MZONE) then
		--mover a la zona S/T y marcarlo
		if Duel.GetLocationCount(tp,LOCATION_SZONE)>0 then
			Duel.MoveToField(tc,tp,tp,LOCATION_SZONE,POS_FACEUP,true)
			tc:RegisterFlagEffect(FLAG_MOVED,RESET_EVENT+RESETS_STANDARD,0,1)
			s.markturn(tc)
		end
	else
		--regresar a la Main Monster Zone (inverso)
		if Duel.GetLocationCount(tp,LOCATION_MZONE)>0 then
			Duel.MoveToField(tc,tp,tp,LOCATION_MZONE,POS_FACEUP,true)
			tc:ResetFlagEffect(FLAG_MOVED)
			s.markturn(tc)
		end
	end
end
--------- rescate: si un monstruo es destruido y no quedan, traer los movidos ----------
function s.resdesfilter(c,tp)
	return c:IsPreviousLocation(LOCATION_MZONE) and c:IsPreviousControler(tp)
end
function s.rescon(e,tp,eg,ep,ev,re,r,rp)
	--se destruyó un monstruo tuyo Y ahora no tienes monstruos en MZONE Y hay movidos en SZONE
	return eg:IsExists(s.resdesfilter,1,nil,tp)
		and Duel.GetFieldGroupCount(tp,LOCATION_MZONE,0)==0
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
		s.markturn(tc)
		tc=g:GetNext()
	end
end

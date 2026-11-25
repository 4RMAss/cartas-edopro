--ラーの翼神竜 (Anime) - Formas
--The Winged Dragon of Ra (Anime Forms)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro) "The Winged Dragon of Ra (Anime)" (c511600400), con licencia AGPL-3.0.
--Tiene exactamente los efectos del Ra anime del juego (se cargan desde c511600400.lua) y además tres formas:
--  • Solo pueden usar sus efectos los jugadores que tenían originalmente una Bestia Divina en su Deck (su dueño
--    siempre puede, porque el propio Ra es su Bestia Divina).
--  • Forma 1 (600000240, esfera): al invocarlo por tributo, o si lo invoca un jugador que no puede usarlo. Para pasar
--    a la forma 2 la activa quien lo controla, si puede usarlo. Si la esfera está en el campo de un rival que no puede
--    usarlo, su dueño la recupera al activarlo en su turno.
--  • Forma 2 (600000239, la del juego base): la forma principal.
--  • Forma 3 (600000241, fénix): al resolver "Point-to-Point Transfer" o "Immortal Phoenix".
--  • "Point-to-Point Transfer" e "Immortal Phoenix" solo los puede usar quien lo controla, si puede usarlo, fuera de la forma 1.
--  • Sigue siendo "The Winged Dragon of Ra" para las reglas (alias 10000010) durante todo el duelo.
--  • Vuelve a la forma 2 al dejar el campo, al terminar el turno (desde la forma 3) y si "De-Fusion" le quita los efectos.
Duel.LoadCardScript("c511600400.lua")
local s,id=GetID()
local BASE=511600400
local FORM_SPHERE=id+1  --600000240: forma esfera
local FORM_PHOENIX=id+2 --600000241: forma fénix (Point-to-Point Transfer / Immortal Phoenix)
local RA_ALIAS=10000010 --"The Winged Dragon of Ra"

function s.initial_effect(c)
	--Todos los efectos del Ra anime del juego
	c511600400.initial_effect(c)
	for _,eff in ipairs({c:GetOwnEffects()}) do
		local d=eff:GetDescription()
		local con=eff:GetCondition()
		if d==aux.Stringid(BASE,0) or d==aux.Stringid(BASE,1) then
			--"Point-to-Point Transfer" e "Immortal Phoenix": solo quien puede usarlo, en su campo y fuera de la forma esfera
			eff:SetCondition(function(e,...) return s.canuse(e:GetHandler()) and (not con or con(e,...)) end)
		elseif eff:GetCode()==EFFECT_CANNOT_CHANGE_CONTROL then
			--Su control no puede cambiar, salvo cuando su dueño lo recupera con el cambio de forma
			eff:SetCondition(function(e,...) return not s.moving and (not con or con(e,...)) end)
		end
	end
	--Invocación por tributo: forma esfera
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetOperation(function(e) s.setform(e:GetHandler(),FORM_SPHERE) end)
	c:RegisterEffect(e1)
	--Invocación especial que no hizo un jugador que puede usarlo (en su propio campo): forma esfera
	local e2=e1:Clone()
	e2:SetCode(EVENT_SPSUMMON_SUCCESS)
	e2:SetCondition(function(e) return not s.worthysummon(e:GetHandler()) end)
	c:RegisterEffect(e2)
	--Pasar de la forma esfera a la forma principal (quien lo controla, si puede usarlo; si lo controla un rival que no puede usarlo, su dueño la recupera)
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,4))
	e3:SetType(EFFECT_TYPE_IGNITION)
	e3:SetRange(LOCATION_MZONE)
	e3:SetProperty(EFFECT_FLAG_BOTH_SIDE+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e3:SetCondition(function(e,tp)
		local c=e:GetHandler()
		return c:GetOriginalCode()==FORM_SPHERE and s.worthy(tp)
			and (c:IsControler(tp) or (tp==c:GetOwner() and not s.worthy(c:GetControler())))
	end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return c:IsControler(tp) or Duel.GetLocationCount(tp,LOCATION_MZONE)>0 end
	end)
	e3:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsFaceup() and c:GetOriginalCode()==FORM_SPHERE) then return end
		if not c:IsControler(tp) then
			s.moving=true
			Duel.GetControl(c,tp)
			s.moving=false
			if not c:IsControler(tp) then return end
		end
		s.revert(c)
	end)
	c:RegisterEffect(e3)
	--Forma fénix al resolver "Point-to-Point Transfer" o "Immortal Phoenix"
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_CHAIN_SOLVED)
	e4:SetRange(LOCATION_MZONE)
	e4:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e4:SetCondition(s.phoenixcon)
	e4:SetOperation(function(e) s.setform(e:GetHandler(),FORM_PHOENIX) end)
	c:RegisterEffect(e4)
	--Volver a la forma principal al dejar el campo
	local e5=Effect.CreateEffect(c)
	e5:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e5:SetCode(EVENT_LEAVE_FIELD_P)
	e5:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e5:SetCondition(function(e) local code=e:GetHandler():GetOriginalCode() return code==FORM_SPHERE or code==FORM_PHOENIX end)
	e5:SetOperation(function(e) s.revert(e:GetHandler()) end)
	c:RegisterEffect(e5)
	--Volver a la forma principal en la End Phase (los efectos de la forma fénix expiran)
	local e6=Effect.CreateEffect(c)
	e6:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e6:SetCode(EVENT_PHASE+PHASE_END)
	e6:SetRange(LOCATION_MZONE)
	e6:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e6:SetCondition(function(e) return e:GetHandler():GetOriginalCode()==FORM_PHOENIX end)
	e6:SetOperation(function(e) s.revert(e:GetHandler()) end)
	c:RegisterEffect(e6)
	--Volver a la forma principal si "De-Fusion" le quita los efectos de Point-to-Point Transfer
	local e7=Effect.CreateEffect(c)
	e7:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e7:SetCode(EVENT_ADJUST)
	e7:SetRange(LOCATION_MZONE)
	e7:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e7:SetCondition(function(e)
		local c=e:GetHandler()
		return c:GetOriginalCode()==FORM_PHOENIX and FLAG_RA_DEFUSION and c:HasFlagEffect(FLAG_RA_DEFUSION)
	end)
	e7:SetOperation(function(e) s.revert(e:GetHandler()) end)
	c:RegisterEffect(e7)
	--En la forma esfera no puede atacar
	local e8=Effect.CreateEffect(c)
	e8:SetType(EFFECT_TYPE_SINGLE)
	e8:SetProperty(EFFECT_FLAG_SINGLE_RANGE+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e8:SetCode(EFFECT_CANNOT_ATTACK)
	e8:SetRange(LOCATION_MZONE)
	e8:SetCondition(function(e) return e:GetHandler():GetOriginalCode()==FORM_SPHERE end)
	c:RegisterEffect(e8)
end
s.listed_names={RA_ALIAS,BASE}

--¿El jugador tenía originalmente una Bestia Divina en su Deck? (cartas suyas, en cualquier lugar, sin contar Tokens)
function s.divinefilter(c,p)
	return c:GetOwner()==p and not c:IsType(TYPE_TOKEN) and (c:GetOriginalRace()&RACE_DIVINE)~=0
end
function s.worthy(p)
	s.divine=s.divine or {}
	if s.divine[p]==nil then
		local g=Duel.GetMatchingGroup(s.divinefilter,0,LOCATION_ALL&~LOCATION_OVERLAY,LOCATION_ALL&~LOCATION_OVERLAY,nil,p)
		g:Merge(Duel.GetOverlayGroup(0,1,1):Filter(s.divinefilter,nil,p))
		s.divine[p]=#g>0
	end
	return s.divine[p]
end
--¿Lo invocó en su propio campo un jugador que puede usarlo?
function s.worthysummon(c)
	local p=c:GetSummonPlayer()
	return c:IsControler(p) and s.worthy(p)
end
--¿Puede usar "Point-to-Point Transfer" e "Immortal Phoenix"?
function s.canuse(c)
	return s.worthy(c:GetControler()) and c:GetOriginalCode()~=FORM_SPHERE
end
function s.phoenixcon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not (re and re:GetHandler()==c and c:IsFaceup()) then return false end
	local d=re:GetDescription()
	return d==aux.Stringid(BASE,0) or d==aux.Stringid(BASE,1)
end
--Cambia la imagen (código de datos) pero conserva el nombre y la identidad: "The Winged Dragon of Ra"
function s.setform(c,form)
	if c:GetOriginalCode()==form then return end
	c:Recreate(form,RA_ALIAS)
	Duel.AdjustInstantly(c)
end
--Vuelve a los datos e imagen de la forma principal (incluye su alias original)
function s.revert(c)
	if c:GetOriginalCode()==id then return end
	c:Recreate(id)
	Duel.AdjustInstantly(c)
end

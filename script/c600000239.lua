--ラーの翼神竜 (Anime) - Formas
--The Winged Dragon of Ra (Anime Forms)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro) "The Winged Dragon of Ra (Anime)" (c511600400), con licencia AGPL-3.0.
--Tiene exactamente los efectos del Ra anime del juego (se cargan desde c511600400.lua) y además:
--  • Al resolver "Point-to-Point Transfer" cambia a la imagen 600000240.
--  • Al resolver "Immortal Phoenix" cambia a la imagen 600000241.
--  • Sigue siendo "The Winged Dragon of Ra" para las reglas (alias 10000010) durante todo el duelo.
--  • Vuelve a su imagen original al dejar el campo (al GY, mano, Deck o destierro solo va la original),
--    al terminar el turno (cuando esos efectos expiran) y si "De-Fusion" le quita los efectos.
Duel.LoadCardScript("c511600400.lua")
local s,id=GetID()
local BASE=511600400
local FORM_PTP=id+1     --600000240: imagen de Point-to-Point Transfer
local FORM_PHOENIX=id+2 --600000241: imagen de Immortal Phoenix
local RA_ALIAS=10000010 --"The Winged Dragon of Ra"
--Pon esto en false si quieres que la forma se mantenga hasta que deje el campo, aunque pase el turno.
s.revert_at_end_phase=true

function s.initial_effect(c)
	--Todos los efectos del Ra anime del juego
	c511600400.initial_effect(c)
	--Cambiar de imagen al resolver Point-to-Point Transfer / Immortal Phoenix
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_CHAIN_SOLVED)
	e1:SetRange(LOCATION_MZONE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetCondition(s.formcon)
	e1:SetOperation(s.formop)
	c:RegisterEffect(e1)
	--Volver a la imagen original al dejar el campo
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_LEAVE_FIELD_P)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e2:SetCondition(s.transformed)
	e2:SetOperation(s.revertop)
	c:RegisterEffect(e2)
	--Volver a la imagen original en la End Phase (los efectos de la forma expiran)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_PHASE+PHASE_END)
	e3:SetRange(LOCATION_MZONE)
	e3:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e3:SetCondition(function(e) return s.revert_at_end_phase and s.transformed(e) end)
	e3:SetOperation(s.revertop)
	c:RegisterEffect(e3)
	--Volver a la imagen original si "De-Fusion" le quita los efectos de Point-to-Point Transfer
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_ADJUST)
	e4:SetRange(LOCATION_MZONE)
	e4:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e4:SetCondition(s.defusedcon)
	e4:SetOperation(s.revertop)
	c:RegisterEffect(e4)
end
s.listed_names={RA_ALIAS,BASE}

--¿Qué efecto del Ra acaba de resolverse?
function s.formof(re)
	if not re then return nil end
	local d=re:GetDescription()
	if d==aux.Stringid(BASE,0) then return FORM_PTP end
	if d==aux.Stringid(BASE,1) then return FORM_PHOENIX end
	return nil
end
function s.formcon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	return re and re:GetHandler()==c and c:IsFaceup() and s.formof(re)~=nil
end
function s.formop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local form=s.formof(re)
	if not form or c:GetOriginalCode()==form then return end
	--Cambia la imagen (código de datos) pero conserva el nombre y la identidad: "The Winged Dragon of Ra"
	c:Recreate(form,RA_ALIAS)
	Duel.AdjustInstantly(c)
end
function s.transformed(e)
	local code=e:GetHandler():GetOriginalCode()
	return code==FORM_PTP or code==FORM_PHOENIX
end
function s.defusedcon(e)
	local c=e:GetHandler()
	return c:GetOriginalCode()==FORM_PTP and FLAG_RA_DEFUSION and c:HasFlagEffect(FLAG_RA_DEFUSION)
end
function s.revertop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not s.transformed(e) then return end
	--Vuelve a los datos e imagen originales de esta carta (incluye su alias original)
	c:Recreate(id)
	Duel.AdjustInstantly(c)
end

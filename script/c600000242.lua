--沈黙の魔術師 ＬＶ０ (Anime) - Formas
--Silent Magician LV0 (Anime Forms)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro) "Silent Magician LV0" (c511001141), con licencia AGPL-3.0.
--Tiene exactamente los efectos del Silent Magician LV0 anime del juego (se cargan desde c511001141.lua) y además:
--  • Cuando su efecto le sube el ATK a 2500 o más, cambia a la imagen 600000243.
--  • Sigue siendo "Silent Magician LV0" para las reglas (alias 511001141) durante todo el duelo.
--  • Vuelve a su imagen original al dejar el campo.
Duel.LoadCardScript("c511001141.lua")
local s,id=GetID()
local BASE=511001141
local FORM=id+1 --600000243: imagen al llegar a 2500 de ATK

function s.initial_effect(c)
	--Todos los efectos del Silent Magician LV0 anime del juego
	c511001141.initial_effect(c)
	--Después de que su efecto le suba el ATK: si llega a 2500, cambia de imagen
	for _,eff in ipairs({c:GetOwnEffects()}) do
		if eff:GetCode()==EVENT_DRAW and eff:GetDescription()==aux.Stringid(BASE,0) then
			local op=eff:GetOperation()
			eff:SetOperation(function(e,...)
				op(e,...)
				local c=e:GetHandler()
				if c:IsFaceup() and c:IsLocation(LOCATION_MZONE) and c:GetAttack()>=2500 then s.setform(c,FORM) end
			end)
		end
	end
	--Volver a la imagen original al dejar el campo
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_LEAVE_FIELD_P)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetCondition(function(e) return e:GetHandler():GetOriginalCode()==FORM end)
	e1:SetOperation(function(e) s.revert(e:GetHandler()) end)
	c:RegisterEffect(e1)
end
s.listed_names={BASE}

--Cambia la imagen (código de datos) pero conserva el nombre y la identidad: "Silent Magician LV0"
function s.setform(c,form)
	if c:GetOriginalCode()==form then return end
	c:Recreate(form,BASE)
	Duel.AdjustInstantly(c)
end
--Vuelve a los datos e imagen originales de esta carta (incluye su alias original)
function s.revert(c)
	if c:GetOriginalCode()==id then return end
	c:Recreate(id)
	Duel.AdjustInstantly(c)
end

--沈黙の剣士 ＬＶ０ (Anime) - Formas
--Silent Swordsman LV0 (Anime Forms)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script de Project Ignis (EDOPro) "Silent Swordsman LV0" (c511001137), con licencia AGPL-3.0.
--Tiene exactamente los efectos del Silent Swordsman LV0 anime del juego (se cargan desde c511001137.lua) y además
--cambia de imagen según el ATK que haya ganado por su propio efecto:
--  • +1000 → 600000245 · +2000 → 600000246 · +3000 → 600000247 · +4000 o más → 600000248
--  • Sigue siendo "Silent Swordsman LV0" para las reglas (alias 511001137) durante todo el duelo.
--  • Vuelve a su imagen original si pierde lo ganado por su efecto (deja el campo o se coloca boca abajo).
Duel.LoadCardScript("c511001137.lua")
local s,id=GetID()
local BASE=511001137
local MAXFORM=4 --600000248: imagen al ganar 4000 de ATK

function s.initial_effect(c)
	--Todos los efectos del Silent Swordsman LV0 anime del juego
	c511001137.initial_effect(c)
	--Después de que su efecto le suba el ATK: cada 1000 ganados cambia de imagen
	for _,eff in ipairs({c:GetOwnEffects()}) do
		if eff:GetCode()==EVENT_PHASE+PHASE_STANDBY and eff:GetDescription()==aux.Stringid(BASE,0) then
			local op=eff:GetOperation()
			eff:SetOperation(function(e,...)
				op(e,...)
				local c=e:GetHandler()
				if c:IsFaceup() and c:IsLocation(LOCATION_MZONE) then s.update(c) end
			end)
		end
	end
	--Volver a la imagen original al dejar el campo
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_LEAVE_FIELD_P)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetCondition(function(e) return e:GetHandler():GetOriginalCode()~=id end)
	e1:SetOperation(function(e) s.revert(e:GetHandler()) end)
	c:RegisterEffect(e1)
	--Volver a la imagen original al colocarse boca abajo (pierde el ATK ganado)
	local e2=e1:Clone()
	e2:SetCode(EVENT_CHANGE_POS)
	e2:SetCondition(function(e) local c=e:GetHandler() return c:IsFacedown() and c:GetOriginalCode()~=id end)
	c:RegisterEffect(e2)
end
s.listed_names={BASE}

--Forma según las veces que resolvió su efecto (+500 cada una): 2 → +1000, 4 → +2000, 6 → +3000, 8 → +4000
function s.update(c)
	local lv=c:GetFlagEffectLabel(BASE) or 0
	local f=math.min(lv//2,MAXFORM)
	if f>0 then s.setform(c,id+f) end
end
--Cambia la imagen (código de datos) pero conserva el nombre y la identidad: "Silent Swordsman LV0"
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

--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--死者蘇生 (Manga)
--Monster Reborn (Manga) - version Magia Rapida
--Adaptado del script OFICIAL c83764718 sin cambiar su logica de invocacion.
--
--EFECTO NO ESCRITO EN LA DESCRIPCION, a peticion del autor del paquete:
--  mientras "Manga Mode (Creator Mode)" (189) este desterrado boca arriba,
--  esta carta tambien se puede activar durante la Battle Phase.
--  Sin Anime Mode se comporta como una Magia Rapida normal y la Battle Phase
--  le queda cerrada.
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
--Solo se puede activar mientras "Anime Mode (Creator Mode)" (600000238) o
--"Manga Mode (Creator Mode)" (189) este desterrada boca arriba: es la regla del
--manga que permite jugar estas Magias Normales como si fueran de Juego Rapido.
--Las dos cartas de modo se destierran boca arriba al empezar el duelo, asi que basta
--con buscarlas en la zona de desterradas de cualquiera de los dos jugadores.
local MODE_ANIME=600000238
local MODE_MANGA=189
function s.modefilter(c)
	return c:IsFaceup() and (c:IsCode(MODE_ANIME) or c:IsCode(MODE_MANGA))
end
function s.modeon()
	return Duel.IsExistingMatchingCard(s.modefilter,0,LOCATION_REMOVED,LOCATION_REMOVED,1,nil)
end
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.actcon)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--Antes solo pedia Manga Mode para activarla dentro de la Battle Phase. Ahora el modo
--hace falta SIEMPRE, asi que esa distincion sobra: con el modo puesto se comporta
--como cualquier Magia de Juego Rapido.
--en tu propio turno, como una Magia Normal: Main Phase y Cadena vacia.
--La velocidad de Juego Rapido queda para el turno del rival.
function s.ownturnok(tp)
	if Duel.GetTurnPlayer()~=tp then return true end
	local ph=Duel.GetCurrentPhase()
	return (ph==PHASE_MAIN1 or ph==PHASE_MAIN2) and Duel.GetCurrentChain()==0
end
function s.actcon(e,tp,eg,ep,ev,re,r,rp)
	if not s.ownturnok(tp) then return false end
	return s.modeon()
end
function s.filter(c,e,tp)
	return c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_GRAVE) and s.filter(chkc,e,tp) end
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingTarget(s.filter,tp,LOCATION_GRAVE,LOCATION_GRAVE,1,nil,e,tp) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local g=Duel.SelectTarget(tp,s.filter,tp,LOCATION_GRAVE,LOCATION_GRAVE,1,1,nil,e,tp)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,g,1,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc:IsRelateToEffect(e) and aux.NecroValleyFilter()(tc) then
		Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)
	end
end

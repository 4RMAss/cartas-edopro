--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script de Project Ignis (EDOPro), con licencia AGPL-3.0.
--魂の交換－ソウル・バーター (Manga)
--Soul Barter (Manga)
--Version de Juego Rapido de "Soul Barter" (511008003), con las mismas dos
--restricciones que el resto de Magias que pasamos a rapidas:
--  (a) Solo se puede activar mientras "Anime Mode (Creator Mode)" (600000238) o
--      "Manga Mode (Creator Mode)" (189) este desterrada boca arriba. Es la regla del
--      manga que permite jugar estas Magias Normales como si fueran de Juego Rapido.
--  (b) En TU turno se comporta como una Magia Normal: solo en Main Phase y con la
--      Cadena vacia. La velocidad de Juego Rapido queda para el turno del rival.
--Ademas, el envio al Cementerio va en la resolucion y no como coste, igual que en
--"Star Level Shuffle": con IsAbleToGraveAsCost() una FICHA no pasa el filtro, porque
--el core no deja mandarlas al Cementerio como coste. Su texto no lo marca como coste.
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
local MODE_ANIME=600000238
local MODE_MANGA=189
function s.initial_effect(c)
	--Special Summon 1 monster from the GY
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.actcon)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--una de las dos cartas de modo, desterrada boca arriba, en cualquiera de los lados
function s.modefilter(c)
	return c:IsFaceup() and (c:IsCode(MODE_ANIME) or c:IsCode(MODE_MANGA))
end
function s.modeon()
	return Duel.IsExistingMatchingCard(s.modefilter,0,LOCATION_REMOVED,LOCATION_REMOVED,1,nil)
end
--en tu propio turno, como una Magia Normal: Main Phase y Cadena vacia
function s.ownturnok(tp)
	if Duel.GetTurnPlayer()~=tp then return true end
	local ph=Duel.GetCurrentPhase()
	return (ph==PHASE_MAIN1 or ph==PHASE_MAIN2) and Duel.GetCurrentChain()==0
end
function s.actcon(e,tp,eg,ep,ev,re,r,rp)
	return s.modeon() and s.ownturnok(tp)
end
--monstruo propio que se puede mandar al Cementerio (Fichas incluidas) dejando hueco
function s.cstfilter(c,tp)
	return c:IsAbleToGrave() and Duel.GetMZoneCount(tp,c)>0
end
function s.spfilter(c,e,tp)
	return c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.cstfilter,tp,LOCATION_MZONE,0,1,nil,tp)
		and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_GRAVE,0,1,nil,e,tp) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_GRAVE)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local g=Duel.SelectMatchingCard(tp,s.cstfilter,tp,LOCATION_MZONE,0,1,1,nil,tp)
	local tc=g:GetFirst()
	if not tc then return end
	Duel.SendtoGrave(g,REASON_EFFECT)
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	--"1 OTHER monster": el que acabas de mandar no vale
	local sg=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_GRAVE,0,1,1,tc,e,tp)
	if #sg>0 then
		Duel.SpecialSummon(sg,0,tp,tp,false,false,POS_FACEUP)
	end
end

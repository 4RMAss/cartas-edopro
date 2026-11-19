--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--レベル・レジストウォール (Manga)
--Level Resist Wall (Manga)
--Versión EDOPro: basada en el script OFICIAL c86133013 de EDOPro.
--Diferencias según el texto del manga:
--  - se activa cuando un monstruo de tu campo es destruido, sin importar la causa
--    (la oficial exige batalla o efecto del rival)
--  - invoca 2 O MÁS monstruos (la oficial permite 1)
--  - NO niega los efectos de los monstruos invocados
--  - sin límite de 1 por turno
local s,id=GetID()
function s.initial_effect(c)
	--Activate/Special Summon
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DELAY+EFFECT_FLAG_CARD_TARGET)
	e1:SetCode(EVENT_DESTROYED)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.tgfilter(c,e,tp,ft)
	local lv=c:GetLevel()
	if not (c:IsPreviousLocation(LOCATION_MZONE) and c:IsPreviousControler(tp)
		and c:IsLocation(LOCATION_GRAVE|LOCATION_REMOVED) and c:IsCanBeEffectTarget(e)
		and c:HasLevel() and lv>1) then return false end
	local g=Duel.GetMatchingGroup(s.spfilter,tp,LOCATION_DECK,0,nil,e,tp,lv)
	--mínimo 2 monstruos cuyos Niveles sumen exactamente el Nivel del destruido
	return g:CheckWithSumEqual(Card.GetLevel,lv,2,ft)
end
function s.spfilter(c,e,tp,lv)
	return c:HasLevel() and c:IsLevelBelow(lv-1)
		and c:IsCanBeSpecialSummoned(e,0,tp,false,false,POS_FACEUP_DEFENSE)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
	if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ft=math.min(ft,1) end
	if chkc then return eg:IsContains(chkc) and s.tgfilter(chkc,e,tp,ft) end
	local tg=eg:Filter(s.tgfilter,nil,e,tp,ft)
	if chk==0 then return ft>1 and #tg>0 end
	local tc=nil
	if #tg>1 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		tc=tg:Select(tp,1,1,nil):GetFirst()
	else
		tc=tg:GetFirst()
	end
	Duel.SetTargetCard(tc)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,2,tp,LOCATION_DECK)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
	if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ft=math.min(ft,1) end
	if ft<2 then return end
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) then return end
	local lv=tc:GetLevel()
	local g=Duel.GetMatchingGroup(s.spfilter,tp,LOCATION_DECK,0,nil,e,tp,lv)
	if not g:CheckWithSumEqual(Card.GetLevel,lv,2,ft) then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local sg=g:SelectWithSumEqual(tp,Card.GetLevel,lv,2,ft)
	if #sg<2 then return end
	for sc in sg:Iter() do
		Duel.SpecialSummonStep(sc,0,tp,tp,false,false,POS_FACEUP_DEFENSE)
	end
	Duel.SpecialSummonComplete()
end

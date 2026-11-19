--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--ダーク・コーリング (Anime)
--Dark Calling (Anime)
--Versión EDOPro basada en el script oficial c12071500.
--Según el texto del anime:
--  - coste: desterrar 1 "Dark Fusion" de tu Cementerio
--  - sirve para cualquier Monstruo de Fusión de Tipo Demonio
--  - los Materiales de Fusión se destierran de tu mano o Cementerio
--  - la Invocación Especial se trata como Invocación por Fusión
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Fusion.CreateSummonEff{handler=c,fusfilter=s.fusfilter,matfilter=Fusion.InHandMat(aux.LimitParams(Card.IsAbleToRemove)),
		extrafil=s.fextra,extraop=Fusion.BanishMaterial,extratg=s.extratg,chkf=FUSPROC_NOLIMIT}
	e1:SetCost(s.cost)
	c:RegisterEffect(e1)
end
s.listed_names={CARD_DARK_FUSION}
function s.fusfilter(c)
	return c:IsRace(RACE_FIEND)
end
function s.fextra(e,tp,mg)
	return Duel.GetMatchingGroup(Fusion.IsMonsterFilter(Card.IsAbleToRemove),tp,LOCATION_GRAVE|LOCATION_HAND,0,nil)
end
function s.extratg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_REMOVE,nil,1,tp,LOCATION_HAND|LOCATION_GRAVE)
end
function s.costfilter(c)
	return c:IsCode(CARD_DARK_FUSION) and c:IsAbleToRemoveAsCost()
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.costfilter,tp,LOCATION_GRAVE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
	local g=Duel.SelectMatchingCard(tp,s.costfilter,tp,LOCATION_GRAVE,0,1,1,nil)
	Duel.Remove(g,POS_FACEUP,REASON_COST)
end

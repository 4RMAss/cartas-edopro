--Rumbling of Heaven and Earth (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--returns the location that the new targets must come from, or nil
function s.newloc(ev)
	local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	if not g or #g==0 then return nil end
	if g:FilterCount(Card.IsOnField,nil)==#g then return LOCATION_GRAVE,g end
	if g:FilterCount(Card.IsLocation,nil,LOCATION_GRAVE)==#g then return LOCATION_ONFIELD,g end
	return nil
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) and s.newloc(ev)~=nil
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local loc,g=s.newloc(ev)
	if chk==0 then return loc and Duel.GetMatchingGroupCount(aux.TRUE,tp,loc,loc,e:GetHandler())>=#g end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local loc,g=s.newloc(ev)
	if not loc then return end
	local cg=Duel.GetMatchingGroup(aux.TRUE,tp,loc,loc,e:GetHandler())
	if #cg<#g then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local ng=cg:Select(tp,#g,#g,nil)
	Duel.HintSelection(ng)
	Duel.ChangeTargetCard(ev,ng)
end

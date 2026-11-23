--Dice Roll Battle (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_REMOVE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_ATTACK_ANNOUNCE)
	e1:SetCondition(function(e,tp) return Duel.GetLP(tp)<=1000 and Duel.GetAttacker():IsControler(1-tp) end)
	e1:SetCost(s.cost)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.dice={16725505,27660735,3549275,62893810,69893315}
function s.cfilter(c)
	return c:IsMonster() and c:IsCode(table.unpack(s.dice)) and c:IsAbleToGraveAsCost()
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_HAND,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	Duel.SendtoGrave(Duel.SelectMatchingCard(tp,s.cfilter,tp,LOCATION_HAND,0,1,1,nil),REASON_COST)
end
function s.matfilter(c)
	return c:IsMonster() and c:HasLevel() and c:IsAbleToRemove()
end
function s.matcheck(lv)
	return function(sg,e,tp,mg)
		return sg:FilterCount(Card.IsType,nil,TYPE_TUNER)==1 and sg:GetSum(Card.GetLevel)==lv
	end
end
function s.scfilter(c,e,tp,mg)
	return c:IsType(TYPE_SYNCHRO) and c:IsCanBeSpecialSummoned(e,SUMMON_TYPE_SYNCHRO,tp,false,false)
		and Duel.GetLocationCountFromEx(tp,tp,nil,c)>0
		and aux.SelectUnselectGroup(mg,e,tp,2,#mg,s.matcheck(c:GetLevel()),0)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then
		--the "Dice" monster sent as cost can also be used as material
		local mg=Duel.GetMatchingGroup(s.matfilter,tp,LOCATION_GRAVE|LOCATION_HAND,0,nil):Filter(function(c) return c:IsLocation(LOCATION_GRAVE) or s.cfilter(c) end,nil)
		return Duel.IsExistingMatchingCard(s.scfilter,tp,LOCATION_EXTRA,0,1,nil,e,tp,mg)
	end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_EXTRA)
	Duel.SetOperationInfo(0,CATEGORY_REMOVE,nil,2,tp,LOCATION_GRAVE)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local mg=Duel.GetMatchingGroup(aux.NecroValleyFilter(s.matfilter),tp,LOCATION_GRAVE,0,nil)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local sc=Duel.SelectMatchingCard(tp,s.scfilter,tp,LOCATION_EXTRA,0,1,1,nil,e,tp,mg):GetFirst()
	if sc then
		local mat=aux.SelectUnselectGroup(mg,e,tp,2,#mg,s.matcheck(sc:GetLevel()),1,tp,HINTMSG_REMOVE)
		if #mat>=2 then
			sc:SetMaterial(mat)
			Duel.Remove(mat,POS_FACEUP,REASON_EFFECT|REASON_MATERIAL|REASON_SYNCHRO)
			Duel.BreakEffect()
			if Duel.SpecialSummon(sc,SUMMON_TYPE_SYNCHRO,tp,tp,false,false,POS_FACEUP)>0 then sc:CompleteProcedure() end
		end
	end
	--All Attack Position monsters your opponent controls must attack, if able
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_MUST_ATTACK)
	e1:SetTargetRange(0,LOCATION_MZONE)
	e1:SetTarget(function(e,tc) return tc:IsAttackPos() end)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
end

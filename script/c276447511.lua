--Dynatherium (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetValue(1)
	e1:SetCondition(function(e,c) return c==nil or Duel.GetLocationCount(c:GetControler(),LOCATION_MZONE)>0 end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_SPSUMMON_SUCCESS)
	e2:SetCondition(function(e) return e:GetHandler():GetSummonType()==SUMMON_TYPE_SPECIAL+1 end)
	e2:SetOperation(s.spop)
	c:RegisterEffect(e2)
end
function s.spfilter(c,e,p,lv)
	return c:IsLevel(lv) and c:IsCanBeSpecialSummoned(e,0,p,false,false)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local p=1-tp
	local g=Duel.GetMatchingGroup(aux.NecroValleyFilter(s.spfilter),p,LOCATION_GRAVE,0,nil,e,p,c:GetLevel())
	if #g==0 or Duel.GetLocationCount(p,LOCATION_MZONE)<=0 or not Duel.SelectYesNo(p,aux.Stringid(id,1)) then return end
	Duel.Hint(HINT_SELECTMSG,p,HINTMSG_SPSUMMON)
	local sg=g:Select(p,1,1,nil)
	Duel.HintSelection(sg)
	Duel.SpecialSummon(sg,0,p,p,false,false,POS_FACEUP)
end

--Kaleidoscope Gate (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	aux.GlobalCheck(s,function()
		s.left={}
		s.turn=-1
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_LEAVE_FIELD)
		ge1:SetOperation(s.checkop)
		Duel.RegisterEffect(ge1,0)
	end)
end
function s.checkop(e,tp,eg,ep,ev,re,r,rp)
	if s.turn~=Duel.GetTurnCount() then
		s.turn=Duel.GetTurnCount()
		s.left={}
	end
	for tc in eg:Iter() do
		if tc:IsPreviousLocation(LOCATION_MZONE) then
			local code=tc:GetPreviousCodeOnField()
			local t=s.left[code] or {n=0,lv=0}
			t.n=t.n+1
			t.lv=tc:GetOriginalLevel()
			s.left[code]=t
		end
	end
end
function s.levels()
	local lv={}
	if s.turn~=Duel.GetTurnCount() then return lv end
	for _,t in pairs(s.left) do
		if t.n>=3 and t.lv>0 then lv[t.lv]=true end
	end
	return lv
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return next(s.levels())~=nil
end
function s.spfilter(c,e,tp,lv)
	return c:IsMonster() and lv[c:GetLevel()] and c:IsDefenseBelow(2000) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_DECK,0,1,nil,e,tp,s.levels()) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_DECK)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_DECK,0,1,1,nil,e,tp,s.levels())
	if #g>0 then Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP) end
end

--Speedroid Ohajikid (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e0:SetCode(EVENT_SUMMON_SUCCESS)
	e0:SetOperation(function(e) e:GetHandler():RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1) end)
	c:RegisterEffect(e0)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk) if chk==0 then return Duel.GetActivityCount(tp,ACTIVITY_SPSUMMON)==0 end end)
	e1:SetTarget(s.sptg)
	e1:SetOperation(s.spop)
	c:RegisterEffect(e1)
end
function s.scfilter(c,lv)
	return c:IsType(TYPE_SYNCHRO) and c:IsLevel(lv)
end
function s.spfilter(c,e,tp,mc)
	return c:IsType(TYPE_TUNER) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
		and Duel.IsExistingMatchingCard(s.scfilter,tp,LOCATION_EXTRA,0,1,nil,c:GetLevel()+mc:GetLevel())
end
function s.sptg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local c=e:GetHandler()
	if chkc then return chkc:IsLocation(LOCATION_GRAVE) and chkc:IsControler(1-tp) and s.spfilter(chkc,e,tp,c) end
	if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingTarget(s.spfilter,tp,0,LOCATION_GRAVE,1,nil,e,tp,c) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local g=Duel.SelectTarget(tp,s.spfilter,tp,0,LOCATION_GRAVE,1,1,nil,e,tp,c)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,g,1,0,0)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	local ok=tc:IsRelateToEffect(e) and c:IsRelateToEffect(e) and c:IsFaceup()
		and Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)>0
	--You cannot Special Summon during this turn, except with this card's effect
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(EFFECT_CANNOT_SPECIAL_SUMMON)
	e1:SetTargetRange(1,0)
	e1:SetTarget(s.splimit)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
	if not ok then return end
	--immediately after this effect resolves, Synchro Summon using that monster and this card only
	local mg=Group.FromCards(c,tc)
	e1:SetLabel(1)
	local g=Duel.GetMatchingGroup(Card.IsSynchroSummonable,tp,LOCATION_EXTRA,0,nil,nil,mg)
	if #g==0 then e1:SetLabel(0) return end
	--once that Synchro Summon is done, no more Special Summons this turn
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_SPSUMMON_SUCCESS)
	e2:SetLabelObject(e1)
	e2:SetOperation(function(e) e:GetLabelObject():SetLabel(0) e:Reset() end)
	e2:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e2,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	Duel.SynchroSummon(tp,g:Select(tp,1,1,nil):GetFirst(),nil,mg)
end
--the Synchro Summon of this card's effect is the only Special Summon allowed
function s.splimit(e,c,sump,sumtype,sumpos,targetp,se)
	return not (e:GetLabel()==1 and sumtype&SUMMON_TYPE_SYNCHRO==SUMMON_TYPE_SYNCHRO)
end

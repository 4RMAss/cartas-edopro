--Garakarasu (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		local f=function(c) return c:IsFaceup() and c:IsType(TYPE_FIELD) end
		if chkc then return chkc:IsLocation(LOCATION_FZONE) and f(chkc) end
		if chk==0 then return Duel.IsExistingTarget(f,tp,LOCATION_FZONE,LOCATION_FZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
		local g=Duel.SelectTarget(tp,f,tp,LOCATION_FZONE,LOCATION_FZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,1,0,0)
	end)
	e1:SetOperation(function(e)
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) then Duel.Destroy(tc,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
end

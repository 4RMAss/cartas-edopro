--Performapal Lebellman (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	Pendulum.AddProcedure(c)
	--Pendulum: all your monsters +1 Level
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_PZONE)
	e1:SetCountLimit(1)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.HasLevel,tp,LOCATION_MZONE,0,1,nil) end
	end)
	e1:SetOperation(function(e,tp)
		for tc in Duel.GetMatchingGroup(function(mc) return mc:IsFaceup() and mc:HasLevel() end,tp,LOCATION_MZONE,0,nil):Iter() do
			local e1=Effect.CreateEffect(e:GetHandler())
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(EFFECT_UPDATE_LEVEL)
			e1:SetValue(1)
			e1:SetReset(RESET_EVENT|RESETS_STANDARD)
			tc:RegisterEffect(e1)
		end
	end)
	c:RegisterEffect(e1)
	--Monster: move Levels from this card to another monster
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_LVCHANGE)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		local c=e:GetHandler()
		local f=function(tc) return tc:IsFaceup() and tc:HasLevel() end
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and chkc~=c and f(chkc) end
		if chk==0 then return c:GetLevel()>1 and Duel.IsExistingTarget(f,tp,LOCATION_MZONE,0,1,c) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
		Duel.SelectTarget(tp,f,tp,LOCATION_MZONE,0,1,1,c)
	end)
	e2:SetOperation(function(e,tp)
		local c=e:GetHandler()
		local tc=Duel.GetFirstTarget()
		if not (c:IsRelateToEffect(e) and c:IsFaceup() and c:GetLevel()>1 and tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
		local n=Duel.AnnounceLevel(tp,1,c:GetLevel()-1)
		for _,pair in ipairs({{tc,n},{c,-n}}) do
			local e1=Effect.CreateEffect(c)
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(EFFECT_UPDATE_LEVEL)
			e1:SetValue(pair[2])
			e1:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END)
			pair[1]:RegisterEffect(e1)
		end
	end)
	c:RegisterEffect(e2)
end

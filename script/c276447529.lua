--Performapal Cheermole (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	Pendulum.AddProcedure(c)
	--Pendulum Monsters you control gain 400 ATK
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetRange(LOCATION_PZONE)
	e1:SetTargetRange(LOCATION_MZONE,0)
	e1:SetTarget(function(e,tc) return tc:IsType(TYPE_PENDULUM) end)
	e1:SetValue(400)
	c:RegisterEffect(e1)
	--An ATK change becomes 1000 bigger
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_ATKCHANGE)
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_CHAINING)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET+EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e2:SetCountLimit(1)
	e2:SetCondition(s.atkcon)
	e2:SetTarget(s.atktg)
	e2:SetOperation(s.atkop)
	c:RegisterEffect(e2)
end
function s.cands(ev)
	local f=function(tc) return tc:IsLocation(LOCATION_MZONE) and tc:IsFaceup() end
	local tg=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	if tg and #tg>0 then return tg:Filter(f,nil) end
	local ex,og=Duel.GetOperationInfo(ev,CATEGORY_ATKCHANGE)
	if og and #og>0 then return og:Filter(f,nil) end
	return Duel.GetMatchingGroup(Card.IsFaceup,0,LOCATION_MZONE,LOCATION_MZONE,nil)
end
function s.atkcon(e,tp,eg,ep,ev,re,r,rp)
	local ex=Duel.GetOperationInfo(ev,CATEGORY_ATKCHANGE)
	return (ex or re:IsHasCategory(CATEGORY_ATKCHANGE)) and #s.cands(ev)>0
end
function s.atktg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local g=s.cands(ev)
	if chkc then return g:IsContains(chkc) end
	if chk==0 then return g:IsExists(Card.IsCanBeEffectTarget,1,nil,e) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	Duel.SelectTarget(tp,function(tc) return g:IsContains(tc) end,tp,LOCATION_MZONE,LOCATION_MZONE,1,1,nil)
	e:SetLabel(ev)
end
function s.atkop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	local link,fid=e:GetLabel(),tc:GetFieldID()
	--remember its ATK right before that effect resolves...
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_CHAIN_SOLVING)
	e1:SetLabel(tc:GetAttack())
	e1:SetCondition(function(_,_,_,_,cev) return cev==link end)
	e1:SetOperation(function(se) if tc:IsFaceup() then se:SetLabel(tc:GetAttack()) end end)
	e1:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e1,tp)
	--...and make the change 1000 bigger once it has resolved
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_CHAIN_SOLVED)
	e2:SetCondition(function(_,_,_,_,cev) return cev==link end)
	e2:SetOperation(function()
		if not (tc:IsFaceup() and tc:IsLocation(LOCATION_MZONE) and tc:GetFieldID()==fid) then return end
		local before,now=e1:GetLabel(),tc:GetAttack()
		local v=(now>before and 1000) or (now<before and -1000) or 0
		if v==0 then return end
		Duel.Hint(HINT_CARD,0,id)
		local e3=Effect.CreateEffect(c)
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetCode(EFFECT_UPDATE_ATTACK)
		e3:SetValue(v)
		e3:SetReset(RESET_EVENT|RESETS_STANDARD)
		tc:RegisterEffect(e3)
	end)
	e2:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e2,tp)
end

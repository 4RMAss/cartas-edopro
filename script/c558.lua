--Script: 4RMAss · Anime Server by 4RMAss
if not EFFECT_SKIP_EP then EFFECT_SKIP_EP=0x7E000010 end
--Drain Time (Anime)
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.con)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetRange(LOCATION_GRAVE)
	e2:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e2:SetCountLimit(1)
	e2:SetCondition(s.thcon)
	e2:SetCost(s.thcost)
	e2:SetTarget(s.thtg)
	e2:SetOperation(s.thop)
	c:RegisterEffect(e2)
end
s.listed_names={83965310,511000614} --Destiny HERO - Plasma (Official + Anime)

function s.filter(c)
	return c:IsFaceup() and (c:IsCode(83965310) or c:IsCode(511000614))
end
function s.con(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_MZONE,0,1,nil)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local op=Duel.SelectOption(tp,
		aux.Stringid(id,0),
		aux.Stringid(id,1),
		aux.Stringid(id,2),
		aux.Stringid(id,3),
		aux.Stringid(id,4)
	)
	local code=nil
	local reset_count=3
	if op==0 then
		code=EFFECT_SKIP_DP
	elseif op==1 then
		code=EFFECT_SKIP_SP
	elseif op==2 then
		code=EFFECT_SKIP_M1
	elseif op==3 then
		code=EFFECT_SKIP_BP
	elseif op==4 then
		code=EFFECT_SKIP_EP
	end
	if op==2 or op==3 or op==4 then
		reset_count=2
	end
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(code)
	e1:SetTargetRange(1,1)
	e1:SetReset(RESET_PHASE+PHASE_END,reset_count)
	Duel.RegisterEffect(e1,tp)
end
function s.thcon(e,tp,eg,ep,ev,re,r,rp)
	return tp==Duel.GetTurnPlayer()
end
function s.thcost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.CheckLPCost(tp,1000) end
	Duel.PayLPCost(tp,1000)
end
function s.thtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return e:GetHandler():IsAbleToHand() end
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,e:GetHandler(),1,0,0)
end
function s.thop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) then
		Duel.SendtoHand(c,nil,REASON_EFFECT)
	end
end
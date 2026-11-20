--超重輝将サン－5
--Superheavy Samurai General Coral (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en los scripts oficiales de Project Ignis (EDOPro), con licencia AGPL-3.0.
local s,id=GetID()
function s.initial_effect(c)
	--Pendulum Summon
	Pendulum.AddProcedure(c)
	--Destroy this card: the "Superheavy" monster can make a second attack in a row
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetRange(LOCATION_PZONE)
	e1:SetCost(s.cacost)
	e1:SetTarget(s.catg)
	e1:SetOperation(s.caop)
	c:RegisterEffect(e1)
	--Draw
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetCategory(CATEGORY_DRAW)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCountLimit(1,id)
	e2:SetCondition(function(e,tp) return s.nostgy(tp) end)
	e2:SetCost(s.drcost)
	e2:SetTarget(s.drtg)
	e2:SetOperation(s.drop)
	c:RegisterEffect(e2)
end
s.listed_series={SET_SUPERHEAVY_SAMURAI}

function s.nostgy(tp)
	return not Duel.IsExistingMatchingCard(Card.IsSpellTrap,tp,LOCATION_GRAVE,0,1,nil)
end

function s.afilter(c,tp)
	return c:IsControler(tp) and c:IsSetCard(SET_SUPERHEAVY_SAMURAI) and c:IsRelateToBattle() and c:CanChainAttack()
end
function s.cacost(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then return c:IsDestructable() end
	Duel.Destroy(c,REASON_COST)
end
function s.catg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return eg:IsExists(s.afilter,1,nil,tp) end
	Duel.SetTargetCard(eg:Filter(s.afilter,nil,tp):GetFirst())
end
function s.caop(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc and tc:IsFaceup() and tc:IsControler(tp) and tc:IsRelateToBattle() then
		Duel.ChainAttack()
	end
end
function s.drcost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.CheckReleaseGroupCost(tp,Card.IsSetCard,1,false,nil,nil,SET_SUPERHEAVY_SAMURAI) end
	local ct=math.min(2,Duel.GetFieldGroupCount(tp,LOCATION_DECK,0))
	local g=Duel.SelectReleaseGroupCost(tp,Card.IsSetCard,1,math.max(ct,1),false,nil,nil,SET_SUPERHEAVY_SAMURAI)
	e:SetLabel(Duel.Release(g,REASON_COST))
end
function s.drtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,e:GetLabel())
end
function s.drop(e,tp,eg,ep,ev,re,r,rp)
	Duel.Draw(tp,e:GetLabel(),REASON_EFFECT)
end

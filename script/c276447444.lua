--Zero Gravitation (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	--When an opponent's monster declares an attack: you choose its attack target
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_ATTACK_ANNOUNCE)
	e1:SetCondition(function(e,tp) return Duel.GetAttacker():IsControler(1-tp) end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return #Duel.GetAttacker():GetAttackableTarget()>0 end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local a=Duel.GetAttacker()
	if not a or not a:IsRelateToBattle() then return end
	local g=a:GetAttackableTarget()
	if #g==0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACKTARGET)
	local tc=g:Select(tp,1,1,nil):GetFirst()
	Duel.HintSelection(tc)
	if tc~=Duel.GetAttackTarget() then Duel.ChangeAttackTarget(tc) end
end

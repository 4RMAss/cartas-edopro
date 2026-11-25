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
	s.patch()
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return #Duel.GetAttacker():GetAttackableTarget()>0 end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	--This turn, both Decks are treated as one Deck
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_CLIENT_HINT)
	e1:SetCode(id)
	e1:SetTargetRange(1,1)
	e1:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e1,tp)
	local a=Duel.GetAttacker()
	if not a or not a:IsRelateToBattle() then return end
	local g=a:GetAttackableTarget()
	if #g==0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACKTARGET)
	local tc=g:Select(tp,1,1,nil):GetFirst()
	Duel.HintSelection(tc)
	if tc~=Duel.GetAttackTarget() then Duel.ChangeAttackTarget(tc) end
end
--While active, any "your Deck"/"opponent's Deck" location used by a card means both Decks
function s.active()
	return Duel.IsPlayerAffectedByEffect(0,id)~=nil
end
function s.loc(sl,ol)
	if s.active() and type(sl)=="number" and type(ol)=="number" then
		if sl&LOCATION_DECK~=0 then ol=ol|LOCATION_DECK end
		if ol&LOCATION_DECK~=0 then sl=sl|LOCATION_DECK end
	end
	return sl,ol
end
function s.patch()
	if Duel.ZeroGravitationPatched then return end
	Duel.ZeroGravitationPatched=true
	local GMG,GMGC,GFMC,IEMC,SMC=Duel.GetMatchingGroup,Duel.GetMatchingGroupCount,Duel.GetFirstMatchingCard,Duel.IsExistingMatchingCard,Duel.SelectMatchingCard
	Duel.GetMatchingGroup=function(f,p,sl,ol,...) sl,ol=s.loc(sl,ol) return GMG(f,p,sl,ol,...) end
	Duel.GetMatchingGroupCount=function(f,p,sl,ol,...) sl,ol=s.loc(sl,ol) return GMGC(f,p,sl,ol,...) end
	Duel.GetFirstMatchingCard=function(f,p,sl,ol,...) sl,ol=s.loc(sl,ol) return GFMC(f,p,sl,ol,...) end
	Duel.IsExistingMatchingCard=function(f,p,sl,ol,...) sl,ol=s.loc(sl,ol) return IEMC(f,p,sl,ol,...) end
	Duel.SelectMatchingCard=function(sp,f,p,sl,ol,...) sl,ol=s.loc(sl,ol) return SMC(sp,f,p,sl,ol,...) end
	--A card added from the opponent's Deck goes to the hand of the player using the effect
	local STH=Duel.SendtoHand
	Duel.SendtoHand=function(tg,p,r,...)
		if p==nil and s.active() and Duel.GetCurrentChain()>0 then
			local cp=Duel.GetChainInfo(0,CHAININFO_TRIGGERING_PLAYER)
			local g=type(tg)=="Card" and Group.FromCards(tg) or tg
			if cp and #g>0 and g:FilterCount(Card.IsLocation,nil,LOCATION_DECK)==#g and g:IsExists(Card.IsControler,1,nil,1-cp) then
				p=cp
			end
		end
		return STH(tg,p,r,...)
	end
	--Draws by card effects: choose your Deck or your opponent's Deck
	local DRAW=Duel.Draw
	Duel.Draw=function(p,ct,r,...)
		if s.active() and type(r)=="number" and r&REASON_EFFECT~=0 and ct and ct>0
			and Duel.GetFieldGroupCount(1-p,LOCATION_DECK,0)>=ct
			and Duel.SelectOption(p,aux.Stringid(id,1),aux.Stringid(id,2))==1 then
			local g=Duel.GetDecktopGroup(1-p,ct)
			Duel.DisableShuffleCheck()
			return STH(g,p,REASON_EFFECT|REASON_DRAW)
		end
		return DRAW(p,ct,r,...)
	end
end

--魔法効果の矢
--Living Arrow (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
--Partes basadas en los scripts de Project Ignis (EDOPro) "Transaction Rollback" y "Curse Transfer", con licencia AGPL-3.0.
local s,id=GetID()
function s.initial_effect(c)
	--Negate an opponent's Spell that would affect your monsters, destroy it and apply it as your own
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetCondition(s.negcon)
	e1:SetTarget(s.negtg)
	e1:SetOperation(s.negop)
	c:RegisterEffect(e1)
	--Apply the effect of a Spell in your opponent's GY
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))
	e2:SetType(EFFECT_TYPE_ACTIVATE)
	e2:SetCode(EVENT_FREE_CHAIN)
	e2:SetHintTiming(0,TIMINGS_CHECK_MONSTER_E)
	e2:SetTarget(s.cptg)
	e2:SetOperation(s.cpop)
	c:RegisterEffect(e2)
end
s.listed_names={id,276447246}
--Effect categories that affect monsters
s.moncats={CATEGORY_DESTROY,CATEGORY_RELEASE,CATEGORY_REMOVE,CATEGORY_TOHAND,CATEGORY_TODECK,CATEGORY_TOGRAVE,
	CATEGORY_TOEXTRA,CATEGORY_POSITION,CATEGORY_CONTROL,CATEGORY_DISABLE,CATEGORY_EQUIP,CATEGORY_ATKCHANGE,
	CATEGORY_DEFCHANGE,CATEGORY_LVCHANGE}
--Normal or Quick-Play Spell
function s.nqspell(c)
	return c:IsNormalSpell() or c:IsQuickPlaySpell()
end
---------------------------------------------------------------------------
--● Negate, destroy, then apply the negated effect as if you activated it
---------------------------------------------------------------------------
function s.mymon(c,tp)
	return c:IsControler(tp) and c:IsLocation(LOCATION_MZONE)
end
function s.affectsmine(ev,tp)
	local tg=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	if tg and tg:IsExists(s.mymon,1,nil,tp) then return true end
	for _,cat in ipairs(s.moncats) do
		for _,getinfo in ipairs({Duel.GetOperationInfo,Duel.GetPossibleOperationInfo}) do
			local ex,g,_,p,loc=getinfo(ev,cat)
			if ex then
				if g and #g>0 then
					if g:IsExists(s.mymon,1,nil,tp) then return true end
				elseif loc and (loc&LOCATION_MZONE)~=0 and (p==tp or p==PLAYER_ALL) then
					return true
				end
			end
		end
	end
	return false
end
function s.negcon(e,tp,eg,ep,ev,re,r,rp)
	return rp==1-tp and re:IsActiveType(TYPE_SPELL) and Duel.IsChainNegatable(ev) and s.affectsmine(ev,tp)
end
function s.negtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
	if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
	end
end
--Only the activation of a Normal or Quick-Play Spell Card can be applied again
function s.canapply(te)
	return te:IsHasType(EFFECT_TYPE_ACTIVATE) and (te:GetActiveType()==TYPE_SPELL or te:IsActiveType(TYPE_QUICKPLAY))
end
function s.negop(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.NegateActivation(ev) then return end
	if re:GetHandler():IsRelateToEffect(re) then
		Duel.Destroy(eg,REASON_EFFECT)
	end
	if not s.canapply(re) then return end
	local tg,op=re:GetTarget(),re:GetOperation()
	local ceg,cep,cev,cre,cr,crp=nil,0,0,nil,0,0
	if re:GetCode()~=EVENT_FREE_CHAIN then
		local res
		res,ceg,cep,cev,cre,cr,crp=Duel.CheckEvent(re:GetCode(),true)
		if not res then return end
	end
	local cat,prop=e:GetCategory(),e:GetProperty()
	e:SetCategory(re:GetCategory())
	e:SetProperty(re:GetProperty())
	Duel.ClearTargetCard()
	if not tg or tg(e,tp,ceg,cep,cev,cre,cr,crp,0) then
		Duel.BreakEffect()
		if tg then tg(e,tp,ceg,cep,cev,cre,cr,crp,1) end
		if op then op(e,tp,ceg,cep,cev,cre,cr,crp) end
	end
	e:SetCategory(cat)
	e:SetProperty(prop)
end
---------------------------------------------------------------------------
--● Apply a Spell from your opponent's GY
---------------------------------------------------------------------------
function s.fuseff(c)
	for _,te in ipairs({c:GetActivateEffect()}) do
		if te:IsHasCategory(CATEGORY_FUSION_SUMMON) then return te end
	end
	return nil
end
function s.monaffect(te)
	for _,cat in ipairs(s.moncats) do
		if te:IsHasCategory(cat) then return true end
	end
	return false
end
--Fusion Materials: both fields, both GYs, both banishments, your hand and your Deck
function s.matfilter(c,e,tp)
	if not c:IsMonster() or not c:IsCanBeFusionMaterial() or c:IsImmuneToEffect(e) then return false end
	if c:IsLocation(LOCATION_REMOVED) then return c:IsFaceup() end
	if c:IsLocation(LOCATION_MZONE) and c:IsControler(1-tp) then return c:IsFaceup() end
	if c:IsLocation(LOCATION_GRAVE) then return aux.nvfilter(c) end
	return true
end
function s.matpool(e,tp)
	return Duel.GetMatchingGroup(s.matfilter,tp,LOCATION_HAND|LOCATION_DECK|LOCATION_MZONE|LOCATION_GRAVE|LOCATION_REMOVED,
		LOCATION_MZONE|LOCATION_GRAVE|LOCATION_REMOVED,nil,e,tp)
end
--The Fusion Monster is Summoned to your opponent's field
function s.fusfilter(c,e,tp,mg)
	return c:IsType(TYPE_FUSION) and c:IsCanBeSpecialSummoned(e,SUMMON_TYPE_FUSION,tp,false,false,POS_FACEUP,1-tp)
		and c:CheckFusionMaterial(mg,nil,1-tp)
end
function s.fuscheck(e,tp)
	local mg=s.matpool(e,tp)
	Fusion.ExtraGroup=mg
	local res=Duel.IsExistingMatchingCard(s.fusfilter,tp,LOCATION_EXTRA,0,1,nil,e,tp,mg)
	Fusion.ExtraGroup=nil
	return res
end
function s.cpfilter(c,e,tp)
	if not s.nqspell(c) or c:IsCode(id,276447246) then return false end
	local fe=s.fuseff(c)
	if fe then
		local con=fe:GetCondition()
		return (not con or con(fe,tp,nil,0,0,nil,0,0)) and s.fuscheck(e,tp)
	end
	local te=c:CheckActivateEffect(false,true,false)
	return te~=nil and s.monaffect(te)
end
function s.cptg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then
		local te=e:GetLabelObject()
		if e:GetLabel()==1 or not te then return false end
		local tg=te:GetTarget()
		return tg and tg(e,tp,eg,ep,ev,re,r,rp,0,chkc)
	end
	if chk==0 then return Duel.IsExistingTarget(s.cpfilter,tp,0,LOCATION_GRAVE,1,nil,e,tp) end
	e:SetCategory(0)
	e:SetProperty(EFFECT_FLAG_CARD_TARGET)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local tc=Duel.SelectTarget(tp,s.cpfilter,tp,0,LOCATION_GRAVE,1,1,nil,e,tp):GetFirst()
	if s.fuseff(tc) then
		--Fusion Summon: done by this card's own procedure (see s.fusop)
		e:SetLabel(1)
		e:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_FUSION_SUMMON)
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_EXTRA)
		return
	end
	e:SetLabel(0)
	local te,ceg,cep,cev,cre,cr,crp=tc:CheckActivateEffect(false,true,true)
	Duel.ClearTargetCard()
	tc:CreateEffectRelation(e)
	local tg=te:GetTarget()
	e:SetCategory(te:GetCategory())
	e:SetProperty(te:GetProperty())
	if tg then tg(e,tp,ceg,cep,cev,cre,cr,crp,1) end
	te:SetLabelObject(e:GetLabelObject())
	e:SetLabelObject(te)
	--The operation info of the copied Spell is kept: some Spells (e.g. "Mystic Box") read it when they resolve
end
function s.cpop(e,tp,eg,ep,ev,re,r,rp)
	if e:GetLabel()==1 then
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) then s.fusop(e,tp) end
		return
	end
	local te=e:GetLabelObject()
	if not te then return end
	e:SetLabelObject(te:GetLabelObject())
	if not te:GetHandler():IsRelateToEffect(e) then return end
	local op=te:GetOperation()
	if op then op(e,tp,eg,ep,ev,re,r,rp) end
end
function s.fusop(e,tp)
	local mg=s.matpool(e,tp)
	Fusion.ExtraGroup=mg
	local sg=Duel.GetMatchingGroup(s.fusfilter,tp,LOCATION_EXTRA,0,nil,e,tp,mg)
	if #sg==0 then Fusion.ExtraGroup=nil return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local fc=sg:Select(tp,1,1,nil):GetFirst()
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FMATERIAL)
	local mat=Duel.SelectFusionMaterial(tp,fc,mg,nil,1-tp)
	Fusion.ExtraGroup=nil
	if not mat or #mat==0 then return end
	fc:SetMaterial(mat)
	--Materials in the GY are banished; the rest are sent to the GY
	local gy=mat:Filter(Card.IsLocation,nil,LOCATION_GRAVE)
	local rest=mat:Clone()
	rest:Sub(gy)
	if #gy>0 then Duel.Remove(gy,POS_FACEUP,REASON_EFFECT|REASON_MATERIAL|REASON_FUSION) end
	if #rest>0 then Duel.SendtoGrave(rest,REASON_EFFECT|REASON_MATERIAL|REASON_FUSION) end
	Duel.BreakEffect()
	if Duel.SpecialSummon(fc,SUMMON_TYPE_FUSION,tp,1-tp,false,false,POS_FACEUP)>0 then
		fc:CompleteProcedure()
	end
end

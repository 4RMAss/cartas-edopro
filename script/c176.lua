--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--融合 (Manga)
--Polymerization (Manga)
--Base: script OFICIAL c24094653, sin tocar su logica de fusion.
--Anadido sobre el oficial:
--  (a) Dos RESTRICCIONES de velocidad:
--        - en Main Phase no se puede activar en Cadena en respuesta a otra carta
--          (solo con la Cadena vacia, como una Magia Normal)
--        - no se puede activar durante TU propia Battle Phase
--      El resto de momentos quedan como en una Magia Rapida normal, incluido el
--      turno del rival fuera de su Battle Phase (Yu-Gi-Oh! R, cap. 20: Jonouchi).
--  (b) Si se activa mientras un monstruo DEL RIVAL esta atacando, el Monstruo de
--      Fusion invocado pasa a ser el NUEVO OBJETIVO del ataque y este continua
--      contra el (Yu-Gi-Oh! R, cap. 38: Arcana Knight Joker).
--  (c) Durante la Battle Phase DEL RIVAL los materiales solo pueden salir del CAMPO:
--      no valen los de la mano. Fuera de esa fase sigue siendo "mano o campo".
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_FUSION_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.actcon)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--velocidad: solo las dos restricciones pedidas; lo demas queda como Magia Rapida
--Solo se puede activar mientras "Anime Mode (Creator Mode)" (600000238) o
--"Manga Mode (Creator Mode)" (189) este desterrada boca arriba: es la regla del
--manga que permite jugar estas Magias Normales como si fueran de Juego Rapido.
--Las dos cartas de modo se destierran boca arriba al empezar el duelo, asi que basta
--con buscarlas en la zona de desterradas de cualquiera de los dos jugadores.
local MODE_ANIME=600000238
local MODE_MANGA=189
function s.modefilter(c)
	return c:IsFaceup() and (c:IsCode(MODE_ANIME) or c:IsCode(MODE_MANGA))
end
function s.modeon()
	return Duel.IsExistingMatchingCard(s.modefilter,0,LOCATION_REMOVED,LOCATION_REMOVED,1,nil)
end
--en tu propio turno, como una Magia Normal: Main Phase y Cadena vacia.
--La velocidad de Juego Rapido queda para el turno del rival.
function s.ownturnok(tp)
	if Duel.GetTurnPlayer()~=tp then return true end
	local ph=Duel.GetCurrentPhase()
	return (ph==PHASE_MAIN1 or ph==PHASE_MAIN2) and Duel.GetCurrentChain()==0
end
function s.actcon(e,tp,eg,ep,ev,re,r,rp)
	if not s.ownturnok(tp) then return false end
	if not s.modeon() then return false end
	local ph=Duel.GetCurrentPhase()
	local mybp=Duel.GetTurnPlayer()==tp
		and (ph==PHASE_BATTLE_START or ph==PHASE_BATTLE_STEP
			or ph==PHASE_DAMAGE or ph==PHASE_DAMAGE_CAL or ph==PHASE_BATTLE)
	--(1) nunca durante tu propia Battle Phase
	if mybp then return false end
	--(2) en Main Phase, solo con la Cadena vacia: no se encadena en respuesta a otra carta
	if (ph==PHASE_MAIN1 or ph==PHASE_MAIN2) and Duel.GetCurrentChain()~=0 then return false end
	return true
end
--(c) estamos en la Battle Phase del RIVAL?
function s.oppbp(tp)
	local ph=Duel.GetCurrentPhase()
	return Duel.GetTurnPlayer()~=tp
		and (ph==PHASE_BATTLE_START or ph==PHASE_BATTLE_STEP
			or ph==PHASE_DAMAGE or ph==PHASE_DAMAGE_CAL or ph==PHASE_BATTLE)
end
--materiales utilizables: en la Battle Phase del rival, solo los del campo
function s.usablemat(tp)
	local mg=Duel.GetFusionMaterial(tp)
	if s.oppbp(tp) then mg=mg:Filter(Card.IsOnField,nil) end
	return mg
end
function s.filter1(c,e)
	return not c:IsImmuneToEffect(e)
end
function s.filter2(c,e,tp,m,f,chkf)
	return c:IsType(TYPE_FUSION) and (not f or f(c))
		and c:IsCanBeSpecialSummoned(e,SUMMON_TYPE_FUSION,tp,false,false) and c:CheckFusionMaterial(m,nil,chkf)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then
		local chkf=tp
		local mg1=s.usablemat(tp)
		local res=Duel.IsExistingMatchingCard(s.filter2,tp,LOCATION_EXTRA,0,1,nil,e,tp,mg1,nil,chkf)
		if not res then
			local ce=Duel.GetChainMaterial(tp)
			if ce~=nil then
				local fgroup=ce:GetTarget()
				local mg2=fgroup(ce,e,tp)
				local mf=ce:GetValue()
				res=Duel.IsExistingMatchingCard(s.filter2,tp,LOCATION_EXTRA,0,1,nil,e,tp,mg2,mf,chkf)
			end
		end
		return res
	end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_EXTRA)
end
--(b) redirigir el ataque al monstruo recien invocado
function s.redirect(e,tp,tc)
	if not (tc and tc:IsLocation(LOCATION_MZONE) and tc:IsControler(tp) and tc:IsFaceup()) then return end
	local at=Duel.GetAttacker()
	if not at then return end
	if not (at:IsControler(1-tp) and at:IsRelateToBattle()) then return end
	if at:IsImmuneToEffect(e) then return end
	if at==tc then return end
	Duel.ChangeAttackTarget(tc)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local chkf=tp
	local mg1=s.usablemat(tp):Filter(s.filter1,nil,e)
	local sg1=Duel.GetMatchingGroup(s.filter2,tp,LOCATION_EXTRA,0,nil,e,tp,mg1,nil,chkf)
	local mg2=nil
	local sg2=nil
	local ce=Duel.GetChainMaterial(tp)
	if ce~=nil then
		local fgroup=ce:GetTarget()
		mg2=fgroup(ce,e,tp)
		local mf=ce:GetValue()
		sg2=Duel.GetMatchingGroup(s.filter2,tp,LOCATION_EXTRA,0,nil,e,tp,mg2,mf,chkf)
	end
	if sg1:GetCount()>0 or (sg2~=nil and sg2:GetCount()>0) then
		local sg=sg1:Clone()
		if sg2 then sg:Merge(sg2) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local tg=sg:Select(tp,1,1,nil)
		local tc=tg:GetFirst()
		if sg1:IsContains(tc) and (sg2==nil or not sg2:IsContains(tc) or not Duel.SelectYesNo(tp,ce:GetDescription())) then
			local mat1=Duel.SelectFusionMaterial(tp,tc,mg1,nil,chkf)
			tc:SetMaterial(mat1)
			Duel.SendtoGrave(mat1,REASON_EFFECT+REASON_MATERIAL+REASON_FUSION)
			Duel.BreakEffect()
			Duel.SpecialSummon(tc,SUMMON_TYPE_FUSION,tp,tp,false,false,POS_FACEUP)
		else
			local mat2=Duel.SelectFusionMaterial(tp,tc,mg2,nil,chkf)
			local fop=ce:GetOperation()
			fop(ce,e,tp,tc,mat2)
		end
		tc:CompleteProcedure()
		s.redirect(e,tp,tc)
	end
end

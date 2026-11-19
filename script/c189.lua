--Script: 4RMAss · Anime Server by 4RMAss
--Manga Mode (Creator Mode)
--Copia exacta de "Anime Mode (Creator Mode)" (600000238) mas una regla propia:
--  * los monstruos de Fusion NO pueden atacar el turno en que fueron Invocados por
--    Fusion. Es lo que le da sentido al efecto de "Quick Attack".
--Se le dio un id BAJO a proposito: aux.Stringid desborda 32 bits por encima de
--268.435.455, asi que con el id 600000238 el menu de Campos de Velocidad salia "???".
--Con 189 los nombres se leen bien.
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
if not EFFECT_DIVINE_LIGHT then EFFECT_DIVINE_LIGHT=900000004 end
s.roll_dice=true
s.toss_coin=true

function s.initial_effect(c)
    c:EnableReviveLimit()
    -- (disfraz) quitar el tipo Link mientras esté en juego -> se ve/comporta como Skill, no como monstruo Link
    local ed=Effect.CreateEffect(c)
    ed:SetType(EFFECT_TYPE_SINGLE)
    ed:SetCode(EFFECT_REMOVE_TYPE)
    ed:SetProperty(EFFECT_FLAG_SINGLE_RANGE+EFFECT_FLAG_IGNORE_IMMUNE)
    ed:SetRange(LOCATION_EXTRA+LOCATION_MZONE+LOCATION_GRAVE+LOCATION_REMOVED)
    ed:SetValue(TYPE_LINK)
    c:RegisterEffect(ed)
    -- (1) al iniciar el duelo: se destierra a sí misma desde el Extra Deck (como una Skill)
    local e0=Effect.CreateEffect(c)
    e0:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    e0:SetCode(EVENT_STARTUP)
    e0:SetRange(LOCATION_EXTRA)
    e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
    e0:SetCountLimit(1)
    e0:SetOperation(s.banishself)
    c:RegisterEffect(e0)
    local e0b=e0:Clone()
    e0b:SetCode(EVENT_ADJUST)
    c:RegisterEffect(e0b)
end
function s.banishself(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    if c:IsLocation(LOCATION_EXTRA) then
        Duel.Remove(c,POS_FACEUP,REASON_RULE)
        -- "Infectar" la Skill: inmune a TODOS los efectos (tuyos y del rival) para que no
        -- vuelva al Deck ni pueda ser retirada del destierro, y mantenga sus reglas activas.
        local eimm=Effect.CreateEffect(c)
        eimm:SetType(EFFECT_TYPE_SINGLE)
        eimm:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
        eimm:SetCode(EFFECT_IMMUNE_EFFECT)
        eimm:SetRange(LOCATION_REMOVED)
        eimm:SetValue(function(e,te) return true end)  -- inmune a cualquier efecto
        c:RegisterEffect(eimm)
        local eind=Effect.CreateEffect(c)
        eind:SetType(EFFECT_TYPE_SINGLE)
        eind:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        eind:SetCode(EFFECT_CANNOT_TO_DECK)
        eind:SetRange(LOCATION_REMOVED)
        c:RegisterEffect(eind)
        -- (Manga Mode) los monstruos de Fusion no atacan el turno en que fueron
        -- Invocados por Fusion. Vale para ambos jugadores.
        -- Excepcion: "Quick Attack" (511004016) marca al monstruo elegido con un
        -- efecto de codigo 511004016; ese monstruo si puede atacar. Es el mismo
        -- mecanismo que ya usan Battle City (511004014) y Virtual World (153999999).
        local efus=Effect.CreateEffect(c)
        efus:SetType(EFFECT_TYPE_FIELD)
        efus:SetCode(EFFECT_CANNOT_ATTACK)
        efus:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
        efus:SetRange(LOCATION_REMOVED)
        efus:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
        efus:SetTarget(s.fusnoatk)
        c:RegisterEffect(efus)
        -- (Manga Mode) "The Wicked Eraser": si en el momento de ser Invocado hay un
        -- "Arcana Knight Joker" boca arriba en el campo, Manga Mode cuenta como 2
        -- cartas mas en el campo para su ATK/DEF, o sea +2000, hasta el final de
        -- ese turno (Yu-Gi-Oh! R: Eraser llega a 4000 con solo 2 cartas enfrente).
        -- Va como EFFECT_TYPE_CONTINUOUS, igual que las demas reglas de este modo:
        -- se aplica solo, sin pasar por la Cadena.
        local eera=Effect.CreateEffect(c)
        eera:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
        eera:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
        eera:SetCode(EVENT_SUMMON_SUCCESS)
        eera:SetRange(LOCATION_REMOVED)
        eera:SetOperation(s.eraop)
        c:RegisterEffect(eera)
        local eera2=eera:Clone()
        eera2:SetCode(EVENT_SPSUMMON_SUCCESS)
        c:RegisterEffect(eera2)
        -- montar las reglas del modo (dados/monedas/boca arriba) y ofrecer campo a ambos
        s.op(e,c:GetControler(),eg,ep,ev,re,r,rp)
    end
end
-- adaptador: al activar la Skill desde el destierro, ejecutar la lógica original de Turbo Duel
function s.skillop(e,tp,eg,ep,ev,re,r,rp)
    s.op(e,tp,eg,ep,ev,re,r,rp)
end

function s.op(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    local speedWorlds={511600371,511600372,511600373,511600374,100000186}

    for p=0,1 do
        -- preguntar a CADA jugador si quiere activar un campo (tú y el rival)
        if Duel.SelectYesNo(p,aux.Stringid(id,5)) then
            -- Menú con los NOMBRES (guardados como strings str1..str5 de esta carta en el cdb).
            -- aux.Stringid(id,N): N=0 -> str1, N=1 -> str2, ... N=4 -> str5
            local sel=Duel.SelectOption(p,
                aux.Stringid(id,0),
                aux.Stringid(id,1),
                aux.Stringid(id,2),
                aux.Stringid(id,3),
                aux.Stringid(id,4)) + 1
            local res=speedWorlds[sel]

            local sW=Duel.CreateToken(p,res)
            sW:ReplaceEffect(res,0)
            Duel.MoveToField(sW,p,p,LOCATION_FZONE,POS_FACEUP,true)

            --========================
            -- Infected Field (protecciones al token)
            --========================
            local e1=Effect.CreateEffect(c)
            e1:SetType(EFFECT_TYPE_SINGLE)
            e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
            e1:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
            e1:SetValue(1)
            sW:RegisterEffect(e1)

            local e2=e1:Clone()
            e2:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
            sW:RegisterEffect(e2)

            local e3=e1:Clone()
            e3:SetCode(EFFECT_CANNOT_TO_DECK)
            sW:RegisterEffect(e3)

            local e4=e1:Clone()
            e4:SetCode(EFFECT_CANNOT_TO_GRAVE)
            sW:RegisterEffect(e4)

            local e5=e1:Clone()
            e5:SetCode(EFFECT_CANNOT_REMOVE)
            sW:RegisterEffect(e5)

            local e6=e1:Clone()
            e6:SetCode(EFFECT_CANNOT_DISABLE)
            sW:RegisterEffect(e6)

            --========================
            -- Player restriction:
            -- No puede activar/colocar otros Field Spells
            --========================
            local e7=Effect.CreateEffect(c)
            e7:SetType(EFFECT_TYPE_FIELD)
            e7:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
            e7:SetCode(EFFECT_CANNOT_ACTIVATE)
            e7:SetTargetRange(1,0)
            e7:SetValue(s.aclimit)
            e7:SetLabelObject(sW)
            Duel.RegisterEffect(e7,p)

            local e8=e7:Clone()
            e8:SetCode(EFFECT_CANNOT_SSET)
            e8:SetTarget(s.setlimit)
            Duel.RegisterEffect(e8,p)
        end
    end

    --========================================
    -- ROBO DEL PRIMER TURNO:
    -- el jugador que juega primero SÍ roba 1 carta en su turno 1
    -- (normalmente se salta la Draw Phase del turno 1)
    --========================================
    local edraw=Effect.CreateEffect(c)
    edraw:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    edraw:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
    edraw:SetCode(EVENT_PHASE+PHASE_DRAW)
    edraw:SetCountLimit(1)
    edraw:SetCondition(s.firstdrawcon)
    edraw:SetOperation(s.firstdrawop)
    Duel.RegisterEffect(edraw,0)

    --========================================
    -- REGLA GLOBAL:
    -- Cartas que vuelven al deck van al fondo
    -- y se hace shuffle del resto
    --========================================
    -- REGLA (ambos jugadores): los monstruos invocados/colocados salen BOCA ARRIBA en modo normal
    -- Invocación normal boca arriba para AMBOS (patrón de 聖なる輝き / Divine Light).
    -- SOLO forzamos boca arriba con EFFECT_DIVINE_LIGHT; NO se restringe el poder setear
    -- monstruos boca abajo (el jugador conserva esa opción con normalidad).
    if EFFECT_DIVINE_LIGHT then
        for pl=0,1 do
            local edl=Effect.CreateEffect(c)
            edl:SetType(EFFECT_TYPE_FIELD)
            edl:SetCode(EFFECT_DIVINE_LIGHT)
            edl:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
            edl:SetTargetRange(1,1)
            Duel.RegisterEffect(edl,pl)
        end
    end

    for p=0,1 do
        local e9=Effect.CreateEffect(c)
        e9:SetType(EFFECT_TYPE_FIELD)
        e9:SetCode(EFFECT_TO_DECK_REDIRECT)
        e9:SetTargetRange(
            LOCATION_HAND+LOCATION_GRAVE+LOCATION_ONFIELD+LOCATION_REMOVED,
            LOCATION_HAND+LOCATION_GRAVE+LOCATION_ONFIELD+LOCATION_REMOVED
        )
        e9:SetValue(LOCATION_DECKBOT)
        Duel.RegisterEffect(e9,p)

        local e10=Effect.CreateEffect(c)
        e10:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
        e10:SetCode(EVENT_TO_DECK)
        e10:SetOperation(s.shuffleop)
        Duel.RegisterEffect(e10,p)
    end

    --========================================
    -- DADOS y MONEDAS: manipulables SOLO por el jugador que activó la Skill (tp).
    -- Patrón EVENT_TOSS_*_NEGATE: intercepta DESPUÉS del lanzamiento y permite reescribir el resultado.
    --========================================
    -- Interceptores ligados al ACTIVADOR (tp), como en Probability Change (c195).
    -- Se registran con Duel.RegisterEffect(e,tp): así 'tp' dentro de las ops ya es el activador
    -- y NO dependemos de e:GetHandler() (la carta está desterrada).
    local edice=Effect.CreateEffect(c)
    edice:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    edice:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
    edice:SetCode(EVENT_TOSS_DICE_NEGATE)
    edice:SetOperation(s.diceop)
    Duel.RegisterEffect(edice,tp)

    --========================================
    -- SELECCIONES AL AZAR: que las elija el jugador (como dados/monedas).
    -- Sustituye Group.RandomSelect por una version que ofrece elegir a mano.
    --========================================
    s.chooser=tp
    if not s.random_hooked then
        s.random_hooked=true
        local oldRandomSelect=Group.RandomSelect
        Group.RandomSelect=function(g,player,count,...)
            local ok,res=pcall(function()
                if s.chooser~=nil and player==s.chooser and g and count and g:GetCount()>count then
                    if Duel.SelectYesNo(player,aux.Stringid(id,8)) then
                        Duel.Hint(HINT_SELECTMSG,player,HINTMSG_TARGET)
                        return g:Select(player,count,count,nil)
                    end
                end
                return nil
            end)
            if ok and res then return res end
            return oldRandomSelect(g,player,count,...)
        end
    end

    local ecoin=Effect.CreateEffect(c)
    ecoin:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    ecoin:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
    ecoin:SetCode(EVENT_TOSS_COIN_NEGATE)
    ecoin:SetOperation(s.coinop)
    Duel.RegisterEffect(ecoin,tp)
end
-- === Manipulación de DADOS (solo el activador) — patrón EVENT_TOSS_DICE_NEGATE + re-tiro ===
function s.diceop(e,tp,eg,ep,ev,re,r,rp)
    if ep~=tp then return end
    if not Duel.SelectYesNo(tp,aux.Stringid(id,6)) then return end
    Duel.Hint(HINT_CARD,0,id)
    local dc={Duel.GetDiceResult()}
    local ct=(ev&0xff)+(ev>>16)
    local ac=1
    if ct>1 then
        local nums={}
        for i=1,ct do nums[i]=i end
        Duel.Hint(HINT_SELECTMSG,tp,aux.Stringid(id,7))
        ac=Duel.AnnounceNumber(tp,table.unpack(nums))
    end
    Duel.Hint(HINT_SELECTMSG,tp,aux.Stringid(id,7))
    dc[ac]=Duel.AnnounceNumber(tp,1,2,3,4,5,6)
    Duel.SetDiceResult(table.unpack(dc))
end
-- === Manipulación de MONEDAS (solo el activador) ===
function s.coinop(e,tp,eg,ep,ev,re,r,rp)
    if ep~=tp then return end
    if not Duel.SelectYesNo(tp,aux.Stringid(id,6)) then return end
    Duel.Hint(HINT_CARD,0,id)
    local cn={Duel.GetCoinResult()}
    local ct=(ev&0xff)+(ev>>16)
    local ac=1
    if ct>1 then
        local nums={}
        for i=1,ct do nums[i]=i end
        Duel.Hint(HINT_SELECTMSG,tp,aux.Stringid(id,7))
        ac=Duel.AnnounceNumber(tp,table.unpack(nums))
    end
    cn[ac]=Duel.SelectOption(tp,60,61)
    Duel.SetCoinResult(table.unpack(cn))
end
-- condicion: solo interviene cuando quien lanza es el jugador que activó la Skill

--========================================
-- Shuffle: shuffle del deck salvo las cartas
-- que acaban de irse al fondo
--========================================
function s.shuffleop(e,tp,eg,ep,ev,re,r,rp)
    local ct=eg:GetCount()
    if ct>0 then
        local tc=eg:GetFirst()
        local owner=tc:GetOwner()
        local deckct=Duel.GetFieldGroupCount(owner,LOCATION_DECK,0)
        if deckct>ct then
            s.ShuffleDeckExceptBottom(owner,ct)
        end
    end
end

function s.ShuffleDeckExceptBottom(tp,bottom_count)
    local g=Duel.GetFieldGroup(tp,LOCATION_DECK,0)
    local ct=g:GetCount()
    if ct<=bottom_count then return end

    local bottom_cards={}
    for i=1,bottom_count do
        local bc=Duel.GetDecktopGroup(tp,0):GetFirst()
        if bc then
            table.insert(bottom_cards,bc)
            Duel.MoveSequence(bc,SEQ_DECKTOP)
        end
    end

    Duel.ShuffleDeck(tp)

    for i=#bottom_cards,1,-1 do
        Duel.MoveSequence(bottom_cards[i],SEQ_DECKBOTTOM)
    end
end

--Cannot activate other Field Spells
function s.aclimit(e,re,tp)
    local sw=e:GetLabelObject()
    return re:GetHandler():IsType(TYPE_FIELD) and re:GetHandler()~=sw
end

--Cannot set other Field Spells
function s.setlimit(e,c,tp)
    local sw=e:GetLabelObject()
    return c:IsType(TYPE_FIELD) and c~=sw
end

--========================================
-- Elección manual de dados

-- Robo del primer turno: solo en el turno 1, para el jugador de turno
function s.firstdrawcon(e,tp,eg,ep,ev,re,r,rp)
    return Duel.GetTurnCount()==1
end
function s.firstdrawop(e,tp,eg,ep,ev,re,r,rp)
    local tep=Duel.GetTurnPlayer()
    Duel.Draw(tep,1,REASON_RULE)
end

--"el turno en que fue Invocado por Fusion": se compara el turno en que la carta llego
--al campo con el turno actual. Es el idioma que funciona en este core.
--========================================
-- The Wicked Eraser + Arcana Knight Joker
--========================================
--El ATK/DEF de Eraser es "numero de cartas que controla tu rival x 1000", calculado
--con EFFECT_SET_ATTACK. Un EFFECT_UPDATE_ATTACK se suma DESPUES del SET solo si se
--registro mas tarde, por eso el +2000 se pone sobre el propio Eraser en el momento
--de la Invocacion y no como efecto permanente de Manga Mode: registrado al empezar
--el duelo, el SET de Eraser lo borraria.
--Se aceptan las dos versiones de cada carta, la del paquete y la oficial.
--DURACION: el +2000 dura hasta que Eraser combate; se retira al terminar el Damage
--Step de SU batalla (EVENT_DAMAGE_STEP_END con la comprobacion estandar de
--aux.dsercon). Si no llega a combatir, se cae igualmente al final del turno.
--No se usa un simple RESET_PHASE+PHASE_DAMAGE porque eso lo borraria en el Damage
--Step de cualquier otro monstruo que atacase antes que Eraser.
function s.erafilter(c)
	return c:IsCode(513000139,57793869)
end
function s.jokerfilter(c)
	return c:IsFaceup() and c:IsCode(513000187,6150044)
end
function s.eraop(e,tp,eg,ep,ev,re,r,rp)
	if not eg then return end
	--"Arcana Knight Joker" en el campo EN ESTE MOMENTO, de cualquiera de los dos lados
	if not Duel.IsExistingMatchingCard(s.jokerfilter,0,LOCATION_MZONE,LOCATION_MZONE,1,nil) then return end
	local g=eg:Filter(s.erafilter,nil)
	local tc=g:GetFirst()
	while tc do
		if tc:IsFaceup() and tc:IsLocation(LOCATION_MZONE) then
			local ea=Effect.CreateEffect(e:GetHandler())
			ea:SetType(EFFECT_TYPE_SINGLE)
			ea:SetCode(EFFECT_UPDATE_ATTACK)
			ea:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
			ea:SetValue(2000)
			ea:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
			tc:RegisterEffect(ea)
			local ed=ea:Clone()
			ed:SetCode(EFFECT_UPDATE_DEFENSE)
			tc:RegisterEffect(ed)
			ea:SetLabelObject(ed)
			--se retira en cuanto Eraser termina su propia batalla
			local erem=Effect.CreateEffect(e:GetHandler())
			erem:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
			erem:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
			erem:SetCode(EVENT_DAMAGE_STEP_END)
			erem:SetLabelObject(ea)
			erem:SetOperation(s.eraclear)
			erem:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
			tc:RegisterEffect(erem)
		end
		tc=g:GetNext()
	end
end
function s.eraclear(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not (c:IsRelateToBattle() or c:IsStatus(STATUS_BATTLE_DESTROYED)) then return end
	local ea=e:GetLabelObject()
	if ea then
		local ed=ea:GetLabelObject()
		if ed then ed:Reset() end
		ea:Reset()
	end
	e:Reset()
end

--"Quick Attack" (511004016) exime al monstruo que marca: registra sobre el un efecto
--con ese codigo, igual que para Battle City y Virtual World.
function s.fusnoatk(e,c)
	return c:IsType(TYPE_FUSION)
		and c:IsSummonType(SUMMON_TYPE_FUSION)
		and c:GetTurnID()==Duel.GetTurnCount()
		and not c:IsHasEffect(511004016)
end

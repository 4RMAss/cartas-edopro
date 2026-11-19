--Script: 4RMAss · Anime Server by 4RMAss
--コード・チェンジ
--Code Change
if not GetID then function GetID() return self_table,self_code end end
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_ANNOUNCE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	--"Once during the turn this card is activated"
	e1:SetCountLimit(1,id)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
--solo monstruos, en cualquiera de las zonas donde un efecto puede senalarlos
function s.filter(c)
	return c:IsType(TYPE_MONSTER) and (not c:IsLocation(LOCATION_MZONE) or c:IsFaceup())
end
--propias: Deck, mano, campo, cementerio, desterradas y Extra
--del rival: campo, cementerio y desterradas (la mano y el Deck estan ocultos)
local LOC_SELF=LOCATION_DECK+LOCATION_HAND+LOCATION_MZONE+LOCATION_GRAVE+LOCATION_REMOVED+LOCATION_EXTRA
local LOC_OPPO=LOCATION_MZONE+LOCATION_GRAVE+LOCATION_REMOVED
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.filter,tp,LOC_SELF,LOC_OPPO,1,nil) end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local g=Duel.SelectMatchingCard(tp,s.filter,tp,LOC_SELF,LOC_OPPO,1,1,nil)
	local tc=g:GetFirst()
	if not tc then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RACE)
	local race=Duel.AnnounceRace(tp,1,RACE_ALL&~tc:GetRace())
	if not race or race==0 then return end
	e:GetHandler():SetHint(CHINT_RACE,race)
	Duel.Hint(HINT_RACE,0,race)
	--el monstruo pasa a ser del Tipo declarado hasta el final del turno.
	--Sin RESET_EVENT a proposito: debe conservarlo aunque cambie de zona
	--(si estaba en el Deck y se anade a la mano, sigue siendo ese Tipo)
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_CHANGE_RACE)
	e1:SetValue(race)
	e1:SetReset(RESET_PHASE+PHASE_END)
	--no se baraja: el Deck conserva su orden
	Duel.DisableShuffleCheck()
	tc:RegisterEffect(e1)
end

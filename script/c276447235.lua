--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--E-HERO ダーク・ガイア (Anime)
--Evil Hero Dark Gaia (Anime)
--adaptado del script oficial c58332301
local s,id=GetID()
function s.initial_effect(c)
	--1 monstruo de Tipo Demonio + 1 monstruo de Tipo Roca
	c:EnableReviveLimit()
	Fusion.AddProcMix(c,true,true,aux.FilterBoolFunctionEx(Card.IsRace,RACE_FIEND),aux.FilterBoolFunctionEx(Card.IsRace,RACE_ROCK))
	--solo se puede Invocar de Modo Especial con "Dark Fusion" o "Super Polymerization"
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e2:SetCode(EFFECT_SPSUMMON_CONDITION)
	e2:SetValue(s.splimit)
	c:RegisterEffect(e2)
	--su ATK original es la suma del ATK de los materiales usados
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetCode(EFFECT_MATERIAL_CHECK)
	e3:SetValue(s.matcheck)
	c:RegisterEffect(e3)
	--al declarar ataque, los monstruos en Defensa del adversario pasan a Ataque
	local e4=Effect.CreateEffect(c)
	e4:SetCategory(CATEGORY_POSITION)
	e4:SetDescription(aux.Stringid(58332301,0))
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e4:SetCode(EVENT_ATTACK_ANNOUNCE)
	e4:SetTarget(s.postg)
	e4:SetOperation(s.posop)
	c:RegisterEffect(e4)
end
s.material_setcode={SET_HERO,SET_EVIL_HERO}
s.dark_calling=true
s.listed_names={CARD_DARK_FUSION}
--solo con "Dark Fusion" o "Super Polymerization" (y "Dark Calling", cuya invocación
--cuenta como hecha con "Dark Fusion"); se conservan además los casos de EDOPro
function s.splimit(e,se,sp,st)
	local sc=se:GetHandler()
	return sc:IsCode(CARD_DARK_FUSION,CARD_SUPER_POLYMERIZATION,12071500) or aux.EvilHeroLimit(e,se,sp,st)
end
function s.matcheck(e,c)
	local g=c:GetMaterial()
	local atk=0
	local tc=g:GetFirst()
	while tc do
		atk=atk+tc:GetBaseAttack()
		tc=g:GetNext()
	end
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_SET_BASE_ATTACK)
	e1:SetValue(atk)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_DISABLE)
	c:RegisterEffect(e1)
end
function s.postg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDefensePos,tp,0,LOCATION_MZONE,1,nil) end
	local g=Duel.GetMatchingGroup(Card.IsDefensePos,tp,0,LOCATION_MZONE,nil)
	Duel.SetOperationInfo(0,CATEGORY_POSITION,g,g:GetCount(),0,0)
end
function s.posop(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetMatchingGroup(Card.IsDefensePos,tp,0,LOCATION_MZONE,nil)
	--el último true evita que se activen los efectos Flip, como dice el texto
	Duel.ChangePosition(g,0,0,POS_FACEUP_ATTACK,POS_FACEUP_ATTACK,true)
end

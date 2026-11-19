--Script: 4RMAss · Anime Server by 4RMAss
--Basado en el script oficial de Project Ignis (EDOPro), con licencia AGPL-3.0.
--E-HERO マリシャス・デビル (Anime)
--Evil Hero Malicious Fiend (Anime)
--adaptado del script oficial c86676862
local s,id=GetID()
local CARD_MALICIOUS_EDGE=58554959
function s.initial_effect(c)
	--"Evil Hero Malicious Edge" + 1 monstruo de Tipo Demonio de Nivel 6 o más
	c:EnableReviveLimit()
	Fusion.AddProcMix(c,true,true,CARD_MALICIOUS_EDGE,s.ffilter)
	--solo se puede Invocar de Modo Especial con "Dark Fusion" o "Super Polymerization"
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e2:SetCode(EFFECT_SPSUMMON_CONDITION)
	e2:SetValue(s.splimit)
	c:RegisterEffect(e2)
	--durante la Battle Phase del adversario, sus monstruos pasan a Ataque boca arriba
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetCode(EFFECT_SET_POSITION)
	e3:SetProperty(EFFECT_FLAG_SET_AVAILABLE)
	e3:SetRange(LOCATION_MZONE)
	e3:SetTargetRange(0,LOCATION_MZONE)
	e3:SetCondition(s.poscon)
	e3:SetValue(POS_FACEUP_ATTACK)
	c:RegisterEffect(e3)
	--...y cada uno debe atacar a esta carta si puede
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD)
	e4:SetCode(EFFECT_MUST_ATTACK)
	e4:SetRange(LOCATION_MZONE)
	e4:SetCondition(s.poscon)
	e4:SetTargetRange(0,LOCATION_MZONE)
	c:RegisterEffect(e4)
	local e5=e4:Clone()
	e5:SetCode(EFFECT_MUST_ATTACK_MONSTER)
	e5:SetValue(s.atklimit)
	c:RegisterEffect(e5)
end
s.material_setcode={SET_HERO,SET_EVIL_HERO}
s.dark_calling=true
s.listed_names={CARD_DARK_FUSION,CARD_MALICIOUS_EDGE}
function s.ffilter(c,fc,sumtype,tp)
	return c:IsRace(RACE_FIEND,fc,sumtype,tp) and c:IsLevelAbove(6)
end
--solo con "Dark Fusion" o "Super Polymerization" (y "Dark Calling", cuya invocación
--cuenta como hecha con "Dark Fusion"); se conservan además los casos de EDOPro
function s.splimit(e,se,sp,st)
	local sc=se:GetHandler()
	return sc:IsCode(CARD_DARK_FUSION,CARD_SUPER_POLYMERIZATION,12071500) or aux.EvilHeroLimit(e,se,sp,st)
end
function s.poscon(e)
	return Duel.IsTurnPlayer(1-e:GetHandlerPlayer()) and Duel.IsBattlePhase()
end
function s.atklimit(e,c)
	return c==e:GetHandler()
end

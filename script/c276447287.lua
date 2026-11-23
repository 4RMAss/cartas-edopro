--Machine Angel Ritual (Anime)
--Script: 4RMAss · Anime Server by 4RMAss
--Basado en los scripts oficiales de Project Ignis (EDOPro), con licencia AGPL-3.0.
local s,id=GetID()
function s.initial_effect(c)
	Ritual.AddProcEqual(c,aux.FilterBoolFunction(Card.IsSetCard,SET_CYBER_ANGEL))
end
s.listed_series={SET_CYBER_ANGEL}

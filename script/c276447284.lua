--Arcana Knight Joker (Manga)
--Script: 4RMAss · Anime Server by 4RMAss
local s,id=GetID()
function s.initial_effect(c)
	c:EnableReviveLimit()
	Fusion.AddProcMix(c,true,true,64788463,25652259,90876561)
end
s.material_setcode={}

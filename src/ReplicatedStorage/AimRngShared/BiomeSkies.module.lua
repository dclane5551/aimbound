--!nocheck
-- BIOME SKIES: the six skybox faces per dungeon biome. UPDATE 4 SKIES v4: real Poly Haven CC0 HDRI skies composited with
-- each biome's signature by tools/hdri_sky.py (wired by tools/sky_apply.py; credits docs/CREDITS_SKIES.md). Face mapping as
-- tools/make_skies.py (0.48: Lf/Rt swapped, Up mirrored).
-- AimRngClient's ApplyLightProfile puts the biome's sky up as you enter its floor. A biome missing here gets a blank sky.
local function Faces(t: { [string]: string }): { [string]: string }
    local out = {}
    for k, v in pairs(t) do out[k] = "rbxassetid://" .. v end
    return out
end
local SKIES = {
    -- MOLTEN: a volcanic dusk -- a real cloud deck turned to ash lit furnace-orange from below, the eruption over the vista
    -- volcano, embers, a blood moon
    Fire = Faces({ Bk = "92484175207757", Dn = "126584547130476", Ft = "102079989854012", Lf = "120370291037760", Rt = "130640756285573", Up = "95470350341053" }),
    -- GLACIER: a clear polar morning, real cirrus / cumulus, a white sun with the 22-degree ice halo + sun dogs
    Ice = Faces({ Bk = "81764257811069", Dn = "123393904194472", Ft = "83154913499098", Lf = "126035820510353", Rt = "103017301771154", Up = "129213999231093" }),
    -- VOID: deep space -- real stars + milky way, an emission nebula with dust lanes, a black hole + accretion disc
    Void = Faces({ Bk = "73147098923343", Dn = "140665992408910", Ft = "117673433660416", Lf = "109351875335290", Rt = "102519451451391", Up = "115647315094925" }),
    -- CYBER: a real overcast deck turned to neon smog lit magenta + cyan from the streets, searchlights, a veiled moon
    -- (2026-10-24: Bk + Up re-rendered with hdri_sky.blur_wrap -- the hard vertical seam straight behind +Z is gone)
    Cyber = Faces({ Bk = "129091859807692", Dn = "96725598025043", Ft = "79245944043409", Lf = "86548340761324", Rt = "80578340992663", Up = "133269785424451" }),
    -- STORMSPIRE: under a supercell -- a real heavy deck graded slate, lightning inside it, rain sheets, a far daybreak
    Storm = Faces({ Bk = "108244887262865", Dn = "134423544618449", Ft = "117395617907583", Lf = "124874741569683", Rt = "100875434554914", Up = "137236346393995" }),
    -- DREAMSCAPE: a pastel night -- real stars + milky way graded lavender, aurora curtains, a planetary ring
    Dream = Faces({ Bk = "78197046166423", Dn = "100180478328134", Ft = "74569636305836", Lf = "137449940079806", Rt = "117475697339924", Up = "73923255455821" }),
    -- NEON FLATS: a synthwave dusk -- real sunset clouds recoloured magenta / violet, the glow behind the hero sun, mesas
    Flats = Faces({ Bk = "137354638587759", Dn = "87685011143766", Ft = "101794492820307", Lf = "73829699348163", Rt = "85826460418133", Up = "78312072075326" }),
    -- THE WALLED CITY (hub + Bazaar): low real overcast lit from below by the streets (sodium + neon at the horizon),
    -- deep indigo overhead, a few stars, no sun / moon. Only shows where AimRngClient parents the sky for the hub.
    -- (2026-10-23, owner: "clearly is like a box": no seam behind +Z any more, and below the horizon the city goes on --
    -- street lights merging into a glow -- instead of a flat wall; needs ATMO.Hub Haze 0, Haze paints the lower half flat)
    Hub = Faces({ Bk = "73903663985014", Dn = "97727107681293", Ft = "113537100209492", Lf = "81087113069025", Rt = "72130343478025", Up = "129956202356113" }),
}
-- (0.87 WORLDS: each world's painted sky -- tools/make_skies.py, ids in the world module)
do
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for k, v in pairs(WB.Sky) do SKIES[k] = Faces(v) end end
end
-- (UPDATE 4 wrap-up: hideouts + duels used Roblox's stock skybox -- the classic cartoon clouds -- wherever their sky shows)
-- FOREST CABIN: a soft gold afternoon of real cumulus over the canopy (light profile HideoutForest, ClockTime 14.5)
SKIES.HideoutForest = Faces({ Bk = "93056347690091", Dn = "125693339726214", Ft = "83066600173445", Lf = "96783568097808", Rt = "125068234551527", Up = "125570435503210" })
-- DUEL ARENAS: a pink dusk over the city, no moon (light profile Pvp, ClockTime 16.8)
SKIES.Pvp = Faces({ Bk = "134199151597337", Dn = "83187539307222", Ft = "99004980780563", Lf = "87322217484775", Rt = "140589656605680", Up = "101713969603513" })
-- DEEP AQUARIUM: the Abyss world's underside of the sea (Snell's window overhead) -- made for exactly this
SKIES.HideoutAquarium = SKIES.Abyss
-- STARWHALE OBSERVATORY (UPDATE 6): deep space the whale swims through -- real stars + milky way on deep navy, a cobalt /
-- teal nebula with dust lanes, nebula below the horizon too (light profile HideoutStarwhale, ClockTime 13, low Brightness)
SKIES.HideoutStarwhale = Faces({ Bk = "89212013603657", Dn = "75085012485433", Ft = "125995199140866", Lf = "118794734590055", Rt = "98476265318354", Up = "107501258404169" })
-- (the night hideouts -- Ember Forge, Starwhale, Crystal Hollow -- keep the stock night sky on purpose: real stars + moon;
-- a painted face goes black at a night clock)
return SKIES

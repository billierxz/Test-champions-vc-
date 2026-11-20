local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local getasset = getcustomasset or getsynasset
local copyToClipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)

-- ==========================================
-- CONFIGURACIÓN GLOBAL Y PALETA DE COLORES
-- ==========================================
local SAVE_FILE = "ChampionsRiseVoicelines_V8.json"
local VolumeData = {}
local CustomQuoteEdits = {}
local VoicelinesActivas = true
local VfxActivos = true
local SoloMisVoces = false

-- URLs de emblema estrella, raya de energía y audios GitHub
local STAR_EMBLEM_URL = "https://i.postimg.cc/brck1DN4/1000331975-Photoroom.png"
local ENERGY_BEAM_URL = "https://i.postimg.cc/Y2RQv9wp/1000331989-Photoroom.png"
local GITHUB_BASE     = "https://raw.githubusercontent.com/billierxz/Champions-rise-Vcs/main/"
local TARGET_HAIR     = "71292732643155"

-- Posición y tamaño finales de la raya
local BEAM_POS  = UDim2.new(0.5575, 0, 0.3350, 0)
local BEAM_SIZE = UDim2.new(1.5276, 0, 13.8182, 0)

-- Colores principales
local COLOR_CELESTE = Color3.fromRGB(142, 228, 255)
local COLOR_ROJO    = Color3.fromRGB(240, 36, 56)
local COLOR_VIOLETA = Color3.fromRGB(185, 125, 255)

-- Colores interiores estilo Force Shield
local SHIELD_DEEP_CYAN = Color3.fromRGB(12, 36, 62)
local SHIELD_MID_BLUE  = Color3.fromRGB(24, 68, 102)
local SHIELD_CRIMSON   = Color3.fromRGB(58, 14, 30)
local SHIELD_SEPARATOR = Color3.fromRGB(22, 56, 110)

local GLOBAL_PALETTE = {COLOR_CELESTE, COLOR_ROJO, COLOR_VIOLETA}

-- ==========================================
-- CARGADOR SEGURO DE IMÁGENES
-- ==========================================
local loadedImageCache = {}

local function isValidImageBody(body)
    if type(body) ~= "string" or #body < 500 then return false end
    local head = body:sub(1, 32):lower()
    if head:find("<html") or head:find("<!doctype") then return false end
    return true
end

local function applySafeWebImage(imageLabel, url, fileName)
    if not imageLabel then return end
    if loadedImageCache[fileName] then
        pcall(function() imageLabel.Image = loadedImageCache[fileName] end)
        return
    end

    task.spawn(function()
        local assetPath = nil
        pcall(function()
            if isfile and isfile(fileName) and readfile and getasset then
                local existingData = readfile(fileName)
                if isValidImageBody(existingData) then
                    assetPath = getasset(fileName)
                end
            end
        end)

        if not assetPath then
            local success = false
            local reqHeaders = {["User-Agent"] = "Mozilla/5.0"}
            local reqFns = {
                http_request,
                syn and syn.request,
                request
            }
            for _, fn in ipairs(reqFns) do
                if not success and fn and writefile and getasset then
                    pcall(function()
                        local res = fn({Url = url, Method = "GET", Headers = reqHeaders})
                        if res and isValidImageBody(res.Body) then
                            writefile(fileName, res.Body)
                            assetPath = getasset(fileName)
                            success = true
                        end
                    end)
                end
            end
            if not success then
                pcall(function()
                    if writefile and getasset then
                        local body = game:HttpGet(url)
                        if isValidImageBody(body) then
                            writefile(fileName, body)
                            assetPath = getasset(fileName)
                            success = true
                        end
                    end
                end)
            end
        end

        if assetPath then
            loadedImageCache[fileName] = assetPath
            pcall(function()
                if imageLabel and imageLabel.Parent then
                    imageLabel.Image = assetPath
                end
            end)
        end
    end)
end

-- ==========================================
-- COLOR PERSONALIZADO DEL INTERIOR DEL GLOBO
-- ==========================================
local CustomGlobeHex = nil
local CustomGlobeName = "Color Personalizado"
local CustomGlobeColor = nil
local SavedGlobeColors = {}

local function parseHexColor(hexStr)
    if type(hexStr) ~= "string" then return nil, nil end
    local cleaned = hexStr:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^#", "")
    if #cleaned == 3 then
        cleaned = cleaned:sub(1, 1):rep(2) .. cleaned:sub(2, 2):rep(2) .. cleaned:sub(3, 3):rep(2)
    end
    if #cleaned ~= 6 or not cleaned:match("^[0-9a-fA-F]+$") then
        return nil, nil
    end
    local r = tonumber(cleaned:sub(1, 2), 16)
    local g = tonumber(cleaned:sub(3, 4), 16)
    local b = tonumber(cleaned:sub(5, 6), 16)
    return Color3.fromRGB(r, g, b), "#" .. cleaned:upper()
end

local function getDefaultInnerColorSequence()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, SHIELD_DEEP_CYAN),
        ColorSequenceKeypoint.new(0.35, SHIELD_MID_BLUE),
        ColorSequenceKeypoint.new(0.68, SHIELD_CRIMSON),
        ColorSequenceKeypoint.new(1.00, SHIELD_DEEP_CYAN)
    })
end

local function applyInnerColorToLayer(innerLayer)
    if not innerLayer then return end
    local innerGrad = innerLayer:FindFirstChild("InnerGrad")
    if CustomGlobeColor then
        if innerGrad then innerGrad.Enabled = false end
        for _, child in ipairs(innerLayer:GetChildren()) do
            if child:IsA("Frame") then
                child.BackgroundColor3 = CustomGlobeColor
            end
        end
    else
        if innerGrad then
            innerGrad.Color = getDefaultInnerColorSequence()
            innerGrad.Enabled = true
        end
        for _, child in ipairs(innerLayer:GetChildren()) do
            if child:IsA("Frame") then
                child.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end
end

-- ==========================================
-- DETECCIÓN DE SPIDER-MAN DEFAULT Y MORPH QUEEN OF THE DEAD
-- ==========================================
local function getSpideyDefaultModel()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local chars = assets and assets:FindFirstChild("Characters")
    local spidey = chars and chars:FindFirstChild("Spider-Man")
    return spidey and spidey:FindFirstChild("Default")
end

local function isSpiderManDefault(char)
    if not char then return false end
    local defaultModel = getSpideyDefaultModel()

    if defaultModel then
        for _, obj in ipairs(player:GetDescendants()) do
            if obj:IsA("ObjectValue") and obj.Value == defaultModel then return true end
        end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("ObjectValue") and obj.Value == defaultModel then return true end
        end
    end

    local charAttr = char:GetAttribute("Character") or char:GetAttribute("CharacterName") or char:GetAttribute("Hero")
    local skinAttr = char:GetAttribute("Skin") or char:GetAttribute("Form") or char:GetAttribute("Variant")
    if type(charAttr) == "string" and charAttr:lower():find("spider") then
        if skinAttr == nil or tostring(skinAttr):lower() == "default" or tostring(skinAttr) == "" then
            return true
        end
    end

    if defaultModel then
        local refShirt = defaultModel:FindFirstChildOfClass("Shirt")
        local refPants = defaultModel:FindFirstChildOfClass("Pants")
        local charShirt = char:FindFirstChildOfClass("Shirt")
        local charPants = char:FindFirstChildOfClass("Pants")

        if refShirt and refPants and charShirt and charPants then
            if refShirt.ShirtTemplate ~= "" and charShirt.ShirtTemplate == refShirt.ShirtTemplate
                and refPants.PantsTemplate ~= "" and charPants.PantsTemplate == refPants.PantsTemplate then
                return true
            end
        end

        local refMeshes = {}
        local countRef = 0
        for _, d in ipairs(defaultModel:GetDescendants()) do
            if (d:IsA("SpecialMesh") or d:IsA("MeshPart")) and d.MeshId ~= "" then
                refMeshes[d.MeshId] = true
                countRef = countRef + 1
            end
        end

        if countRef > 0 then
            local matches = 0
            for _, d in ipairs(char:GetDescendants()) do
                if (d:IsA("SpecialMesh") or d:IsA("MeshPart")) and refMeshes[d.MeshId] then
                    matches = matches + 1
                end
            end
            if matches >= math.max(1, math.floor(countRef * 0.6)) then
                return true
            end
        end
    end

    return false
end

local function isQueenOfTheDeadMorph(char)
    if not char then return false end
    local ok, result = pcall(function()
        local targetPlr = Players:GetPlayerFromCharacter(char) or player

        -- 1. Revisar atributos activos del personaje
        for _, attrName in ipairs({"Skin", "Morph", "SkinName", "MorphName", "Variant", "Form", "CharacterName", "Character"}) do
            local val = char:GetAttribute(attrName)
            if type(val) == "string" and val ~= "" then
                local low = val:lower()
                if low:find("queen of the dead", 1, true) then
                    return true
                elseif (attrName == "Skin" or attrName == "Morph" or attrName == "SkinName" or attrName == "MorphName") and low ~= "wanda" and low ~= "wandamaximoff" then
                    return false
                end
            end
        end

        -- 2. Revisar referencia exacta en Data.UnlockedSkins.WandaMaximoff["Wanda Maximoff: Queen of the Dead"]
        local dataFolder = targetPlr and targetPlr:FindFirstChild("Data")
        local unlockedSkins = dataFolder and dataFolder:FindFirstChild("UnlockedSkins")
        local wandaFolder = unlockedSkins and unlockedSkins:FindFirstChild("WandaMaximoff")
        local queenSkinObj = wandaFolder and wandaFolder:FindFirstChild("Wanda Maximoff: Queen of the Dead")

        for _, folderName in ipairs({"EquippedSkins", "SelectedSkins", "CurrentSkins", "ActiveSkins"}) do
            local eqFolder = dataFolder and dataFolder:FindFirstChild(folderName)
            local eqWanda = eqFolder and eqFolder:FindFirstChild("WandaMaximoff")
            if eqWanda then
                if eqWanda:IsA("StringValue") then
                    return eqWanda.Value:lower():find("queen of the dead", 1, true) ~= nil
                elseif eqWanda:IsA("ObjectValue") and eqWanda.Value then
                    return eqWanda.Value == queenSkinObj or eqWanda.Value.Name:lower():find("queen of the dead", 1, true) ~= nil
                end
            end
        end

        for _, container in ipairs({char, targetPlr}) do
            if container then
                for _, desc in ipairs(container:GetDescendants()) do
                    if desc:IsA("ObjectValue") and desc.Value then
                        if (queenSkinObj and desc.Value == queenSkinObj) or desc.Value.Name:lower():find("queen of the dead", 1, true) then
                            return true
                        end
                    elseif desc:IsA("StringValue") then
                        local nLow = desc.Name:lower()
                        if nLow:find("skin") or nLow:find("morph") then
                            if desc.Value:lower():find("queen of the dead", 1, true) then
                                return true
                            elseif desc.Value ~= "" and not desc.Value:lower():find("wanda") then
                                return false
                            end
                        end
                    elseif desc.Name:lower():find("queen of the dead", 1, true) and desc:IsDescendantOf(char) then
                        return true
                    end
                end
            end
        end

        if queenSkinObj then
            if queenSkinObj:GetAttribute("Equipped") == true or (queenSkinObj:IsA("BoolValue") and queenSkinObj.Value == true) then
                return true
            end
        end

        return false
    end)
    return ok and result == true
end

-- ==========================================
-- DATOS DE VOICELINES CON TODOS TUS AJUSTES FIJOS
-- ==========================================
local STOP_SONG_ANIM = "105976246289294"

local SONG_DATA = {
    key = "Cancion", type = "url",
    src = "https://github.com/billierxz/Champions-rise-Vcs/blob/c75b87b155db10d3579ce95d906baa5df51deb53/mix_Bad_Bunny___EoO__Video_Lyrics__1080P_HD_.mp3",
    defVol = 5, cd = 1.5, hero = "Spider-Man", order = 6,
    isSong = true,
    fade = true,
    stopAnimId = STOP_SONG_ANIM,
    vfxType = "random",
    quote = "🎧"
}

local DEATH_VOICELINE = {
    key = "Death (Im Okay)", type = "url",
    src = "https://github.com/billierxz/Champions-rise-Vcs/blob/94052a84f7ee0889465961679bec76cddaa32569/separated_vocal_im_ek_fix__FA95189_.mp3",
    defVol = 6.5, cd = 1, hero = "Spider-Man", order = 7,
    vfxType = "death",
    isSadDeath = true,
    quote = "im okay im okay I'm okay.."
}

local TRACKED = {
    ["126744091497158"] = {
        key = "Spider Trap", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/7206d4f1a6c0fab3aa364820af50e62123e199ee/separated_vocal_laugh__505D0B6_.mp3",
        nextSrc = "https://github.com/billierxz/Champions-rise-Vcs/blob/4cb1a0ed1efa85097ace32922dff72020cf56191/separated_vocal_im_in_control_bubby__350370B_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 2,
        vfxType = "response",
        quote = "Hahah",
        nextQuote = "Im in control bubby"
    },
    ["114696600161120"] = {
        key = "Spider Trap Mass", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/8d641f30a8fb6bfe825c4dc001eb3344631a2cb4/separated_vocal_you_can_t_trick_me_anymore__6E3008F_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 3,
        vfxType = "damage",
        quote = "You can't trick me anymore."
    },
    ["110771864835896"] = {
        key = "Spider Stun Bring", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/441db525530eadbf74fea5b445d3084de39e6daa/separated_vocal_you_ready____11D2A6A_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 4,
        vfxType = "response",
        quote = "You ready?"
    },
    ["99079784262381"] = {
        key = "Spider Kick", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/d248b52cd145be82101c4553ca55b5d551701f4f/separated_vocal_im_both__9ED1F80_.mp3",
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 5,
        vfxType = "damage",
        quote = "Im both.",
        afterDelayTime = 3,
        afterDelayQuote = ""
    },
    ["117318923209438"] = SONG_DATA,
    ["81821563682239"]  = SONG_DATA
}

local SOUND_TRACKED = {
    ["71182782447096"] = {
        key = "Spider Sense", type = "url",
        src = "https://github.com/billierxz/Champions-rise-Vcs/blob/609257568b3adafa6e7265f4f634e64fef40c4a4/mix_sense__CE9A314_.mp3",
        primaryVolFactor = 1.25,
        extraUrl = "https://github.com/billierxz/Champions-rise-Vcs/blob/9a1fc7e4e3610d083c28806846c8687f06bfb329/separated_vocal_give_a_sec__74333BB_.mp3",
        extraVolFactor = 0.78,
        defVol = 6, cd = 1.5, hero = "Spider-Man", order = 1,
        replaceSoundId = "71182782447096",
        vfxType = "response",
        quote = "Alright, just give a sec",
        afterDelayTime = 0.9,
        afterDelayQuote = "..."
    }
}

-- Cortes de audio de CARRIE
local PUSH_CUTS = {
    [110895682591322] = {file="separated_vocal_1155241.mp3", start=0.00, endT=6.00, fadeIn=0.15, fadeOut=0.35, useFadeIn=true, useFadeOut=true},
    [112275408128882] = {file="mix_scrim__D9EB52E_.mp3", start=0.00, endT=1.80, fadeIn=0.20, fadeOut=0.35, useFadeIn=false, useFadeOut=true},
    [121248577169811] = {file="mix_scrim__D9EB52E_.mp3", start=1.80, endT=6.00, fadeIn=0.20, fadeOut=0.25, useFadeIn=true, useFadeOut=false},
}

-- Voicelines por personaje
local EXTRA_ANIM_DATA = {
    -- JEAN GREY
    {
        id=87915013236692, name="are mine", char="JEAN GREY", mode="cycle", group="main",
        files={"separated_vocal_are_mine.mp3"}, displayNames={"are mine"},
        quotes={{t1="are mine", start=0, split=2, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=117655431108492, name="jin grei", char="JEAN GREY", mode="cycle", group="main",
        files={"separated_vocal_jean_grey__8A70B4A__denoise.mp3"}, displayNames={"jin grei"},
        quotes={{t1="I'm jean grey", start=0, split=0, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=130101164040743, name="you're a mess", char="JEAN GREY", mode="cycle", group="main",
        files={"separated_vocal_mess__401B7EA___1__denoise.mp3", "separated_vocal_what_i_want__4E3FB12__denoise.mp3", "separated_vocal_i_can_be_anything__E70DE10__denoise.mp3"},
        displayNames={"you're a mess", "and you know what I want", "i can be any what I want"},
        quotes={
            {t1="you're a mess", start=0, split=0, t2=""},
            {t1="and you know what I want", start=0, split=0, t2=""},
            {t1="i can be any what I want", start=0, split=0, t2=""}
        },
        defaultVols={3.0, 3.0, 3.0}, nocancel={true, true, true}
    },
    {
        id=75615528562757, name="jean random", char="JEAN GREY", mode="cycle", group="main",
        files={"separated_vocal_jean_grey__8A70B4A__denoise.mp3", "separated_vocal_mess__401B7EA___1__denoise.mp3"},
        displayNames={"jin grei", "mess"},
        quotes={
            {t1="I'm Jean grey", start=0, split=0, t2=""},
            {t1="you're a mess", start=0, split=0, t2=""}
        },
        defaultVols={3.0, 3.0}, nocancel={true, true}
    },

    -- WANDA
    {
        id=86306673049428, name="rocas normal", char="WANDA", mode="cycle", group="main",
        files={"separated_vocal_rocas_normal_eande__6C6F0C3_.mp3", "separated_vocal_rocas_2_normal__8A84B51_.mp3"},
        displayNames={"rocas normal 1", "rocas normal 2"},
        quotes={
            {t1="You took", start=0, split=2, t2="everything from me"},
            {t1="you will", start=0, split=0, t2=""}
        },
        defaultVols={3.0, 3.0}, nocancel={true, false}
    },
    {
        id=140048440092631, name="beam normal", char="WANDA", mode="cycle", group="main",
        files={"mix_Nuevo_proyecto_60__B355EDA_.mp3", "mix_beam_normal__9D286C7_.mp3"},
        displayNames={"beam normal 1", "beam normal 2"},
        quotes={
            {t1="you'll never", start=0, split=0.8, t2="see me again"},
            {t1="the storm is upon us!", start=0, split=0, t2=""}
        },
        defaultVols={3.0, 3.0}, nocancel={true, true}
    },
    {
        id=111027451423932, name="bolt", char="WANDA", mode="cycle", group="main",
        files={"separated_vocal_bolt__53F7CEB_.mp3", "separated_vocal_botl2__9870C35_.mp3"},
        displayNames={"bolt 1", "bolt 2"},
        quotes={
            {t1="Mo", start=0, split=0.1, t2="More..?"},
            {t1="O", start=0, split=0.1, t2="OMG-"}
        },
        defaultVols={3.0, 3.0}, nocancel={true, true}
    },
    {
        id=124726258588179, name="escudo", char="WANDA", mode="cycle", group="main_nocancel",
        files={"separated_vocal_shield__2B504F4_.mp3"}, displayNames={"escudo"},
        quotes={{t1="I can't control their fear", start=0.2, split=2, t2="only my own"}},
        defaultVols={3.0}
    },
    {
        id=120312339420058, name="beam normal extra", char="WANDA", mode="cycle", group="main",
        files={"mix_Nuevo_proyecto_60__B355EDA_.mp3", "separated_vocal_beam_mp3.mp3"},
        displayNames={"beam extra 1", "beam extra 2"},
        quotes={
            {t1="you'll never", start=0, split=0.8, t2="see me again"},
            {t1="UAH!", start=0, split=0, t2=""}
        },
        defaultVols={3.0, 3.0}, nocancel={true, true}
    },

    -- WANDA ZOMBIE
    {
        id=127024022312117, name="Wanda both shield rocks", char="WANDA ZOMBIE", mode="cycle", group="main",
        files={
            "separated_vocal_zombie_rokas__AF4239C_.mp3",
            "separated_vocal_rocas_wanda_zombie__818C67C_.mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/62e366c5a7bf6c49691363005c3e9e21e31cacee/i%20warn%20you..%20zombie.mp3"
        },
        displayNames={"rocas zombie 1", "rocas zombie 2", "I warned you.."},
        quotes={
            {t1="to hold..", start=0, split=0.7, t2="all this power"},
            {t1="and so the world..", start=0, split=0.8, t2="begins again"},
            {t1="I warned you..", start=0, split=0, t2=""}
        },
        defaultVols={3.0, 3.0, 3.0},
        nocancel={true, true, true},
        requiresQueenMorph={false, false, true}
    },
    {
        id=139183919008648, name="rocas de escudo", char="WANDA ZOMBIE", mode="cycle", group="main_nocancel",
        files={
            "separated_vocal_rocas_shield_pain__A60A8CC_.mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/f7bf457f9528750045b7bcd537cf74769e5dd207/separated_vocal_i_warn_ye__AB25530_.mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/27dcc7aa3f1e956882425d1f97d0e3a806827a40/mix_and_i_warn_you__91C37F1_.mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/0e04d16ef600bb7643f72259e1a7a507baaa5796/denoise_Nuevo_proyecto__366B0AC_.mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/1aba92edff6ae97f4508c39ac4a8d9fdf806a973/mix_i_just_did__CECEBE1_.mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/4906c2b0e8e0e6c6b61e6684c48242bea97f670c/waiting%20for%20me...mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/f2b211c9ab62d51511c1303a52511d27c9e3e8e9/you%20have%20exhausted%20my%20patience.mp3",
            "https://github.com/billierxz/Champions-rise-Vcs/blob/07a6782049da5a334bb27d3154446a45341a1da2/get%20out%20of%20my%20way..mp3"
        },
        displayNames={
            "I've come to ease your pain",
            "I warned you.",
            "And I want you to leave",
            "They never know",
            "I just did.. It feel like that",
            "They've waiting for me..",
            "you have exhausted my patience",
            "Get out of my way."
        },
        quotes={
            {t1="I've come to ease", start=0, split=0.9, t2="your pain"},
            {t1="I warned you.", start=0, split=0, t2=""},
            {t1="And I want you", start=0, split=2, t2="to leave"},
            {t1="They never", start=0, split=0.4, t2="know", split2=0, t3="", audioDelay=0},
            {t1="I just did..", start=0, split=0.8, t2="do know how it felt?", split2=2, t3="it feel like that", audioDelay=0},
            {t1="They've waiting for me..", start=0, split=0, t2=""},
            {t1="you have exhausted my patience", start=0.4, split=0.8, t2="", split2=0, t3="", audioDelay=0},
            {t1="Get out", start=0, split=0, t2="of my way.", split2=0, t3="", audioDelay=0}
        },
        defaultVols={3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0},
        nocancel={true, true, true, true, true, true, true, true},
        requiresQueenMorph={false, false, false, false, false, true, false, false},
        excludeQueenMorph={false, true, false, false, false, false, false, false}
    },
    {
        id=98443117457067, name="beam zombie", char="WANDA ZOMBIE", mode="cycle", group="main",
        files={"120312339420058", "separated_vocal_beam_mp3.mp3"},
        displayNames={"beam zombie normal", "beam zombie github"},
        quotes={
            {t1="aah", start=0, split=0, t2=""},
            {t1="UAH!", start=0, split=0, t2=""}
        },
        defaultVols={3.0, 3.0}, nocancel={true, true}
    },
    {
        id=99999999999999, name="do I look dead?", char="WANDA ZOMBIE", mode="cycle", group="main_nocancel",
        files={"separated_vocal_Nuevo_proyecto_225__C7D937F_.mp3"}, displayNames={"do I look dead?"},
        quotes={{t1="Do I look dead to you?", start=0, split=0, t2=""}},
        defaultVols={5.0}
    },

    -- CARRIE
    {
        id=81231009722943, name="plug / bitch", char="CARRIE", mode="chain", group="main",
        files={"separated_vocal_ged_plug_it_up__09FC71D_.mp3","separated_vocal_plug_it_eps__898DA09_.mp3","separated_vocal_bitch__CB1A70F_.mp3"},
        displayNames={"you need to repent","plug it up","bitch"},
        quotes={
            {t1="you need to repent...", start=0, split=2, t2="get right with god."},
            {t1="plug it up", start=0, split=0, t2=""},
            {t1="bitch", start=0, split=0, t2=""}
        },
        defaultVols={3.0,3.0,3.0}
    },
    {
        id=86662730198588, name="sombra carrie", char="CARRIE", mode="cycle", group="main",
        files={"separated_vocal_wheel__883EC24_.mp3"}, displayNames={"wheel"},
        quotes={{t1="let me take the wheel okay?", start=0.4, split=0, t2=""}},
        defaultVols={3.0}
    },
    {
        id=85169791625553, name="explosion", char="CARRIE", mode="cycle", group="main",
        files={"mix_sharrep__96E14A1_.mp3","separated_vocal_whyyyy__90CB052_.mp3","separated_vocal_emalainn__DA1BE8E_.mp3"},
        displayNames={"shut up","whyyy","Emaline!"},
        quotes={
            {t1="shut up", start=0, split=0, t2=""},
            {t1="WHYYY?!", start=0, split=0, t2=""},
            {t1="EMALINE!!", start=0.4, split=0, t2=""}
        },
        defaultVols={3.0,3.0,3.0}
    },
    {
        id=110895682591322, name="push 1", char="CARRIE", mode="cut", group="push1",
        files={"separated_vocal_1155241.mp3"}, displayNames={"1155241 [0.00-6.00]"},
        quotes={{t1="..", start=0, split=0.6, t2="Cause things are gonna change"}},
        defaultVols={3.0}
    },
    {
        id=112275408128882, name="push 2 - scrim p1", char="CARRIE", mode="cut", group="scrim",
        files={"mix_scrim__D9EB52E_.mp3"}, displayNames={"scrim [0.00-1.80]"},
        quotes={{t1="AHH!", start=0.4, split=0, t2=""}},
        defaultVols={3.0}
    },
    {
        id=121248577169811, name="last push - scrim p2", char="CARRIE", mode="cut", group="scrim",
        files={"mix_scrim__D9EB52E_.mp3"}, displayNames={"scrim [1.80-6.00]"},
        quotes={{t1="!!!!", start=0, split=0, t2=""}},
        defaultVols={3.0}
    },

    -- ELEVEN
    {
        id=131937626189701, name="reset it", char="ELEVEN", mode="cycle", group="main",
        files={"106256954091412"}, displayNames={"reset it"},
        quotes={{t1="reset it", start=0, split=0, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=100672235784007, name="Yu lai", char="ELEVEN", mode="cycle", group="main",
        files={"102610277656628"}, displayNames={"Yu lai"},
        quotes={{t1="YOU....", start=0, split=0.5, t2="LIE!"}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=86760345654308, name="I can fight", char="ELEVEN", mode="cycle", group="main",
        files={"139147349228730"}, displayNames={"I can fight"},
        quotes={{t1="I can fight", start=0, split=0, t2=""}},
        defaultVols={3.0}
    },

    -- ATOM
    {
        id=72208693897518, name="Shield Voiceline", char="ATOM", mode="cycle", group="main_nocancel",
        files={"99877479013651"}, displayNames={"Shield"},
        quotes={{t1="You're coming with me", start=0.4, split=0, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=135605539099677, name="Spear Voiceline", char="ATOM", mode="cycle", group="main",
        files={"136524271516162"}, displayNames={"Spear"},
        quotes={{t1="Okay-", start=0, split=0, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=124039184964656, name="you need help", char="ATOM", mode="cycle", group="main",
        files={"119031874604160"}, displayNames={"you need help"},
        quotes={{t1="you need help..", start=0, split=0, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=119607378859508, name="fight", char="ATOM", mode="cycle", group="main",
        files={"73224922579522"}, displayNames={"fight"},
        quotes={{t1="not a fight.", start=0, split=0, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
    {
        id=100845373527241, name="jerk", char="ATOM", mode="cycle", group="main",
        files={"86265863416856"}, displayNames={"jerk"},
        quotes={{t1="jerk", start=0, split=0, t2=""}},
        defaultVols={3.0}, nocancel={true}
    },
}

local EXTRA_ANIM_BY_ID = {}
for _, d in ipairs(EXTRA_ANIM_DATA) do
    EXTRA_ANIM_BY_ID[d.id] = d
end

-- Cargar configuración guardada
if isfile and isfile(SAVE_FILE) then
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(SAVE_FILE))
        if type(decoded) == "table" then
            VolumeData = decoded
            if VolumeData._vfxEnabled ~= nil then VfxActivos = VolumeData._vfxEnabled end
            if VolumeData._onlyMe ~= nil then SoloMisVoces = VolumeData._onlyMe end
            if type(VolumeData._customQuotes) == "table" then
                CustomQuoteEdits = VolumeData._customQuotes
            end
            if type(VolumeData._globeInnerHex) == "string" then
                local col, norm = parseHexColor(VolumeData._globeInnerHex)
                if col then
                    CustomGlobeColor = col
                    CustomGlobeHex = norm
                end
            end
            if type(VolumeData._globeInnerName) == "string" and VolumeData._globeInnerName ~= "" then
                CustomGlobeName = VolumeData._globeInnerName
            end
            if type(VolumeData._savedGlobeColors) == "table" then
                SavedGlobeColors = VolumeData._savedGlobeColors
            end
        end
    end)
end

local function saveConfig()
    VolumeData._vfxEnabled = VfxActivos
    VolumeData._onlyMe = SoloMisVoces
    VolumeData._customQuotes = CustomQuoteEdits
    VolumeData._globeInnerHex = CustomGlobeHex
    VolumeData._globeInnerName = CustomGlobeName
    VolumeData._savedGlobeColors = SavedGlobeColors
    if writefile then
        pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(VolumeData)) end)
    end
end

local function getClipVolume(volKey, defaultVol)
    local v = VolumeData[volKey]
    if type(v) == "number" and v > 0 then
        return v
    end
    return defaultVol or 3.0
end

local function getEffectiveQuoteSpec(animData, clipIdx)
    local baseQ = (animData.quotes and animData.quotes[clipIdx]) or {
        t1 = animData.displayNames[clipIdx] or animData.name,
        start = 0,
        split = 0,
        t2 = "",
        split2 = 0,
        t3 = "",
        audioDelay = 0
    }
    local editKey = tostring(animData.id) .. "_" .. tostring(clipIdx)
    local saved = CustomQuoteEdits[editKey]
    if type(saved) == "table" then
        return {
            t1 = saved.t1 ~= nil and tostring(saved.t1) or (baseQ.t1 or ""),
            start = tonumber(saved.start) or tonumber(baseQ.start) or 0,
            split = tonumber(saved.split) or tonumber(baseQ.split) or 0,
            t2 = saved.t2 ~= nil and tostring(saved.t2) or (baseQ.t2 or ""),
            split2 = tonumber(saved.split2) or tonumber(baseQ.split2) or 0,
            t3 = saved.t3 ~= nil and tostring(saved.t3) or (baseQ.t3 or ""),
            audioDelay = tonumber(saved.audioDelay) or tonumber(baseQ.audioDelay) or 0
        }
    end
    return {
        t1 = baseQ.t1 or "",
        start = tonumber(baseQ.start) or 0,
        split = tonumber(baseQ.split) or 0,
        t2 = baseQ.t2 or "",
        split2 = tonumber(baseQ.split2) or 0,
        t3 = baseQ.t3 or "",
        audioDelay = tonumber(baseQ.audioDelay) or 0
    }
end

-- ==========================================
-- SISTEMA DE NUBE FORCE-SHIELD + ESTRELLA Y RAYA CALIBRADA
-- ==========================================
local activeBillboards = {}
local activeCaptionLoops = {}
local charBillboards = setmetatable({}, {__mode = "k"})

local LOBE_SPECS = {
    {x = 0.31, y = 0.35, w = 0.23, h = 0.32, side = -1},
    {x = 0.45, y = 0.24, w = 0.28, h = 0.36, side = -1},
    {x = 0.62, y = 0.23, w = 0.30, h = 0.38, side = 1},
    {x = 0.79, y = 0.31, w = 0.26, h = 0.35, side = 1},
    {x = 0.83, y = 0.46, w = 0.24, h = 0.33, side = 1},
    {x = 0.69, y = 0.53, w = 0.30, h = 0.34, side = 1},
    {x = 0.49, y = 0.54, w = 0.29, h = 0.34, side = -1},
    {x = 0.34, y = 0.47, w = 0.24, h = 0.31, side = -1}
}

local DRIP_SPECS = {
    {x = 0.42, y = 0.625, w = 0.020, baseH = 0.072, dropColor = COLOR_ROJO,    side = -1},
    {x = 0.50, y = 0.645, w = 0.024, baseH = 0.112, dropColor = COLOR_VIOLETA, side = -1},
    {x = 0.58, y = 0.650, w = 0.026, baseH = 0.132, dropColor = COLOR_ROJO,    side = 1},
    {x = 0.66, y = 0.642, w = 0.022, baseH = 0.105, dropColor = COLOR_CELESTE, side = 1},
    {x = 0.74, y = 0.622, w = 0.019, baseH = 0.068, dropColor = COLOR_ROJO,    side = 1}
}

local function resetBubbleGeometry(cloudRoot)
    if not cloudRoot then return end
    local shieldGroup = cloudRoot:FindFirstChild("ShieldGroup")
    if shieldGroup then
        local borderLayer = shieldGroup:FindFirstChild("BorderLayer")
        local separatorLayer = shieldGroup:FindFirstChild("SeparatorLayer")
        local innerLayer = shieldGroup:FindFirstChild("InnerLayer")

        for i, sp in ipairs(LOBE_SPECS) do
            local outerLobe = borderLayer and borderLayer:FindFirstChild("OuterLobe_" .. i)
            local sepLobe = separatorLayer and separatorLayer:FindFirstChild("SepLobe_" .. i)
            local innerLobe = innerLayer and innerLayer:FindFirstChild("InnerLobe_" .. i)
            if outerLobe then outerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0) end
            if sepLobe then sepLobe.Position = UDim2.new(sp.x, 0, sp.y, 0) end
            if innerLobe then innerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0) end
        end

        for i, d in ipairs(DRIP_SPECS) do
            local collarOut = borderLayer and borderLayer:FindFirstChild("DripCollarOut_" .. i)
            local taperOut = borderLayer and borderLayer:FindFirstChild("DripTaperOut_" .. i)
            local neckOut = borderLayer and borderLayer:FindFirstChild("DripNeckOut_" .. i)
            local bulbOut = borderLayer and borderLayer:FindFirstChild("DripBulbOut_" .. i)
            if collarOut then collarOut.Position = UDim2.new(d.x, 0, d.y, 0) end
            if taperOut then taperOut.Position = UDim2.new(d.x, 0, d.y, 0) end
            if neckOut then neckOut.Position = UDim2.new(d.x, 0, d.y, 0) end
            if bulbOut then bulbOut.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0) end

            local collarSep = separatorLayer and separatorLayer:FindFirstChild("DripCollarSep_" .. i)
            local taperSep = separatorLayer and separatorLayer:FindFirstChild("DripTaperSep_" .. i)
            local neckSep = separatorLayer and separatorLayer:FindFirstChild("DripNeckSep_" .. i)
            local bulbSep = separatorLayer and separatorLayer:FindFirstChild("DripBulbSep_" .. i)
            if collarSep then collarSep.Position = UDim2.new(d.x, 0, d.y, 0) end
            if taperSep then taperSep.Position = UDim2.new(d.x, 0, d.y, 0) end
            if neckSep then neckSep.Position = UDim2.new(d.x, 0, d.y, 0) end
            if bulbSep then bulbSep.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0) end

            local collarIn = innerLayer and innerLayer:FindFirstChild("DripCollarIn_" .. i)
            local taperIn = innerLayer and innerLayer:FindFirstChild("DripTaperIn_" .. i)
            local neckIn = innerLayer and innerLayer:FindFirstChild("DripNeckIn_" .. i)
            local bulbIn = innerLayer and innerLayer:FindFirstChild("DripBulbIn_" .. i)
            if collarIn then collarIn.Position = UDim2.new(d.x, 0, d.y, 0) end
            if taperIn then taperIn.Position = UDim2.new(d.x, 0, d.y, 0) end
            if neckIn then neckIn.Position = UDim2.new(d.x, 0, d.y, 0) end
            if bulbIn then bulbIn.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0) end
        end

        local centerCore = innerLayer and innerLayer:FindFirstChild("CenterCore")
        if centerCore then
            centerCore.Position = UDim2.new(0.57, 0, 0.39, 0)
            centerCore.Size = UDim2.new(0.50, 0, 0.32, 0)
            centerCore.BackgroundTransparency = 0
        end
    end

    local headerSig = cloudRoot:FindFirstChild("HeaderSignature")
    if headerSig then
        headerSig.Position = UDim2.new(0.54, 0, 0.145, 0)
        headerSig.Rotation = -3
        local underlineBeam = headerSig:FindFirstChild("UnderlineBeam")
        if underlineBeam then
            underlineBeam.Position = BEAM_POS
            underlineBeam.Size = BEAM_SIZE
            underlineBeam.ScaleType = Enum.ScaleType.Stretch
        end
    end

    local safeTextZone = cloudRoot:FindFirstChild("SafeTextZone")
    local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
    local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
    if quoteLbl then quoteLbl.Rotation = 0 end

    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
    if breachLayer then
        breachLayer.Visible = false
        for _, child in ipairs(breachLayer:GetChildren()) do
            if child.Name == "DynamicPlasmaDrop" then child:Destroy() end
        end
    end
end

local function refreshAllBillboardInnerColors()
    for _, bb in pairs(charBillboards) do
        if bb and bb.Parent then
            local cloudRoot = bb:FindFirstChild("CloudRoot")
            local shieldGroup = cloudRoot and cloudRoot:FindFirstChild("ShieldGroup")
            local innerLayer = shieldGroup and shieldGroup:FindFirstChild("InnerLayer")
            applyInnerColorToLayer(innerLayer)
        end
    end
end

local function setHeadParticles(char, enabled, isSad)
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not head then return end

    local att = head:FindFirstChild("OmegaVoiceVFXAttachment")
    if not enabled or not VfxActivos then
        if att then
            for _, p in ipairs(att:GetChildren()) do
                if p:IsA("ParticleEmitter") then p.Enabled = false end
            end
        end
        return
    end

    if not att then
        att = Instance.new("Attachment")
        att.Name = "OmegaVoiceVFXAttachment"
        att.Position = Vector3.new(0.45, 0.55, 0)
        att.Parent = head

        local sparks = Instance.new("ParticleEmitter")
        sparks.Name = "VoiceSparks"
        sparks.Texture = "rbxassetid://243098098"
        sparks.Rate = 16
        sparks.Lifetime = NumberRange.new(0.55, 1.0)
        sparks.Speed = NumberRange.new(1.1, 2.4)
        sparks.SpreadAngle = Vector2.new(360, 360)
        sparks.LightEmission = 1
        sparks.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.14),
            NumberSequenceKeypoint.new(0.6, 0.22),
            NumberSequenceKeypoint.new(1, 0)
        })
        sparks.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(0.8, 0.4),
            NumberSequenceKeypoint.new(1, 1)
        })
        sparks.Parent = att

        local glow = Instance.new("ParticleEmitter")
        glow.Name = "VoiceGlow"
        glow.Texture = "rbxassetid://243098098"
        glow.Rate = 6
        glow.Lifetime = NumberRange.new(0.65, 0.95)
        glow.Speed = NumberRange.new(0.2, 0.5)
        glow.SpreadAngle = Vector2.new(180, 180)
        glow.LightEmission = 0.85
        glow.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.65),
            NumberSequenceKeypoint.new(0.5, 1.1),
            NumberSequenceKeypoint.new(1, 1.35)
        })
        glow.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.70),
            NumberSequenceKeypoint.new(0.5, 0.82),
            NumberSequenceKeypoint.new(1, 1)
        })
        glow.Parent = att
    end

    local colorSeq = isSad and ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(115, 185, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 115, 205)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(80, 130, 200))
    }) or ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
        ColorSequenceKeypoint.new(1.0, COLOR_VIOLETA)
    })

    for _, p in ipairs(att:GetChildren()) do
        if p:IsA("ParticleEmitter") then
            p.Color = colorSeq
            p.Enabled = true
        end
    end
end

local function getBillboard(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not head then return nil end

    local existing = charBillboards[char]
    if existing and existing.Parent then
        existing.Adornee = head
        existing.MaxDistance = math.huge
        existing.ClipsDescendants = false
        local cloudRoot = existing:FindFirstChild("CloudRoot")
        local shieldGroup = cloudRoot and cloudRoot:FindFirstChild("ShieldGroup")
        local innerLayer = shieldGroup and shieldGroup:FindFirstChild("InnerLayer")
        applyInnerColorToLayer(innerLayer)
        return existing
    end

    local playerGui = player:WaitForChild("PlayerGui")
    local bbName = "ChampionsRiseForceShieldBB_" .. char.Name
    local oldGui = playerGui:FindFirstChild(bbName)
    if oldGui then oldGui:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = bbName
    bb.Adornee = head
    bb.Size = UDim2.new(4.15, 0, 2.75, 0)
    bb.StudsOffset = Vector3.new(2.55, 2.15, 0)
    bb.AlwaysOnTop = false
    bb.LightInfluence = 0
    bb.MaxDistance = math.huge
    bb.ClipsDescendants = false
    bb.ResetOnSpawn = false
    bb.Enabled = false
    bb.Parent = playerGui

    charBillboards[char] = bb

    local cloudRoot = Instance.new("Frame")
    cloudRoot.Name = "CloudRoot"
    cloudRoot.AnchorPoint = Vector2.new(0.5, 0.5)
    cloudRoot.Position = UDim2.new(0.5, 0, 0.5, 0)
    cloudRoot.Size = UDim2.new(1, 0, 1, 0)
    cloudRoot.Rotation = -3
    cloudRoot.BackgroundTransparency = 1
    cloudRoot.ClipsDescendants = false
    cloudRoot.Visible = false
    cloudRoot.Parent = bb

    -- 1. Trama de puntos
    local halftoneHolder = Instance.new("Frame")
    halftoneHolder.Name = "HalftoneHolder"
    halftoneHolder.Size = UDim2.new(1, 0, 1, 0)
    halftoneHolder.BackgroundTransparency = 1
    halftoneHolder.ZIndex = 1
    halftoneHolder.Parent = cloudRoot

    for row = 0, 14 do
        for col = 0, 19 do
            local stagger = (row % 2 == 0) and 0.020 or 0
            local px = 0.05 + (col / 19) * 0.90 + stagger
            local py = 0.01 + (row / 14) * 0.82

            local minNormDist = 999
            for _, sp in ipairs(LOBE_SPECS) do
                local dx = (px - sp.x) / (sp.w * 0.52)
                local dy = (py - sp.y) / (sp.h * 0.52)
                local d = math.sqrt(dx * dx + dy * dy)
                if d < minNormDist then minNormDist = d end
            end

            if minNormDist >= 1.02 and minNormDist <= 1.50 then
                local dot = Instance.new("Frame")
                dot.Name = "Dot"
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.Position = UDim2.new(px, 0, py, 0)
                local tEdge = 1 - ((minNormDist - 1.02) / 0.48)
                local scaleSz = math.clamp(0.007 + tEdge * 0.011, 0.007, 0.018)
                dot.Size = UDim2.new(scaleSz, 0, scaleSz * 1.55, 0)
                local dotColorIdx = ((row + col) % 3) + 1
                dot.BackgroundColor3 = GLOBAL_PALETTE[dotColorIdx]
                dot.BackgroundTransparency = math.clamp(0.80 - tEdge * 0.44, 0.28, 0.84)
                dot.BorderSizePixel = 0
                dot.ZIndex = 1
                dot.Parent = halftoneHolder
                Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            end
        end
    end

    -- 2. Force Shield Unificado
    local shieldGroup = Instance.new("CanvasGroup")
    shieldGroup.Name = "ShieldGroup"
    shieldGroup.Size = UDim2.new(1, 0, 1, 0)
    shieldGroup.BackgroundTransparency = 1
    shieldGroup.GroupTransparency = 0.24
    shieldGroup.ZIndex = 2
    shieldGroup.Parent = cloudRoot

    local borderLayer = Instance.new("CanvasGroup")
    borderLayer.Name = "BorderLayer"
    borderLayer.Size = UDim2.new(1, 0, 1, 0)
    borderLayer.BackgroundTransparency = 1
    borderLayer.ZIndex = 2
    borderLayer.Parent = shieldGroup

    local borderGrad = Instance.new("UIGradient", borderLayer)
    borderGrad.Name = "BorderGrad"
    borderGrad.Rotation = 18
    borderGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.28, COLOR_ROJO),
        ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
        ColorSequenceKeypoint.new(0.72, COLOR_ROJO),
        ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
    })

    local separatorLayer = Instance.new("CanvasGroup")
    separatorLayer.Name = "SeparatorLayer"
    separatorLayer.Size = UDim2.new(1, 0, 1, 0)
    separatorLayer.BackgroundTransparency = 1
    separatorLayer.ZIndex = 3
    separatorLayer.Parent = shieldGroup

    local innerLayer = Instance.new("CanvasGroup")
    innerLayer.Name = "InnerLayer"
    innerLayer.Size = UDim2.new(1, 0, 1, 0)
    innerLayer.BackgroundTransparency = 1
    innerLayer.ZIndex = 4
    innerLayer.Parent = shieldGroup

    local innerGrad = Instance.new("UIGradient", innerLayer)
    innerGrad.Name = "InnerGrad"
    innerGrad.Rotation = 30
    innerGrad.Color = getDefaultInnerColorSequence()

    for i, sp in ipairs(LOBE_SPECS) do
        local outerLobe = Instance.new("Frame")
        outerLobe.Name = "OuterLobe_" .. i
        outerLobe.AnchorPoint = Vector2.new(0.5, 0.5)
        outerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0)
        outerLobe.Size = UDim2.new(sp.w + 0.032, 0, sp.h + 0.048, 0)
        outerLobe.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        outerLobe.BorderSizePixel = 0
        outerLobe.Parent = borderLayer
        Instance.new("UICorner", outerLobe).CornerRadius = UDim.new(1, 0)

        local sepLobe = Instance.new("Frame")
        sepLobe.Name = "SepLobe_" .. i
        sepLobe.AnchorPoint = Vector2.new(0.5, 0.5)
        sepLobe.Position = UDim2.new(sp.x, 0, sp.y, 0)
        sepLobe.Size = UDim2.new(sp.w + 0.010, 0, sp.h + 0.015, 0)
        sepLobe.BackgroundColor3 = SHIELD_SEPARATOR
        sepLobe.BorderSizePixel = 0
        sepLobe.Parent = separatorLayer
        Instance.new("UICorner", sepLobe).CornerRadius = UDim.new(1, 0)

        local innerLobe = Instance.new("Frame")
        innerLobe.Name = "InnerLobe_" .. i
        innerLobe.AnchorPoint = Vector2.new(0.5, 0.5)
        innerLobe.Position = UDim2.new(sp.x, 0, sp.y, 0)
        innerLobe.Size = UDim2.new(sp.w, 0, sp.h, 0)
        innerLobe.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        innerLobe.BorderSizePixel = 0
        innerLobe.Parent = innerLayer
        Instance.new("UICorner", innerLobe).CornerRadius = UDim.new(1, 0)
    end

    local centerCore = Instance.new("Frame")
    centerCore.Name = "CenterCore"
    centerCore.AnchorPoint = Vector2.new(0.5, 0.5)
    centerCore.Position = UDim2.new(0.57, 0, 0.39, 0)
    centerCore.Size = UDim2.new(0.50, 0, 0.32, 0)
    centerCore.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    centerCore.BorderSizePixel = 0
    centerCore.Parent = innerLayer
    Instance.new("UICorner", centerCore).CornerRadius = UDim.new(0.45, 0)

    -- 3. Escurrido
    local dripEffectsLayer = Instance.new("Frame")
    dripEffectsLayer.Name = "DripEffectsLayer"
    dripEffectsLayer.Size = UDim2.new(1, 0, 1, 0)
    dripEffectsLayer.BackgroundTransparency = 1
    dripEffectsLayer.ZIndex = 5
    dripEffectsLayer.Parent = cloudRoot

    for i, d in ipairs(DRIP_SPECS) do
        local collarOut = Instance.new("Frame")
        collarOut.Name = "DripCollarOut_" .. i
        collarOut.AnchorPoint = Vector2.new(0.5, 0.5)
        collarOut.Position = UDim2.new(d.x, 0, d.y, 0)
        collarOut.Size = UDim2.new(d.w * 2.85 + 0.026, 0, 0.066, 0)
        collarOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        collarOut.BorderSizePixel = 0
        collarOut.Parent = borderLayer
        Instance.new("UICorner", collarOut).CornerRadius = UDim.new(1, 0)

        local taperOut = Instance.new("Frame")
        taperOut.Name = "DripTaperOut_" .. i
        taperOut.AnchorPoint = Vector2.new(0.5, 0)
        taperOut.Position = UDim2.new(d.x, 0, d.y, 0)
        taperOut.Size = UDim2.new(d.w * 1.80 + 0.026, 0, d.baseH * 0.45 + 0.024, 0)
        taperOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        taperOut.BorderSizePixel = 0
        taperOut.Parent = borderLayer
        Instance.new("UICorner", taperOut).CornerRadius = UDim.new(1, 0)

        local neckOut = Instance.new("Frame")
        neckOut.Name = "DripNeckOut_" .. i
        neckOut.AnchorPoint = Vector2.new(0.5, 0)
        neckOut.Position = UDim2.new(d.x, 0, d.y, 0)
        neckOut.Size = UDim2.new(d.w * 0.85 + 0.024, 0, d.baseH + 0.024, 0)
        neckOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        neckOut.BorderSizePixel = 0
        neckOut.Parent = borderLayer
        Instance.new("UICorner", neckOut).CornerRadius = UDim.new(1, 0)

        local bulbOut = Instance.new("Frame")
        bulbOut.Name = "DripBulbOut_" .. i
        bulbOut.AnchorPoint = Vector2.new(0.5, 0.5)
        bulbOut.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0)
        bulbOut.Size = UDim2.new(d.w * 1.65 + 0.026, 0, (d.w * 1.65) * 1.72 + 0.038, 0)
        bulbOut.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bulbOut.BorderSizePixel = 0
        bulbOut.Parent = borderLayer
        Instance.new("UICorner", bulbOut).CornerRadius = UDim.new(1, 0)

        local collarSep = Instance.new("Frame")
        collarSep.Name = "DripCollarSep_" .. i
        collarSep.AnchorPoint = Vector2.new(0.5, 0.5)
        collarSep.Position = UDim2.new(d.x, 0, d.y, 0)
        collarSep.Size = UDim2.new(d.w * 2.85 + 0.010, 0, 0.044, 0)
        collarSep.BackgroundColor3 = SHIELD_SEPARATOR
        collarSep.BorderSizePixel = 0
        collarSep.Parent = separatorLayer
        Instance.new("UICorner", collarSep).CornerRadius = UDim.new(1, 0)

        local taperSep = Instance.new("Frame")
        taperSep.Name = "DripTaperSep_" .. i
        taperSep.AnchorPoint = Vector2.new(0.5, 0)
        taperSep.Position = UDim2.new(d.x, 0, d.y, 0)
        taperSep.Size = UDim2.new(d.w * 1.80 + 0.010, 0, d.baseH * 0.45 + 0.010, 0)
        taperSep.BackgroundColor3 = SHIELD_SEPARATOR
        taperSep.BorderSizePixel = 0
        taperSep.Parent = separatorLayer
        Instance.new("UICorner", taperSep).CornerRadius = UDim.new(1, 0)

        local neckSep = Instance.new("Frame")
        neckSep.Name = "DripNeckSep_" .. i
        neckSep.AnchorPoint = Vector2.new(0.5, 0)
        neckSep.Position = UDim2.new(d.x, 0, d.y, 0)
        neckSep.Size = UDim2.new(d.w * 0.85 + 0.008, 0, d.baseH + 0.010, 0)
        neckSep.BackgroundColor3 = SHIELD_SEPARATOR
        neckSep.BorderSizePixel = 0
        neckSep.Parent = separatorLayer
        Instance.new("UICorner", neckSep).CornerRadius = UDim.new(1, 0)

        local bulbSep = Instance.new("Frame")
        bulbSep.Name = "DripBulbSep_" .. i
        bulbSep.AnchorPoint = Vector2.new(0.5, 0.5)
        bulbSep.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0)
        bulbSep.Size = UDim2.new(d.w * 1.65 + 0.010, 0, (d.w * 1.65) * 1.72 + 0.014, 0)
        bulbSep.BackgroundColor3 = SHIELD_SEPARATOR
        bulbSep.BorderSizePixel = 0
        bulbSep.Parent = separatorLayer
        Instance.new("UICorner", bulbSep).CornerRadius = UDim.new(1, 0)

        local collarIn = Instance.new("Frame")
        collarIn.Name = "DripCollarIn_" .. i
        collarIn.AnchorPoint = Vector2.new(0.5, 0.5)
        collarIn.Position = UDim2.new(d.x, 0, d.y, 0)
        collarIn.Size = UDim2.new(d.w * 2.85, 0, 0.032, 0)
        collarIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        collarIn.BorderSizePixel = 0
        collarIn.Parent = innerLayer
        Instance.new("UICorner", collarIn).CornerRadius = UDim.new(1, 0)

        local taperIn = Instance.new("Frame")
        taperIn.Name = "DripTaperIn_" .. i
        taperIn.AnchorPoint = Vector2.new(0.5, 0)
        taperIn.Position = UDim2.new(d.x, 0, d.y, 0)
        taperIn.Size = UDim2.new(d.w * 1.80, 0, d.baseH * 0.45, 0)
        taperIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        taperIn.BorderSizePixel = 0
        taperIn.Parent = innerLayer
        Instance.new("UICorner", taperIn).CornerRadius = UDim.new(1, 0)

        local neckIn = Instance.new("Frame")
        neckIn.Name = "DripNeckIn_" .. i
        neckIn.AnchorPoint = Vector2.new(0.5, 0)
        neckIn.Position = UDim2.new(d.x, 0, d.y, 0)
        neckIn.Size = UDim2.new(d.w * 0.85, 0, d.baseH, 0)
        neckIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        neckIn.BorderSizePixel = 0
        neckIn.Parent = innerLayer
        Instance.new("UICorner", neckIn).CornerRadius = UDim.new(1, 0)

        local bulbIn = Instance.new("Frame")
        bulbIn.Name = "DripBulbIn_" .. i
        bulbIn.AnchorPoint = Vector2.new(0.5, 0.5)
        bulbIn.Position = UDim2.new(d.x, 0, d.y + d.baseH, 0)
        bulbIn.Size = UDim2.new(d.w * 1.65, 0, (d.w * 1.65) * 1.72, 0)
        bulbIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bulbIn.BorderSizePixel = 0
        bulbIn.Parent = innerLayer
        Instance.new("UICorner", bulbIn).CornerRadius = UDim.new(1, 0)

        local gloss = Instance.new("Frame")
        gloss.Name = "DripGloss_" .. i
        gloss.AnchorPoint = Vector2.new(0.5, 0.5)
        gloss.Position = UDim2.new(d.x - d.w * 0.35, 0, d.y + d.baseH - 0.004, 0)
        gloss.Size = UDim2.new(d.w * 0.42, 0, d.w * 0.85, 0)
        gloss.BackgroundColor3 = COLOR_CELESTE
        gloss.BackgroundTransparency = 0.25
        gloss.BorderSizePixel = 0
        gloss.Parent = dripEffectsLayer
        Instance.new("UICorner", gloss).CornerRadius = UDim.new(1, 0)
    end

    -- 4. Orbes
    local thoughtCircles = {
        {x = 0.24, y = 0.68, w = 0.068, h = 0.104},
        {x = 0.14, y = 0.78, w = 0.046, h = 0.070},
        {x = 0.06, y = 0.87, w = 0.028, h = 0.043}
    }

    for i, tc in ipairs(thoughtCircles) do
        local orbOuter = Instance.new("Frame")
        orbOuter.Name = "OrbOuter_" .. i
        orbOuter.AnchorPoint = Vector2.new(0.5, 0.5)
        orbOuter.Position = UDim2.new(tc.x, 0, tc.y, 0)
        orbOuter.Size = UDim2.new(tc.w + 0.022, 0, tc.h + 0.034, 0)
        orbOuter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        orbOuter.BorderSizePixel = 0
        orbOuter.Parent = borderLayer
        Instance.new("UICorner", orbOuter).CornerRadius = UDim.new(1, 0)

        local orbSep = Instance.new("Frame")
        orbSep.Name = "OrbSep_" .. i
        orbSep.AnchorPoint = Vector2.new(0.5, 0.5)
        orbSep.Position = UDim2.new(tc.x, 0, tc.y, 0)
        orbSep.Size = UDim2.new(tc.w + 0.008, 0, tc.h + 0.012, 0)
        orbSep.BackgroundColor3 = SHIELD_SEPARATOR
        orbSep.BorderSizePixel = 0
        orbSep.Parent = separatorLayer
        Instance.new("UICorner", orbSep).CornerRadius = UDim.new(1, 0)

        local orbInner = Instance.new("Frame")
        orbInner.Name = "OrbInner_" .. i
        orbInner.AnchorPoint = Vector2.new(0.5, 0.5)
        orbInner.Position = UDim2.new(tc.x, 0, tc.y, 0)
        orbInner.Size = UDim2.new(tc.w, 0, tc.h, 0)
        orbInner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        orbInner.BorderSizePixel = 0
        orbInner.Parent = innerLayer
        Instance.new("UICorner", orbInner).CornerRadius = UDim.new(1, 0)
    end

    -- 5. Firma del personaje + Estrella + Raya calibrada
    local headerSig = Instance.new("Frame")
    headerSig.Name = "HeaderSignature"
    headerSig.AnchorPoint = Vector2.new(0.5, 0.5)
    headerSig.Position = UDim2.new(0.54, 0, 0.145, 0)
    headerSig.Size = UDim2.new(0.62, 0, 0.165, 0)
    headerSig.Rotation = -3
    headerSig.BackgroundTransparency = 1
    headerSig.ClipsDescendants = false
    headerSig.ZIndex = 14
    headerSig.Parent = cloudRoot

    local starEmblem = Instance.new("ImageLabel")
    starEmblem.Name = "StarEmblem"
    starEmblem.AnchorPoint = Vector2.new(0.5, 0.5)
    starEmblem.Position = UDim2.new(0.115, 0, 0.43, 0)
    starEmblem.Size = UDim2.new(0.325, 0, 1.76, 0)
    starEmblem.BackgroundTransparency = 1
    starEmblem.ImageTransparency = 0
    starEmblem.BorderSizePixel = 0
    starEmblem.Image = ""
    starEmblem.ScaleType = Enum.ScaleType.Fit
    starEmblem.ZIndex = 17
    starEmblem.Parent = headerSig
    applySafeWebImage(starEmblem, STAR_EMBLEM_URL, "omega_spidey_star_v2.png")

    local nameTextGroup = Instance.new("Frame")
    nameTextGroup.Name = "NameTextGroup"
    nameTextGroup.AnchorPoint = Vector2.new(0, 0.5)
    nameTextGroup.Position = UDim2.new(0.295, 0, 0.36, 0)
    nameTextGroup.Size = UDim2.new(0.685, 0, 0.68, 0)
    nameTextGroup.BackgroundTransparency = 1
    nameTextGroup.ZIndex = 15
    nameTextGroup.Parent = headerSig

    local shadowCyan = Instance.new("TextLabel")
    shadowCyan.Name = "ShadowCyan"
    shadowCyan.Position = UDim2.new(-0.016, 0, -0.022, 0)
    shadowCyan.Size = UDim2.new(1, 0, 1, 0)
    shadowCyan.BackgroundTransparency = 1
    shadowCyan.Font = Enum.Font.Bangers
    shadowCyan.TextScaled = true
    shadowCyan.TextXAlignment = Enum.TextXAlignment.Left
    shadowCyan.TextColor3 = COLOR_CELESTE
    shadowCyan.TextTransparency = 0.22
    shadowCyan.Text = "SPIDER-MAN"
    shadowCyan.ZIndex = 15
    shadowCyan.Parent = nameTextGroup

    local shadowRed = Instance.new("TextLabel")
    shadowRed.Name = "ShadowRed"
    shadowRed.Position = UDim2.new(0.016, 0, 0.022, 0)
    shadowRed.Size = UDim2.new(1, 0, 1, 0)
    shadowRed.BackgroundTransparency = 1
    shadowRed.Font = Enum.Font.Bangers
    shadowRed.TextScaled = true
    shadowRed.TextXAlignment = Enum.TextXAlignment.Left
    shadowRed.TextColor3 = COLOR_ROJO
    shadowRed.TextTransparency = 0.22
    shadowRed.Text = "SPIDER-MAN"
    shadowRed.ZIndex = 15
    shadowRed.Parent = nameTextGroup

    local headerLbl = Instance.new("TextLabel")
    headerLbl.Name = "HeaderLbl"
    headerLbl.Size = UDim2.new(1, 0, 1, 0)
    headerLbl.BackgroundTransparency = 1
    headerLbl.Font = Enum.Font.Bangers
    headerLbl.TextScaled = true
    headerLbl.TextXAlignment = Enum.TextXAlignment.Left
    headerLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    headerLbl.Text = "SPIDER-MAN"
    headerLbl.ZIndex = 16
    headerLbl.Parent = nameTextGroup

    local headerGrad = Instance.new("UIGradient", headerLbl)
    headerGrad.Name = "HeaderGrad"
    headerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.45, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1.00, COLOR_VIOLETA)
    })

    local headerStroke = Instance.new("UIStroke", headerLbl)
    headerStroke.Color = Color3.fromRGB(10, 20, 46)
    headerStroke.Thickness = 2.2

    local underlineBeam = Instance.new("ImageLabel")
    underlineBeam.Name = "UnderlineBeam"
    underlineBeam.AnchorPoint = Vector2.new(0.5, 0.5)
    underlineBeam.Position = BEAM_POS
    underlineBeam.Size = BEAM_SIZE
    underlineBeam.BackgroundTransparency = 1
    underlineBeam.ImageTransparency = 0
    underlineBeam.BorderSizePixel = 0
    underlineBeam.Image = ""
    underlineBeam.ScaleType = Enum.ScaleType.Stretch
    underlineBeam.ZIndex = 16
    underlineBeam.Parent = headerSig
    applySafeWebImage(underlineBeam, ENERGY_BEAM_URL, "omega_spidey_beam_v3.png")

    applyInnerColorToLayer(innerLayer)

    -- 6. Capa de ruptura
    local breachLayer = Instance.new("Frame")
    breachLayer.Name = "EnergyBreachLayer"
    breachLayer.Size = UDim2.new(1, 0, 1, 0)
    breachLayer.BackgroundTransparency = 1
    breachLayer.Visible = false
    breachLayer.ZIndex = 12
    breachLayer.Parent = cloudRoot

    local breachOrigin = Instance.new("Frame")
    breachOrigin.Name = "BreachOrigin"
    breachOrigin.AnchorPoint = Vector2.new(0.5, 0.5)
    breachOrigin.Position = UDim2.new(0.550, 0, 0.195, 0)
    breachOrigin.Size = UDim2.new(0, 0, 0, 0)
    breachOrigin.BackgroundColor3 = Color3.fromRGB(225, 250, 255)
    breachOrigin.BackgroundTransparency = 1
    breachOrigin.BorderSizePixel = 0
    breachOrigin.ZIndex = 13
    breachOrigin.Parent = breachLayer
    Instance.new("UICorner", breachOrigin).CornerRadius = UDim.new(1, 0)

    local originRing = Instance.new("Frame")
    originRing.Name = "OriginRing"
    originRing.AnchorPoint = Vector2.new(0.5, 0.5)
    originRing.Position = UDim2.new(0.550, 0, 0.195, 0)
    originRing.Size = UDim2.new(0, 0, 0, 0)
    originRing.BackgroundTransparency = 1
    originRing.ZIndex = 13
    originRing.Parent = breachLayer
    Instance.new("UICorner", originRing).CornerRadius = UDim.new(1, 0)

    local originRingStroke = Instance.new("UIStroke", originRing)
    originRingStroke.Name = "OriginRingStroke"
    originRingStroke.Color = COLOR_CELESTE
    originRingStroke.Thickness = 2.0
    originRingStroke.Transparency = 1

    -- 7. Zona segura de texto + ondas de música
    local safeTextZone = Instance.new("Frame")
    safeTextZone.Name = "SafeTextZone"
    safeTextZone.AnchorPoint = Vector2.new(0.5, 0.5)
    safeTextZone.Position = UDim2.new(0.57, 0, 0.415, 0)
    safeTextZone.Size = UDim2.new(0.55, 0, 0.33, 0)
    safeTextZone.ClipsDescendants = true
    safeTextZone.BackgroundTransparency = 1
    safeTextZone.ZIndex = 9
    safeTextZone.Parent = cloudRoot

    local quoteBox = Instance.new("Frame")
    quoteBox.Name = "QuoteBox"
    quoteBox.Size = UDim2.new(1, 0, 1, 0)
    quoteBox.ClipsDescendants = true
    quoteBox.BackgroundTransparency = 1
    quoteBox.ZIndex = 9
    quoteBox.Parent = safeTextZone

    local quoteLbl = Instance.new("TextLabel")
    quoteLbl.Name = "QuoteLbl"
    quoteLbl.Size = UDim2.new(1, 0, 1, 0)
    quoteLbl.BackgroundTransparency = 1
    quoteLbl.Font = Enum.Font.Bangers
    quoteLbl.TextWrapped = true
    quoteLbl.TextScaled = true
    quoteLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    quoteLbl.Text = ""
    quoteLbl.ZIndex = 10
    quoteLbl.Parent = quoteBox

    local quoteStroke = Instance.new("UIStroke", quoteLbl)
    quoteStroke.Name = "QuoteStroke"
    quoteStroke.Color = Color3.fromRGB(12, 26, 54)
    quoteStroke.Thickness = 2.0

    local textGrad = Instance.new("UIGradient", quoteLbl)
    textGrad.Name = "TextLightGrad"
    textGrad.Rotation = 12
    textGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.32, COLOR_ROJO),
        ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
        ColorSequenceKeypoint.new(0.68, COLOR_ROJO),
        ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
    })

    local musicWavesHolder = Instance.new("Frame")
    musicWavesHolder.Name = "MusicWavesHolder"
    musicWavesHolder.Size = UDim2.new(1, 0, 1, 0)
    musicWavesHolder.BackgroundTransparency = 1
    musicWavesHolder.Visible = false
    musicWavesHolder.ZIndex = 10
    musicWavesHolder.Parent = quoteBox

    local songIconLbl = Instance.new("TextLabel")
    songIconLbl.Name = "SongIconLbl"
    songIconLbl.AnchorPoint = Vector2.new(0.5, 0)
    songIconLbl.Position = UDim2.new(0.5, 0, 0.0, 0)
    songIconLbl.Size = UDim2.new(0.34, 0, 0.36, 0)
    songIconLbl.BackgroundTransparency = 1
    songIconLbl.Font = Enum.Font.GothamBlack
    songIconLbl.TextScaled = true
    songIconLbl.TextColor3 = COLOR_CELESTE
    songIconLbl.Text = "🎧"
    songIconLbl.ZIndex = 11
    songIconLbl.Parent = musicWavesHolder

    local barsFrame = Instance.new("Frame")
    barsFrame.Name = "BarsFrame"
    barsFrame.AnchorPoint = Vector2.new(0.5, 1)
    barsFrame.Position = UDim2.new(0.5, 0, 0.96, 0)
    barsFrame.Size = UDim2.new(0.84, 0, 0.56, 0)
    barsFrame.BackgroundTransparency = 1
    barsFrame.ZIndex = 11
    barsFrame.Parent = musicWavesHolder

    local numBars = 9
    for b = 1, numBars do
        local bar = Instance.new("Frame")
        bar.Name = "WaveBar_" .. b
        bar.AnchorPoint = Vector2.new(0.5, 0.5)
        local xPos = (b - 0.5) / numBars
        bar.Position = UDim2.new(xPos, 0, 0.5, 0)
        bar.Size = UDim2.new(0.068, 0, 0.35, 0)
        bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bar.BorderSizePixel = 0
        bar.ZIndex = 11
        bar.Parent = barsFrame
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local bGrad = Instance.new("UIGradient", bar)
        bGrad.Rotation = 90
        bGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, COLOR_CELESTE),
            ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
            ColorSequenceKeypoint.new(1.0, COLOR_VIOLETA)
        })
    end

    return bb
end

local function spawnPlasmaLeakDrop(parentLayer, originX, originY)
    if not parentLayer or not parentLayer.Parent then return end
    local drop = Instance.new("Frame")
    drop.Name = "DynamicPlasmaDrop"
    drop.AnchorPoint = Vector2.new(0.5, 0.5)
    drop.Position = UDim2.new(originX, 0, originY, 0)
    drop.Size = UDim2.new(0.015, 0, 0.024, 0)
    local colors = {COLOR_CELESTE, COLOR_VIOLETA, Color3.fromRGB(210, 245, 255)}
    drop.BackgroundColor3 = colors[math.random(1, #colors)]
    drop.BackgroundTransparency = 0.1
    drop.BorderSizePixel = 0
    drop.ZIndex = 13
    drop.Parent = parentLayer
    Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)

    local dStroke = Instance.new("UIStroke", drop)
    dStroke.Color = SHIELD_SEPARATOR
    dStroke.Thickness = 1

    local driftX = (math.random() - 0.5) * 0.12
    local fallY = math.min(originY + 0.18 + math.random() * 0.16, 0.97)
    local dur = 0.65 + math.random() * 0.30

    local tw = TweenService:Create(drop, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(math.clamp(originX + driftX, 0.05, 0.95), 0, fallY, 0),
        Size = UDim2.new(0.008, 0, 0.036, 0),
        BackgroundTransparency = 1
    })
    TweenService:Create(dStroke, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Transparency = 1
    }):Play()
    tw:Play()
    tw.Completed:Connect(function()
        if drop then drop:Destroy() end
    end)
end

local function startProgressiveEnergyBreach(cloudRoot, sessionId, char)
    if not cloudRoot then return end
    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
    if not breachLayer then return end

    breachLayer.Visible = true

    local breachOrigin = breachLayer:FindFirstChild("BreachOrigin")
    local originRing = breachLayer:FindFirstChild("OriginRing")
    local originRingStroke = originRing and originRing:FindFirstChild("OriginRingStroke")

    if breachOrigin then
        breachOrigin.Size = UDim2.new(0, 0, 0, 0)
        breachOrigin.BackgroundTransparency = 1
    end
    if originRing then
        originRing.Size = UDim2.new(0, 0, 0, 0)
        if originRingStroke then originRingStroke.Transparency = 1 end
    end

    task.delay(0.24, function()
        if not breachLayer or not breachLayer.Parent then return end
        if char and char:GetAttribute("VoiceSession") ~= sessionId then return end

        if breachOrigin then
            breachOrigin.BackgroundTransparency = 0.05
            TweenService:Create(breachOrigin, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0.032, 0, 0.048, 0)
            }):Play()
            task.delay(0.35, function()
                if breachOrigin and breachOrigin.Parent then
                    TweenService:Create(breachOrigin, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
                end
            end)
        end

        if originRing and originRingStroke then
            originRingStroke.Transparency = 0.1
            TweenService:Create(originRing, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0.18, 0, 0.26, 0)
            }):Play()
            TweenService:Create(originRingStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Transparency = 1
            }):Play()
        end
    end)

    for step = 1, 5 do
        local openDelay = 0.45 + (step - 1) * 0.10
        task.delay(openDelay, function()
            if not breachLayer or not breachLayer.Parent then return end
            if char and char:GetAttribute("VoiceSession") ~= sessionId then return end
            spawnPlasmaLeakDrop(breachLayer, 0.548 + (math.random() - 0.5) * 0.02, 0.20 + (step - 1) * 0.075)
        end)
    end
end

local function startCaptionEffectsLoop(char, sessionId, vfxType, isSong, isSadDeath)
    activeCaptionLoops[char] = sessionId
    local startTime = tick()
    local nextDropTime = 0
    local nextLeakTime = 0.85

    task.spawn(function()
        while activeCaptionLoops[char] == sessionId and char and char.Parent do
            local bb = charBillboards[char]
            if not bb or not bb.Parent or not bb.Enabled then break end

            local cloudRoot = bb:FindFirstChild("CloudRoot")
            if not cloudRoot or not cloudRoot.Visible then break end

            local elapsed = tick() - startTime

            local headerSig = cloudRoot:FindFirstChild("HeaderSignature")
            local starEmblem = headerSig and headerSig:FindFirstChild("StarEmblem")
            local nameTextGroup = headerSig and headerSig:FindFirstChild("NameTextGroup")
            local shadowCyan = nameTextGroup and nameTextGroup:FindFirstChild("ShadowCyan")
            local shadowRed = nameTextGroup and nameTextGroup:FindFirstChild("ShadowRed")
            local headerLbl = nameTextGroup and nameTextGroup:FindFirstChild("HeaderLbl")
            local headerGrad = headerLbl and headerLbl:FindFirstChild("HeaderGrad")

            if starEmblem then
                starEmblem.Rotation = (elapsed * 32) % 360
                local starPulse = 1 + math.sin(elapsed * 3.4) * 0.07
                starEmblem.Size = UDim2.new(0.325 * starPulse, 0, 1.76 * starPulse, 0)
            end

            if shadowCyan and shadowRed then
                local glitchOff = math.sin(elapsed * 3.8) * 0.005
                shadowCyan.Position = UDim2.new(-0.016 - glitchOff, 0, -0.022, 0)
                shadowRed.Position = UDim2.new(0.016 + glitchOff, 0, 0.022, 0)
            end

            if headerGrad then
                headerGrad.Offset = Vector2.new(math.sin(elapsed * 2.1) * 0.70, 0)
            end

            local safeTextZone = cloudRoot:FindFirstChild("SafeTextZone")
            local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
            local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
            local textGrad = quoteLbl and quoteLbl:FindFirstChild("TextLightGrad")
            if textGrad then
                local sweep = math.sin(elapsed * (isSadDeath and 1.1 or 2.5)) * 0.85
                textGrad.Offset = Vector2.new(sweep, 0)
            end

            if isSong and quoteBox then
                local musicWavesHolder = quoteBox:FindFirstChild("MusicWavesHolder")
                local barsFrame = musicWavesHolder and musicWavesHolder:FindFirstChild("BarsFrame")
                local songIconLbl = musicWavesHolder and musicWavesHolder:FindFirstChild("SongIconLbl")
                if songIconLbl then
                    local pulseIcon = 0.36 + math.sin(elapsed * 6.0) * 0.045
                    songIconLbl.Size = UDim2.new(0.34, 0, pulseIcon, 0)
                end
                if barsFrame then
                    for b = 1, 9 do
                        local bar = barsFrame:FindFirstChild("WaveBar_" .. b)
                        if bar then
                            local w1 = math.abs(math.sin(elapsed * 6.5 + b * 0.85))
                            local w2 = math.abs(math.cos(elapsed * 4.2 - b * 0.55))
                            local hScale = math.clamp(0.20 + (w1 * 0.55 + w2 * 0.30), 0.18, 0.98)
                            bar.Size = UDim2.new(0.068, 0, hScale, 0)
                        end
                    end
                end
            end

            local shieldGroup = cloudRoot:FindFirstChild("ShieldGroup")
            local dripEffectsLayer = cloudRoot:FindFirstChild("DripEffectsLayer")

            local splitProgress = 0
            if isSadDeath and elapsed > 0.45 then
                local rawT = math.clamp((elapsed - 0.45) / 0.85, 0, 1)
                splitProgress = rawT * rawT * (3 - 2 * rawT)
            end

            if shieldGroup then
                local holoFlicker = (isSadDeath and elapsed > 0.40) and (math.sin(elapsed * 22) * 0.03) or 0
                shieldGroup.GroupTransparency = math.clamp((isSadDeath and 0.26 or 0.22) + math.sin(elapsed * 2.8) * 0.04 + holoFlicker, 0.15, 0.45)

                local borderLayer = shieldGroup:FindFirstChild("BorderLayer")
                local separatorLayer = shieldGroup:FindFirstChild("SeparatorLayer")
                local innerLayer = shieldGroup:FindFirstChild("InnerLayer")

                if isSadDeath then
                    local breatheSplit = math.sin(elapsed * 3.0) * 0.005 * splitProgress
                    for i, sp in ipairs(LOBE_SPECS) do
                        local dx = (sp.side == -1) and (-0.052 * splitProgress - breatheSplit) or (0.066 * splitProgress + breatheSplit)
                        local dy = (sp.side == -1) and (0.012 * splitProgress) or (0.062 * splitProgress)
                        local outerLobe = borderLayer and borderLayer:FindFirstChild("OuterLobe_" .. i)
                        local sepLobe = separatorLayer and separatorLayer:FindFirstChild("SepLobe_" .. i)
                        local innerLobe = innerLayer and innerLayer:FindFirstChild("InnerLobe_" .. i)
                        if outerLobe then outerLobe.Position = UDim2.new(sp.x + dx, 0, sp.y + dy, 0) end
                        if sepLobe then sepLobe.Position = UDim2.new(sp.x + dx, 0, sp.y + dy, 0) end
                        if innerLobe then innerLobe.Position = UDim2.new(sp.x + dx, 0, sp.y + dy, 0) end
                    end

                    local centerCore = innerLayer and innerLayer:FindFirstChild("CenterCore")
                    if centerCore then
                        centerCore.Size = UDim2.new(0.50 * (1 - splitProgress * 0.76), 0, 0.32 * (1 - splitProgress * 0.28), 0)
                        centerCore.Position = UDim2.new(0.57, 0, 0.39 + 0.03 * splitProgress, 0)
                        centerCore.BackgroundTransparency = splitProgress * 0.65
                    end

                    if headerSig then
                        headerSig.Position = UDim2.new(0.54 - 0.030 * splitProgress, 0, 0.145 + 0.012 * splitProgress, 0)
                        headerSig.Rotation = -3 - 5.0 * splitProgress + math.sin(elapsed * 2.2) * 0.7
                    end

                    if quoteLbl then quoteLbl.Rotation = 3.0 * splitProgress end

                    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
                    if breachLayer and elapsed > 0.55 and elapsed >= nextLeakTime then
                        nextLeakTime = elapsed + 0.34
                        spawnPlasmaLeakDrop(breachLayer, 0.548 + (math.random() - 0.5) * 0.02, 0.22 + math.random() * 0.34)
                    end
                end

                local borderGrad = borderLayer and borderLayer:FindFirstChild("BorderGrad")
                local innerGrad = innerLayer and innerLayer:FindFirstChild("InnerGrad")

                if borderGrad then
                    borderGrad.Offset = Vector2.new(math.sin(elapsed * (isSadDeath and 0.9 or 2.2)) * 0.88, 0)
                    borderGrad.Rotation = 18 + math.cos(elapsed * 1.4) * 28
                end

                if innerGrad and innerGrad.Enabled then
                    innerGrad.Offset = Vector2.new(math.cos(elapsed * 1.6) * 0.45, 0)
                    innerGrad.Rotation = (elapsed * 25) % 360
                end

                for i, d in ipairs(DRIP_SPECS) do
                    local speedMult = isSadDeath and 0.65 or 1.0
                    local wave = (math.sin(elapsed * (2.1 + i * 0.35) * speedMult + i * 1.5) + 1) * 0.5
                    local curH = d.baseH + wave * (isSadDeath and 0.125 or 0.082)
                    local bulbScale = 0.92 + wave * 0.32
                    local neckThin = 1.0 - wave * 0.25

                    local dOffX = isSadDeath and ((d.side == -1) and (-0.048 * splitProgress) or (0.062 * splitProgress)) or 0
                    local dOffY = isSadDeath and ((d.side == -1) and (0.012 * splitProgress) or (0.060 * splitProgress)) or 0
                    local dxPos = d.x + dOffX
                    local dyPos = d.y + dOffY

                    local collarOut = borderLayer and borderLayer:FindFirstChild("DripCollarOut_" .. i)
                    local taperOut = borderLayer and borderLayer:FindFirstChild("DripTaperOut_" .. i)
                    local neckOut = borderLayer and borderLayer:FindFirstChild("DripNeckOut_" .. i)
                    local bulbOut = borderLayer and borderLayer:FindFirstChild("DripBulbOut_" .. i)
                    if collarOut then collarOut.Position = UDim2.new(dxPos, 0, dyPos, 0) end
                    if taperOut then
                        taperOut.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        taperOut.Size = UDim2.new(d.w * 1.80 + 0.026, 0, curH * 0.45 + 0.024, 0)
                    end
                    if neckOut then
                        neckOut.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        neckOut.Size = UDim2.new((d.w * 0.85 * neckThin) + 0.024, 0, curH + 0.024, 0)
                    end
                    if bulbOut then
                        bulbOut.Position = UDim2.new(dxPos, 0, dyPos + curH, 0)
                        bulbOut.Size = UDim2.new((d.w * 1.65) * bulbScale + 0.026, 0, ((d.w * 1.65) * 1.72) * bulbScale + 0.038, 0)
                    end

                    local collarSep = separatorLayer and separatorLayer:FindFirstChild("DripCollarSep_" .. i)
                    local taperSep = separatorLayer and separatorLayer:FindFirstChild("DripTaperSep_" .. i)
                    local neckSep = separatorLayer and separatorLayer:FindFirstChild("DripNeckSep_" .. i)
                    local bulbSep = separatorLayer and separatorLayer:FindFirstChild("DripBulbSep_" .. i)
                    if collarSep then collarSep.Position = UDim2.new(dxPos, 0, dyPos, 0) end
                    if taperSep then
                        taperSep.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        taperSep.Size = UDim2.new(d.w * 1.80 + 0.010, 0, curH * 0.45 + 0.010, 0)
                    end
                    if neckSep then
                        neckSep.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        neckSep.Size = UDim2.new((d.w * 0.85 * neckThin) + 0.008, 0, curH + 0.010, 0)
                    end
                    if bulbSep then
                        bulbSep.Position = UDim2.new(dxPos, 0, dyPos + curH, 0)
                        bulbSep.Size = UDim2.new((d.w * 1.65) * bulbScale + 0.010, 0, ((d.w * 1.65) * 1.72) * bulbScale + 0.014, 0)
                    end

                    local collarIn = innerLayer and innerLayer:FindFirstChild("DripCollarIn_" .. i)
                    local taperIn = innerLayer and innerLayer:FindFirstChild("DripTaperIn_" .. i)
                    local neckIn = innerLayer and innerLayer:FindFirstChild("DripNeckIn_" .. i)
                    local bulbIn = innerLayer and innerLayer:FindFirstChild("DripBulbIn_" .. i)
                    if collarIn then collarIn.Position = UDim2.new(dxPos, 0, dyPos, 0) end
                    if taperIn then
                        taperIn.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        taperIn.Size = UDim2.new(d.w * 1.80, 0, curH * 0.45, 0)
                    end
                    if neckIn then
                        neckIn.Position = UDim2.new(dxPos, 0, dyPos, 0)
                        neckIn.Size = UDim2.new(d.w * 0.85 * neckThin, 0, curH, 0)
                    end
                    if bulbIn then
                        bulbIn.Position = UDim2.new(dxPos, 0, dyPos + curH, 0)
                        bulbIn.Size = UDim2.new((d.w * 1.65) * bulbScale, 0, ((d.w * 1.65) * 1.72) * bulbScale, 0)
                    end

                    local gloss = dripEffectsLayer and dripEffectsLayer:FindFirstChild("DripGloss_" .. i)
                    if gloss then
                        gloss.Position = UDim2.new(dxPos - (d.w * 0.35 * bulbScale), 0, dyPos + curH - 0.004, 0)
                        gloss.Size = UDim2.new(d.w * 0.42 * bulbScale, 0, d.w * 0.85 * bulbScale, 0)
                    end
                end

                if dripEffectsLayer and tick() >= nextDropTime then
                    nextDropTime = tick() + (isSadDeath and 0.32 or 0.48)
                    local pick = math.random(1, #DRIP_SPECS)
                    local d = DRIP_SPECS[pick]
                    local bulbIn = innerLayer and innerLayer:FindFirstChild("DripBulbIn_" .. pick)
                    if bulbIn then
                        local drop = Instance.new("Frame")
                        drop.AnchorPoint = Vector2.new(0.5, 0.5)
                        drop.Position = bulbIn.Position
                        drop.Size = UDim2.new(0.020, 0, 0.036, 0)
                        drop.BackgroundColor3 = isSadDeath and COLOR_CELESTE or d.dropColor
                        drop.BorderSizePixel = 0
                        drop.Parent = dripEffectsLayer
                        Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)

                        local dStroke = Instance.new("UIStroke", drop)
                        dStroke.Color = SHIELD_SEPARATOR
                        dStroke.Thickness = 1.2

                        local dropGloss = Instance.new("Frame")
                        dropGloss.AnchorPoint = Vector2.new(0.5, 0.5)
                        dropGloss.Position = UDim2.new(0.32, 0, 0.38, 0)
                        dropGloss.Size = UDim2.new(0.28, 0, 0.34, 0)
                        dropGloss.BackgroundColor3 = COLOR_CELESTE
                        dropGloss.BackgroundTransparency = 0.2
                        dropGloss.BorderSizePixel = 0
                        dropGloss.Parent = drop
                        Instance.new("UICorner", dropGloss).CornerRadius = UDim.new(1, 0)

                        local startDropX = bulbIn.Position.X.Scale
                        local startDropY = bulbIn.Position.Y.Scale
                        local fallTw = TweenService:Create(drop, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                            Position = UDim2.new(startDropX, 0, math.min(startDropY + 0.22, 0.98), 0),
                            Size = UDim2.new(0.011, 0, 0.048, 0),
                            BackgroundTransparency = 1
                        })
                        TweenService:Create(dStroke, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                            Transparency = 1
                        }):Play()
                        fallTw:Play()
                        fallTw.Completed:Connect(function()
                            if drop then drop:Destroy() end
                        end)
                    end
                end

                local baseOrbs = {
                    {w = 0.068, h = 0.104},
                    {w = 0.046, h = 0.070},
                    {w = 0.028, h = 0.043}
                }
                for i = 1, 3 do
                    local orbOuter = borderLayer and borderLayer:FindFirstChild("OrbOuter_" .. i)
                    local orbSep = separatorLayer and separatorLayer:FindFirstChild("OrbSep_" .. i)
                    local orbInner = innerLayer and innerLayer:FindFirstChild("OrbInner_" .. i)
                    local pulse = 1 + math.sin(elapsed * 4.2 - i * 0.7) * 0.12
                    if orbOuter then orbOuter.Size = UDim2.new((baseOrbs[i].w + 0.022) * pulse, 0, (baseOrbs[i].h + 0.034) * pulse, 0) end
                    if orbSep then orbSep.Size = UDim2.new((baseOrbs[i].w + 0.008) * pulse, 0, (baseOrbs[i].h + 0.012) * pulse, 0) end
                    if orbInner then orbInner.Size = UDim2.new(baseOrbs[i].w * pulse, 0, baseOrbs[i].h * pulse, 0) end
                end
            end

            local panX = math.sin(elapsed * (isSadDeath and 1.2 or 2.1)) * 0.022
            local panY = math.cos(elapsed * (isSadDeath and 1.4 or 2.7)) * 0.016 + (isSadDeath and 0.050 * splitProgress or 0)

            local shakeX, shakeY, shakeRot = 0, 0, 0
            if vfxType == "damage" and elapsed < 0.35 then
                local power = 1 - (elapsed / 0.35)
                shakeX = math.sin(elapsed * 62) * 0.018 * power
                shakeY = math.cos(elapsed * 68) * 0.014 * power
                shakeRot = math.sin(elapsed * 54) * 2.8 * power
            elseif isSadDeath and elapsed >= 0.24 and elapsed < 1.15 then
                local pTime = elapsed - 0.24
                local envelope = math.sin(math.clamp(pTime / 0.91, 0, 1) * math.pi)
                shakeX = math.sin(elapsed * 64) * 0.024 * envelope
                shakeY = math.cos(elapsed * 70) * 0.018 * envelope
                shakeRot = math.sin(elapsed * 56) * 3.8 * envelope
            end

            local baseRot = isSadDeath and (-3 + 9.5 * splitProgress) or -3
            cloudRoot.Position = UDim2.new(0.5 + panX + shakeX, 0, 0.5 + panY + shakeY, 0)
            cloudRoot.Rotation = baseRot + math.sin(elapsed * 1.9) * 1.6 + shakeRot

            RunService.RenderStepped:Wait()
        end
    end)
end

local function transitionBubbleQuote(char, sessionId, newText)
    if not char or not newText then return end
    local bb = charBillboards[char]
    if not bb or not bb.Parent then return end

    local cloudRoot = bb:FindFirstChild("CloudRoot")
    local safeTextZone = cloudRoot and cloudRoot:FindFirstChild("SafeTextZone")
    local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
    local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
    if not quoteLbl then return end

    local quoteStroke = quoteLbl:FindFirstChild("QuoteStroke") or quoteLbl:FindFirstChildOfClass("UIStroke")

    task.spawn(function()
        if char:GetAttribute("VoiceSession") ~= sessionId then return end

        local fadeOut = TweenService:Create(quoteLbl, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            TextTransparency = 1
        })
        if quoteStroke then
            TweenService:Create(quoteStroke, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Transparency = 1
            }):Play()
        end
        fadeOut:Play()
        fadeOut.Completed:Wait()

        if char:GetAttribute("VoiceSession") ~= sessionId then return end

        quoteLbl.Text = ""
        quoteLbl.TextTransparency = 0
        if quoteStroke then quoteStroke.Transparency = 0 end

        local isLongText = (#newText > 35)
        local charDelay = isLongText and 0.032 or 0.015

        for i = 1, #newText do
            if char:GetAttribute("VoiceSession") ~= sessionId then return end
            quoteLbl.Text = string.sub(newText, 1, i)
            task.wait(charDelay)
        end
    end)
end

local function showThoughtBubble(char, data, sessionId, overrideQuote)
    local bb = getBillboard(char)
    if not bb then return end

    local vfxType = (data and data.vfxType) or "random"
    local isSong = (data and data.isSong) == true
    local isSadDeath = (data and data.isSadDeath) == true

    setHeadParticles(char, true, isSadDeath)

    if not VfxActivos then
        bb.Enabled = false
        return
    end

    local cloudRoot = bb:FindFirstChild("CloudRoot")
    if not cloudRoot then return end

    resetBubbleGeometry(cloudRoot)

    local breachLayer = cloudRoot:FindFirstChild("EnergyBreachLayer")
    if breachLayer then
        if isSadDeath then
            startProgressiveEnergyBreach(cloudRoot, sessionId, char)
        else
            breachLayer.Visible = false
        end
    end

    local shieldGroup = cloudRoot:FindFirstChild("ShieldGroup")
    local borderLayer = shieldGroup and shieldGroup:FindFirstChild("BorderLayer")
    local borderGrad = borderLayer and borderLayer:FindFirstChild("BorderGrad")
    if borderGrad then
        if isSadDeath then
            borderGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(115, 185, 250)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(130, 110, 200)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(85, 135, 205))
            })
        else
            borderGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
                ColorSequenceKeypoint.new(0.28, COLOR_ROJO),
                ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
                ColorSequenceKeypoint.new(0.72, COLOR_ROJO),
                ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
            })
        end
    end

    local headerSig = cloudRoot:FindFirstChild("HeaderSignature")
    local nameTextGroup = headerSig and headerSig:FindFirstChild("NameTextGroup")
    local shadowCyan = nameTextGroup and nameTextGroup:FindFirstChild("ShadowCyan")
    local shadowRed = nameTextGroup and nameTextGroup:FindFirstChild("ShadowRed")
    local headerLbl = nameTextGroup and nameTextGroup:FindFirstChild("HeaderLbl")

    local safeTextZone = cloudRoot:FindFirstChild("SafeTextZone")
    local quoteBox = safeTextZone and safeTextZone:FindFirstChild("QuoteBox")
    local quoteLbl = quoteBox and quoteBox:FindFirstChild("QuoteLbl")
    local musicWavesHolder = quoteBox and quoteBox:FindFirstChild("MusicWavesHolder")

    local fullText = overrideQuote or (data and (data.quote or data.key)) or ""
    local heroName = ((data and (data.hero or data.char)) or "SPIDER-MAN"):upper()

    if headerLbl then headerLbl.Text = heroName end
    if shadowCyan then shadowCyan.Text = heroName end
    if shadowRed then shadowRed.Text = heroName end

    if activeBillboards[char] then
        for _, tw in ipairs(activeBillboards[char]) do
            if tw then tw:Cancel() end
        end
    end
    activeBillboards[char] = {}

    bb.Enabled = true
    bb.StudsOffset = Vector3.new(2.15, 1.90, 0)
    cloudRoot.Visible = true
    cloudRoot.Size = UDim2.new(0.12, 0, 0.12, 0)

    local targetOffset = isSadDeath and Vector3.new(2.55, 1.72, 0) or Vector3.new(2.55, 2.15, 0)

    local tOffset = TweenService:Create(bb, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        StudsOffset = targetOffset
    })
    local tPop = TweenService:Create(cloudRoot, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0)
    })

    table.insert(activeBillboards[char], tOffset)
    table.insert(activeBillboards[char], tPop)

    tOffset:Play()
    tPop:Play()

    if sessionId then
        startCaptionEffectsLoop(char, sessionId, vfxType, isSong, isSadDeath)
    end

    if quoteLbl and sessionId then
        local quoteStroke = quoteLbl:FindFirstChild("QuoteStroke") or quoteLbl:FindFirstChildOfClass("UIStroke")
        local textGrad = quoteLbl:FindFirstChild("TextLightGrad")

        if isSong then
            quoteLbl.Visible = false
            if musicWavesHolder then musicWavesHolder.Visible = true end
        else
            if musicWavesHolder then musicWavesHolder.Visible = false end
            quoteLbl.Visible = true
            quoteLbl.TextTransparency = 0
            if quoteStroke then quoteStroke.Transparency = 0 end

            if isSadDeath then
                quoteLbl.Font = Enum.Font.SpecialElite
                if textGrad then
                    textGrad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(185, 225, 255)),
                        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(160, 145, 215)),
                        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(140, 190, 245))
                    })
                end
            else
                quoteLbl.Font = Enum.Font.Bangers
                if textGrad then
                    textGrad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0.00, COLOR_CELESTE),
                        ColorSequenceKeypoint.new(0.32, COLOR_ROJO),
                        ColorSequenceKeypoint.new(0.50, COLOR_VIOLETA),
                        ColorSequenceKeypoint.new(0.68, COLOR_ROJO),
                        ColorSequenceKeypoint.new(1.00, COLOR_CELESTE)
                    })
                end
            end

            quoteLbl.Text = ""
            local isLongText = (#fullText > 35)
            local charDelay = isSadDeath and 0.045 or (isLongText and 0.032 or 0.015)

            task.spawn(function()
                for i = 1, #fullText do
                    if char:GetAttribute("VoiceSession") ~= sessionId then return end
                    quoteLbl.Text = string.sub(fullText, 1, i)
                    task.wait(charDelay)
                end
            end)
        end
    end
end

local function endVoicelineEffect(char, sessionId)
    if not char or char:GetAttribute("VoiceSession") ~= sessionId then return end

    activeCaptionLoops[char] = nil
    setHeadParticles(char, false)

    local bb = charBillboards[char]
    if bb and bb.Parent then
        local cloudRoot = bb:FindFirstChild("CloudRoot")
        if cloudRoot and cloudRoot.Visible then
            local shrink = TweenService:Create(cloudRoot, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0)
            })
            shrink:Play()
            shrink.Completed:Connect(function()
                if char:GetAttribute("VoiceSession") == sessionId and bb and bb.Parent then
                    cloudRoot.Visible = false
                    bb.Enabled = false
                    resetBubbleGeometry(cloudRoot)
                end
            end)
        else
            bb.Enabled = false
        end
    end
end

-- Orquestador de tiempos exclusivos del globo (soporta 1, 2 y 3 fases)
local function runBubbleTimeline(char, bubbleData, sessionId, text1, startDelay, splitDelay, text2, isSecondStep, splitDelay2, text3)
    if not char then return 0 end
    startDelay = math.max(0, tonumber(startDelay) or 0)
    splitDelay = math.max(0, tonumber(splitDelay) or 0)
    splitDelay2 = math.max(0, tonumber(splitDelay2) or 0)
    text1 = text1 or ""
    text2 = text2 or ""
    text3 = text3 or ""

    char:SetAttribute("VoiceSession", sessionId)

    local function triggerShow()
        if not char or not char.Parent then return end
        if char:GetAttribute("VoiceSession") ~= sessionId then return end

        if isSecondStep then
            transitionBubbleQuote(char, sessionId, text1)
        else
            showThoughtBubble(char, bubbleData, sessionId, text1)
        end

        if text2 ~= "" then
            local waitBetween1 = (splitDelay > 0) and splitDelay or 1.2
            task.delay(waitBetween1, function()
                if not char or not char.Parent then return end
                if char:GetAttribute("VoiceSession") ~= sessionId then return end
                transitionBubbleQuote(char, sessionId, text2)

                if text3 ~= "" then
                    local waitBetween2 = (splitDelay2 > 0) and splitDelay2 or 1.2
                    task.delay(waitBetween2, function()
                        if not char or not char.Parent then return end
                        if char:GetAttribute("VoiceSession") ~= sessionId then return end
                        transitionBubbleQuote(char, sessionId, text3)
                    end)
                end
            end)
        end
    end

    if startDelay > 0 then
        if not isSecondStep then
            local bb = charBillboards[char]
            if bb and bb.Parent then
                bb.Enabled = false
            end
        end
        task.delay(startDelay, triggerShow)
    else
        triggerShow()
    end

    local minVisualTime = startDelay + 1.4
    if text2 ~= "" then
        local effectiveSplit1 = (splitDelay > 0) and splitDelay or 1.2
        if text3 ~= "" then
            local effectiveSplit2 = (splitDelay2 > 0) and splitDelay2 or 1.2
            minVisualTime = startDelay + effectiveSplit1 + effectiveSplit2 + 1.5
        else
            minVisualTime = startDelay + effectiveSplit1 + 1.5
        end
    elseif splitDelay > 0 then
        minVisualTime = startDelay + splitDelay
    end
    return minVisualTime
end

local function scheduleBubbleEnd(char, sessionId, playStartTime, minVisualTime)
    if not char then return end
    local elapsed = tick() - playStartTime
    local remaining = (minVisualTime or 0) - elapsed
    if remaining > 0.05 then
        task.delay(remaining, function()
            endVoicelineEffect(char, sessionId)
        end)
    else
        endVoicelineEffect(char, sessionId)
    end
end

-- ==========================================
-- SISTEMA DE AUDIO UNIFICADO (SPIDER-MAN + DEMÁS PERSONAJES)
-- ==========================================
local cachedAudio = {}
local activeSong = nil
local activeExtraVoices = {}
local extraSeq = {}
local extraLastPlay = {}
local previewSessionToken = 0
local activePreviewSounds = {}

local function stopAllPreviewSounds()
    previewSessionToken = previewSessionToken + 1
    for i = #activePreviewSounds, 1, -1 do
        local s = activePreviewSounds[i]
        activePreviewSounds[i] = nil
        if s then
            pcall(function()
                s.Looped = false
                s:Stop()
                s:Destroy()
            end)
        end
    end
    return previewSessionToken
end

local function sanitizeUrl(url)
    if type(url) ~= "string" then return url end
    url = url:gsub("github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)", "raw.githubusercontent.com/%1/%2/%3/%4")
    return url
end

local function getAudioSource(rawSrc, cacheKey, srcType)
    if not rawSrc or rawSrc == "" then return nil end

    if srcType == "id" or tonumber(rawSrc) then
        return "rbxassetid://" .. tostring(rawSrc)
    end

    if cachedAudio[cacheKey] then
        return cachedAudio[cacheKey]
    end

    local finalUrl = rawSrc
    if not finalUrl:match("^https?://") then
        finalUrl = GITHUB_BASE .. finalUrl:gsub(" ", "%%20")
    else
        finalUrl = sanitizeUrl(finalUrl)
    end

    local hash = 0
    for i = 1, #finalUrl do
        hash = (hash * 31 + string.byte(finalUrl, i)) % 1000000007
    end

    local safeKey = tostring(cacheKey):gsub("[^%w_]", "")
    local fileName = "v8_cr_" .. safeKey .. "_" .. tostring(hash) .. ".mp3"

    if not (isfile and isfile(fileName)) then
        local success = pcall(function()
            if writefile then
                writefile(fileName, game:HttpGet(finalUrl))
            end
        end)
        if not success then
            return finalUrl
        end
    end

    if getasset then
        local ok, asset = pcall(function() return getasset(fileName) end)
        if ok and asset then
            cachedAudio[cacheKey] = asset
            return asset
        end
    end
    return finalUrl
end

local function stopActiveSong(withFade)
    if not activeSong then return end
    local songObj = activeSong
    activeSong = nil
    songObj.stopping = true

    local s = songObj.sound
    if s and s.Parent then
        if withFade then
            TweenService:Create(s, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Volume = 0}):Play()
            task.delay(0.7, function()
                if s and s.Parent then
                    pcall(function() s:Stop(); s:Destroy() end)
                end
            end)
        else
            pcall(function() s:Stop(); s:Destroy() end)
        end
    end

    if songObj.char and songObj.sessionId then
        endVoicelineEffect(songObj.char, songObj.sessionId)
    end
end

local function beginSongInterference()
    if not activeSong or activeSong.stopping then return end
    local songObj = activeSong
    songObj.interrupts = (songObj.interrupts or 0) + 1
    if songObj.interrupts > 1 then return end

    local s = songObj.sound
    if not s or not s.Parent then return end

    task.spawn(function()
        local baseVol = getClipVolume(songObj.data.key .. "_1", songObj.data.defVol)
        local flickers = {baseVol * 0.25, 0, baseVol * 0.4, 0}
        for _, v in ipairs(flickers) do
            if not activeSong or activeSong ~= songObj or songObj.stopping or (songObj.interrupts or 0) <= 0 then
                return
            end
            if s and s.Parent then s.Volume = v end
            task.wait(0.045)
        end
        if activeSong == songObj and not songObj.stopping and (songObj.interrupts or 0) > 0 and s and s.Parent then
            pcall(function() s:Pause() end)
        end
    end)
end

local function endSongInterference()
    if not activeSong or activeSong.stopping then return end
    local songObj = activeSong
    songObj.interrupts = math.max(0, (songObj.interrupts or 1) - 1)
    if songObj.interrupts > 0 then return end

    local s = songObj.sound
    if not s or not s.Parent then return end

    if songObj.char and songObj.sessionId then
        songObj.char:SetAttribute("VoiceSession", songObj.sessionId)
        showThoughtBubble(songObj.char, songObj.data, songObj.sessionId, "🎧")
    end

    task.spawn(function()
        local targetVol = getClipVolume(songObj.data.key .. "_1", songObj.data.defVol)
        pcall(function() s:Resume() end)
        local flickers = {0, targetVol * 0.35, targetVol * 0.1, targetVol * 0.65}
        for _, v in ipairs(flickers) do
            if activeSong ~= songObj or songObj.stopping or (songObj.interrupts or 0) > 0 then
                return
            end
            if s and s.Parent then s.Volume = v end
            task.wait(0.045)
        end
        if activeSong == songObj and not songObj.stopping and (songObj.interrupts or 0) == 0 and s and s.Parent then
            TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {Volume = targetVol}):Play()
        end
    end)
end

local function stopAllActiveVoices()
    stopAllPreviewSounds()
    stopActiveSong(false)
    for idx, info in pairs(activeExtraVoices) do
        if info.sound then pcall(function() info.sound:Stop(); info.sound:Destroy() end) end
        if info.char and info.sessionId then
            endVoicelineEffect(info.char, info.sessionId)
        end
        activeExtraVoices[idx] = nil
    end
end

-- Reproductor de Spider-Man
local function playSpiderManSound(data, preview, char, forceClipIndex)
    if not VoicelinesActivas and not preview then return end

    local myPreviewToken = nil
    if preview then
        myPreviewToken = stopAllPreviewSounds()
    end

    if data.isSong then
        if activeSong then
            if preview then stopActiveSong(true) end
            return
        end

        local src = getAudioSource(data.src, data.key .. "_song", data.type)
        if not src then return end
        if preview and myPreviewToken ~= previewSessionToken then return end

        local targetVol = getClipVolume(data.key .. "_1", data.defVol)
        local s = Instance.new("Sound")
        s.SoundId = src
        s.Volume = 0
        s.Looped = true
        s:SetAttribute("IsCustomVoice", true)
        s.Parent = preview and CoreGui or player:WaitForChild("PlayerGui")
        if preview then table.insert(activePreviewSounds, s) end

        local sessionId = tick()
        local songObj = {
            sound = s,
            data = data,
            char = char,
            sessionId = sessionId,
            interrupts = 0,
            stopping = false
        }
        activeSong = songObj

        if char then
            char:SetAttribute("VoiceSession", sessionId)
            showThoughtBubble(char, data, sessionId, "🎧")
        end

        s:Play()
        TweenService:Create(s, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Volume = targetVol
        }):Play()

        s.Ended:Connect(function()
            if activeSong == songObj then stopActiveSong(false) end
        end)
        return
    end

    if data.isSadDeath and activeSong then
        stopActiveSong(false)
    end

    local targetVol1 = getClipVolume(data.key .. "_1", data.defVol)
    local targetVol2 = getClipVolume(data.key .. "_2", targetVol1)
    local causedInterference = false
    if not data.isSadDeath and activeSong and not activeSong.stopping then
        causedInterference = true
        beginSongInterference()
    end

    local parentContainer = (preview or data.isSadDeath) and CoreGui or player:WaitForChild("PlayerGui")
    local sessionId = tick()
    local playStartTime = tick()

    -- Previsualizar parte 2 de Spider Trap
    if forceClipIndex == 2 and data.nextSrc then
        local src2 = getAudioSource(data.nextSrc, data.key .. "_2", "url")
        if not src2 then return end
        if preview and myPreviewToken ~= previewSessionToken then return end

        local s2 = Instance.new("Sound")
        s2.SoundId = src2
        s2.Volume = targetVol2
        s2.Looped = false
        s2:SetAttribute("IsCustomVoice", true)
        s2.Parent = parentContainer
        if preview then table.insert(activePreviewSounds, s2) end

        local minVis = runBubbleTimeline(char, data, sessionId, data.nextQuote, 0, 0, "", false)
        s2:Play()
        s2.Ended:Connect(function()
            if s2 and s2.Parent then pcall(function() s2:Stop(); s2:Destroy() end) end
            if causedInterference then endSongInterference() end
            scheduleBubbleEnd(char, sessionId, playStartTime, minVis)
        end)
        return
    end

    local src1 = getAudioSource(data.src, data.key .. "_1", data.type)
    if not src1 then return end
    if preview and myPreviewToken ~= previewSessionToken then return end

    local primaryVol = targetVol1 * (data.primaryVolFactor or 1)
    local s1 = Instance.new("Sound")
    s1.SoundId = src1
    s1.Volume = data.fade and 0 or primaryVol
    s1.Looped = false
    s1:SetAttribute("IsCustomVoice", true)
    s1.Parent = parentContainer
    if preview then table.insert(activePreviewSounds, s1) end

    local minVis = runBubbleTimeline(
        char, data, sessionId,
        data.quote,
        data.startDelayTime or 0,
        data.afterDelayTime or 0,
        data.afterDelayQuote or "",
        false
    )

    s1:Play()
    if data.fade then
        TweenService:Create(s1, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Volume = primaryVol}):Play()
    end

    local sExtra = nil
    if data.extraUrl then
        local srcExtra = getAudioSource(data.extraUrl, data.key .. "_extra", "url")
        if srcExtra and (not preview or myPreviewToken == previewSessionToken) then
            sExtra = Instance.new("Sound")
            sExtra.SoundId = srcExtra
            sExtra.Volume = targetVol1 * (data.extraVolFactor or 0.8)
            sExtra.Looped = false
            sExtra:SetAttribute("IsCustomVoice", true)
            sExtra.Parent = parentContainer
            if preview then table.insert(activePreviewSounds, sExtra) end
            sExtra:Play()
        end
    end

    local s2 = nil
    local cleaned = false

    local function cleanup(overrideMinVis)
        if cleaned then return end
        cleaned = true
        if s1 and s1.Parent then pcall(function() s1:Stop(); s1:Destroy() end) end
        if s2 and s2.Parent then pcall(function() s2:Stop(); s2:Destroy() end) end
        if sExtra and sExtra.Parent then pcall(function() sExtra:Stop(); sExtra:Destroy() end) end
        if causedInterference then
            endSongInterference()
        end
        scheduleBubbleEnd(char, sessionId, playStartTime, overrideMinVis or minVis)
    end

    if data.nextSrc then
        local src2 = getAudioSource(data.nextSrc, data.key .. "_2", "url")
        s1.Ended:Connect(function()
            if cleaned then return end
            if preview and myPreviewToken ~= previewSessionToken then
                cleanup(0)
                return
            end
            if s1 and s1.Parent then pcall(function() s1:Stop(); s1:Destroy() end) end

            local step2Start = tick()
            local minVis2 = runBubbleTimeline(char, data, sessionId, data.nextQuote, 0, 0, "", true)

            if src2 then
                s2 = Instance.new("Sound")
                s2.SoundId = src2
                s2.Volume = getClipVolume(data.key .. "_2", targetVol1)
                s2.Looped = false
                s2:SetAttribute("IsCustomVoice", true)
                s2.Parent = parentContainer
                if preview then table.insert(activePreviewSounds, s2) end
                s2:Play()
                s2.Ended:Connect(function()
                    playStartTime = step2Start
                    cleanup(minVis2)
                end)
            else
                playStartTime = step2Start
                cleanup(minVis2)
            end
        end)
    else
        s1.Ended:Connect(function() cleanup(minVis) end)
    end

    task.delay(25, function() cleanup(minVis) end)
end

-- Reproductor de las voicelines de los demás personajes
local function stopMainExtraForChar(char)
    for idx, info in pairs(activeExtraVoices) do
        if info.char == char and not info.noCancel and info.sound then
            local s = info.sound
            activeExtraVoices[idx] = nil
            pcall(function()
                local tw = TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Volume = 0})
                tw:Play()
                tw.Completed:Connect(function()
                    pcall(function() s:Stop(); s:Destroy() end)
                end)
            end)
        end
    end
end

local function playExtraVoiceline(animData, targetChar, animTrack, forceIndex, isPreview)
    if not VoicelinesActivas and not isPreview then return end
    if not targetChar then return end
    if SoloMisVoces and not isPreview and targetChar ~= player.Character then return end

    local myPreviewToken = nil
    if isPreview then
        myPreviewToken = stopAllPreviewSounds()
    end

    if not isPreview then
        for _, sInfo in pairs(activeExtraVoices) do
            if sInfo.char == targetChar and sInfo.animId == animData.id then
                return
            end
        end
    end

    local now = tick()
    if not isPreview then
        if animData.id == 110895682591322 and (now - (extraLastPlay[animData.id] or 0) < 4.0) then return end
        if (animData.group == "main" or animData.group == "main_nocancel") and (now - (extraLastPlay[animData.id] or 0) < 0.15) then return end
    end
    extraLastPlay[animData.id] = now

    local isLocalChar = (targetChar == player.Character)
    local sessionId = tick()
    local cancelled = false
    local bubbleData = {
        hero = animData.char,
        char = animData.char,
        vfxType = (animData.id == 99999999999999) and "death" or "response",
        isSadDeath = (animData.id == 99999999999999)
    }

    -- MODO CUT (Carrie Push / Scrim)
    if animData.mode == "cut" or animData.group == "push1" or animData.group == "scrim" then
        local cut = PUSH_CUTS[animData.id]
        if not cut then return end

        local causedInterference = false
        if isLocalChar and activeSong and not activeSong.stopping then
            causedInterference = true
            beginSongInterference()
        end

        local function finishCutSession(pStart, minVis)
            if causedInterference then endSongInterference() end
            scheduleBubbleEnd(targetChar, sessionId, pStart or tick(), minVis or 0)
        end

        local volKey = tostring(animData.id) .. "_1"
        local vol = getClipVolume(volKey, animData.defaultVols[1] or 3.0)
        local qSpec = getEffectiveQuoteSpec(animData, 1)

        local src = getAudioSource(cut.file, "extra_" .. animData.id .. "_1", "url")
        if not src then
            if causedInterference then endSongInterference() end
            return
        end
        if isPreview and myPreviewToken ~= previewSessionToken then return end

        local sound = Instance.new("Sound")
        sound.SoundId = src
        sound.Volume = cut.useFadeIn and 0 or math.clamp(vol, 0, 10)
        sound.Looped = false
        sound:SetAttribute("IsCustomVoice", true)
        sound.Parent = isPreview and CoreGui or player:WaitForChild("PlayerGui")
        if isPreview then table.insert(activePreviewSounds, sound) end

        local idx = #activeExtraVoices + 1
        activeExtraVoices[idx] = {sound = sound, char = targetChar, animId = animData.id, sessionId = sessionId, noCancel = false}

        local pStart = tick()
        local minVis = runBubbleTimeline(targetChar, bubbleData, sessionId, qSpec.t1, qSpec.start, qSpec.split, qSpec.t2, false, qSpec.split2, qSpec.t3)

        task.spawn(function()
            pcall(function() if not sound.IsLoaded then sound.Loaded:Wait() end end)
            if isPreview and myPreviewToken ~= previewSessionToken then
                pcall(function() sound:Stop(); sound:Destroy() end)
                activeExtraVoices[idx] = nil
                return
            end
            if not VoicelinesActivas and not isPreview then
                pcall(function() sound:Stop(); sound:Destroy() end)
                activeExtraVoices[idx] = nil
                finishCutSession(pStart, minVis)
                return
            end

            local total = sound.TimeLength
            if total == 0 or total ~= total then total = cut.endT + 0.5 end
            local sPos = math.clamp(cut.start, 0, total)
            local ePos = math.clamp(cut.endT, sPos + 0.1, total)
            local dur = ePos - sPos

            sound.TimePosition = sPos
            sound:Play()

            if cut.useFadeIn then
                TweenService:Create(sound, TweenInfo.new(cut.fadeIn, Enum.EasingStyle.Sine), {Volume = math.clamp(vol, 0, 10)}):Play()
            else
                sound.Volume = math.clamp(vol, 0, 10)
            end

            if cut.useFadeOut then
                task.delay(math.max(0, dur - cut.fadeOut), function()
                    if sound and sound.Parent and sound.IsPlaying then
                        TweenService:Create(sound, TweenInfo.new(cut.fadeOut, Enum.EasingStyle.Sine), {Volume = 0}):Play()
                    end
                end)
            end

            if animTrack then
                animTrack.Stopped:Connect(function()
                    if animData.id ~= 110895682591322 and animData.id ~= 112275408128882 then
                        if activeExtraVoices[idx] then
                            activeExtraVoices[idx] = nil
                            pcall(function()
                                TweenService:Create(sound, TweenInfo.new(0.2), {Volume = 0}):Play()
                                task.delay(0.2, function() pcall(function() sound:Stop(); sound:Destroy() end) end)
                            end)
                            finishCutSession(pStart, minVis)
                        end
                    end
                end)
            end

            task.delay(dur + 0.2, function()
                if activeExtraVoices[idx] then
                    activeExtraVoices[idx] = nil
                    pcall(function() sound:Stop(); sound:Destroy() end)
                    finishCutSession(pStart, minVis)
                end
            end)
        end)
        return
    end

    -- MODO CYCLE / CHAIN (main y main_nocancel)
    if not isPreview then
        stopMainExtraForChar(targetChar)
    end
    local currentSounds = {}
    local causedInterference = false

    local function finishSession(pStart, minVis)
        if causedInterference then
            causedInterference = false
            endSongInterference()
        end
        scheduleBubbleEnd(targetChar, sessionId, pStart or tick(), minVis or 0)
    end

    local function onCancel()
        if cancelled then return end
        cancelled = true
        local stoppedAny = false
        for _, sInfo in ipairs(currentSounds) do
            if sInfo and sInfo.sound and not sInfo.noCancel then
                stoppedAny = true
                if sInfo.idx then activeExtraVoices[sInfo.idx] = nil end
                pcall(function()
                    local tw = TweenService:Create(sInfo.sound, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Volume = 0})
                    tw:Play()
                    tw.Completed:Connect(function()
                        pcall(function() sInfo.sound:Stop(); sInfo.sound:Destroy() end)
                    end)
                end)
            end
        end
        if stoppedAny then
            if causedInterference then
                causedInterference = false
                endSongInterference()
            end
            endVoicelineEffect(targetChar, sessionId)
        end
    end

    if animTrack and animData.group ~= "main_nocancel" then
        animTrack.Stopped:Connect(onCancel)
    end

    if animData.mode == "chain" and not forceIndex then
        if isLocalChar and activeSong and not activeSong.stopping then
            causedInterference = true
            beginSongInterference()
        end

        local function playChainStep(stepIdx)
            if cancelled or (not VoicelinesActivas and not isPreview) then return end
            if isPreview and myPreviewToken ~= previewSessionToken then return end
            if stepIdx > #animData.files then
                finishSession(tick(), 0)
                return
            end

            local delayBefore = (stepIdx == 2 and 0.15) or (stepIdx == 3 and 0.5) or 0
            if delayBefore > 0 then task.wait(delayBefore) end
            if cancelled or (not VoicelinesActivas and not isPreview) then return end
            if isPreview and myPreviewToken ~= previewSessionToken then return end

            local volKey = tostring(animData.id) .. "_" .. tostring(stepIdx)
            local vol = getClipVolume(volKey, animData.defaultVols[stepIdx] or 3.0)
            local qSpec = getEffectiveQuoteSpec(animData, stepIdx)
            local isNoCancel = (not isPreview) and ((animData.group == "main_nocancel") or (animData.nocancel and animData.nocancel[stepIdx] == true))

            local src = getAudioSource(animData.files[stepIdx], "extra_" .. animData.id .. "_" .. stepIdx, "url")
            if not src then
                playChainStep(stepIdx + 1)
                return
            end
            if isPreview and myPreviewToken ~= previewSessionToken then return end

            local pStart = tick()
            local minVis = runBubbleTimeline(targetChar, bubbleData, sessionId, qSpec.t1, qSpec.start, qSpec.split, qSpec.t2, stepIdx > 1, qSpec.split2, qSpec.t3)

            local sound = Instance.new("Sound")
            sound.SoundId = src
            sound.Volume = math.clamp(vol, 0, 10)
            sound.Looped = false
            sound:SetAttribute("IsCustomVoice", true)
            sound.Parent = isPreview and CoreGui or player:WaitForChild("PlayerGui")
            if isPreview then table.insert(activePreviewSounds, sound) end

            local idx = #activeExtraVoices + 1
            local sInfo = {sound = sound, char = targetChar, animId = animData.id, sessionId = sessionId, noCancel = isNoCancel, idx = idx}
            activeExtraVoices[idx] = sInfo
            table.insert(currentSounds, sInfo)

            local stepDone = false
            local function nextStep()
                if stepDone then return end
                stepDone = true
                activeExtraVoices[idx] = nil
                pcall(function() sound:Stop(); sound:Destroy() end)
                if isPreview and myPreviewToken ~= previewSessionToken then return end
                if stepIdx >= #animData.files then
                    finishSession(pStart, minVis)
                else
                    playChainStep(stepIdx + 1)
                end
            end

            sound.Ended:Connect(nextStep)
            task.delay(10, nextStep)
            sound:Play()
        end

        task.spawn(function() playChainStep(1) end)
    else
        local clipIdx = forceIndex
        if not clipIdx then
            local charKey = targetChar.Name
            extraSeq[charKey] = extraSeq[charKey] or {}

            local eligibleIndices = {}
            local hasQueenMorph = isQueenOfTheDeadMorph(targetChar)
            for i = 1, #animData.files do
                local needsQueen = animData.requiresQueenMorph and animData.requiresQueenMorph[i] == true
                local blockQueen = animData.excludeQueenMorph and animData.excludeQueenMorph[i] == true
                local allowed = true
                if needsQueen and not hasQueenMorph then
                    allowed = false
                end
                if blockQueen and hasQueenMorph then
                    allowed = false
                end
                if allowed then
                    table.insert(eligibleIndices, i)
                end
            end
            if #eligibleIndices == 0 then
                eligibleIndices = {1}
            end

            local seqPos = extraSeq[charKey][animData.id] or 1
            if seqPos > #eligibleIndices then seqPos = 1 end
            clipIdx = eligibleIndices[seqPos]
            extraSeq[charKey][animData.id] = (seqPos % #eligibleIndices) + 1
        end

        local volKey = tostring(animData.id) .. "_" .. tostring(clipIdx)
        local vol = getClipVolume(volKey, animData.defaultVols[clipIdx] or 3.0)
        local qSpec = getEffectiveQuoteSpec(animData, clipIdx)
        local isNoCancel = (not isPreview) and ((animData.group == "main_nocancel") or (animData.nocancel and animData.nocancel[clipIdx] == true))
        local audioDelay = math.max(0, tonumber(qSpec.audioDelay) or 0)

        local function startClipExecution()
            if cancelled or (not VoicelinesActivas and not isPreview) then return end
            if isPreview and myPreviewToken ~= previewSessionToken then return end

            local src = getAudioSource(animData.files[clipIdx], "extra_" .. animData.id .. "_" .. clipIdx, "url")
            if not src then return end
            if isPreview and myPreviewToken ~= previewSessionToken then return end

            if isLocalChar and activeSong and not activeSong.stopping then
                causedInterference = true
                beginSongInterference()
            end

            local pStart = tick()
            local minVis = runBubbleTimeline(targetChar, bubbleData, sessionId, qSpec.t1, qSpec.start, qSpec.split, qSpec.t2, false, qSpec.split2, qSpec.t3)

            local sound = Instance.new("Sound")
            sound.SoundId = src
            sound.Volume = math.clamp(vol, 0, 10)
            sound.Looped = false
            sound:SetAttribute("IsCustomVoice", true)
            sound.Parent = isPreview and CoreGui or player:WaitForChild("PlayerGui")
            if isPreview then table.insert(activePreviewSounds, sound) end

            local idx = #activeExtraVoices + 1
            local sInfo = {sound = sound, char = targetChar, animId = animData.id, sessionId = sessionId, noCancel = isNoCancel, idx = idx}
            activeExtraVoices[idx] = sInfo
            table.insert(currentSounds, sInfo)

            local finished = false
            local function onDone()
                if finished then return end
                finished = true
                activeExtraVoices[idx] = nil
                pcall(function() sound:Stop(); sound:Destroy() end)
                finishSession(pStart, minVis)
            end

            sound.Ended:Connect(onDone)
            task.delay(10, onDone)
            sound:Play()
        end

        if audioDelay > 0 then
            task.delay(audioDelay, startClipExecution)
        else
            startClipExecution()
        end
    end
end

-- ==========================================
-- GUI PREMIUM: CHAMPIONS RISE VOICELINES
-- ==========================================
if CoreGui:FindFirstChild("OmegaPremiumUI") then CoreGui.OmegaPremiumUI:Destroy() end

local ui = Instance.new("ScreenGui")
ui.Name = "OmegaPremiumUI"
ui.Parent = CoreGui
ui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 620)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -310)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Parent = ui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = COLOR_CELESTE
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.5

mainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(mainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 500, 0, 620)
}):Play()

task.spawn(function()
    while task.wait() do
        if not mainFrame or not mainFrame.Parent then break end
        local idx = (math.floor(tick() * 1.2) % #GLOBAL_PALETTE) + 1
        mainStroke.Color = GLOBAL_PALETTE[idx]
    end
end)

-- BARRA SUPERIOR
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundTransparency = 1
topBar.Active = true
topBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 250, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "CHAMPIONS RISE VOICELINES"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBlack
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local titleGrad = Instance.new("UIGradient", title)
titleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLOR_CELESTE),
    ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
    ColorSequenceKeypoint.new(1, COLOR_VIOLETA)
})

-- Botón VFX ON/OFF
local vfxBtn = Instance.new("TextButton")
vfxBtn.Size = UDim2.new(0, 62, 0, 24)
vfxBtn.Position = UDim2.new(1, -214, 0.5, -12)
vfxBtn.BackgroundColor3 = VfxActivos and Color3.fromRGB(70, 110, 240) or Color3.fromRGB(45, 45, 55)
vfxBtn.Text = VfxActivos and "VFX: ON" or "VFX: OFF"
vfxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
vfxBtn.Font = Enum.Font.GothamBold
vfxBtn.TextSize = 10
vfxBtn.Parent = topBar
Instance.new("UICorner", vfxBtn).CornerRadius = UDim.new(1, 0)

vfxBtn.MouseButton1Click:Connect(function()
    VfxActivos = not VfxActivos
    vfxBtn.Text = VfxActivos and "VFX: ON" or "VFX: OFF"
    TweenService:Create(vfxBtn, TweenInfo.new(0.25), {
        BackgroundColor3 = VfxActivos and Color3.fromRGB(70, 110, 240) or Color3.fromRGB(45, 45, 55)
    }):Play()
    if not VfxActivos then
        for char, bb in pairs(charBillboards) do
            setHeadParticles(char, false)
            if bb then bb.Enabled = false end
        end
    end
    saveConfig()
end)

-- Switch global ON/OFF
local switchBg = Instance.new("Frame")
switchBg.Size = UDim2.new(0, 46, 0, 24)
switchBg.Position = UDim2.new(1, -144, 0.5, -12)
switchBg.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
switchBg.Parent = topBar
Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

local switchKnob = Instance.new("Frame")
switchKnob.Size = UDim2.new(0, 20, 0, 20)
switchKnob.Position = UDim2.new(1, -22, 0.5, -10)
switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
switchKnob.Parent = switchBg
Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

local switchBtn = Instance.new("TextButton")
switchBtn.Size = UDim2.new(1, 0, 1, 0)
switchBtn.BackgroundTransparency = 1
switchBtn.Text = ""
switchBtn.Parent = switchBg

switchBtn.MouseButton1Click:Connect(function()
    VoicelinesActivas = not VoicelinesActivas
    if VoicelinesActivas then
        TweenService:Create(switchBg, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 220, 120)}):Play()
        TweenService:Create(switchKnob, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(1, -22, 0.5, -10)}):Play()
    else
        TweenService:Create(switchBg, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
        TweenService:Create(switchKnob, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 2, 0.5, -10)}):Play()
        stopAllActiveVoices()
    end
end)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 36, 1, 0)
minBtn.Position = UDim2.new(1, -86, 0, 0)
minBtn.BackgroundTransparency = 1
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 1, 0)
closeBtn.Position = UDim2.new(1, -44, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 24
closeBtn.Parent = topBar

-- Arrastre de ventana
do
    local dragToggle, dragInput, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragToggle = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragToggle = false end
            end)
        end
    end)
    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragToggle then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = minimized and UDim2.new(0, 500, 0, 52) or UDim2.new(0, 500, 0, 620)
    }):Play()
end)

closeBtn.MouseButton1Click:Connect(function()
    stopAllActiveVoices()
    local tw = TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
    tw:Play()
    tw.Completed:Connect(function() ui:Destroy() end)
end)

-- ==========================================
-- BARRA DE PESTAÑAS HORIZONTAL DESLIZABLE
-- ==========================================
local tabBarFrame = Instance.new("Frame")
tabBarFrame.Size = UDim2.new(1, -30, 0, 42)
tabBarFrame.Position = UDim2.new(0, 15, 0, 54)
tabBarFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
tabBarFrame.Parent = mainFrame
Instance.new("UICorner", tabBarFrame).CornerRadius = UDim.new(0, 10)

local tabStroke = Instance.new("UIStroke", tabBarFrame)
tabStroke.Color = Color3.fromRGB(45, 45, 60)
tabStroke.Thickness = 1

local tabScroll = Instance.new("ScrollingFrame")
tabScroll.Size = UDim2.new(1, -8, 1, -4)
tabScroll.Position = UDim2.new(0, 4, 0, 2)
tabScroll.BackgroundTransparency = 1
tabScroll.ScrollingDirection = Enum.ScrollingDirection.X
tabScroll.ScrollBarThickness = 3
tabScroll.ScrollBarImageColor3 = Color3.fromRGB(110, 130, 185)
tabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tabScroll.Parent = tabBarFrame

local tabLayout = Instance.new("UIListLayout", tabScroll)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

RunService.RenderStepped:Connect(function()
    if tabScroll and tabScroll.Parent then
        tabScroll.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X + 8, 0, 0)
    end
end)

local TAB_DEFS = {
    {id = "SPIDER-MAN",   label = "SPIDER-MAN",   color = Color3.fromRGB(215, 45, 65)},
    {id = "JEAN GREY",    label = "JEAN GREY",    color = Color3.fromRGB(220, 75, 135)},
    {id = "WANDA",        label = "WANDA",        color = Color3.fromRGB(205, 40, 65)},
    {id = "WANDA ZOMBIE", label = "WANDA ZOMBIE", color = Color3.fromRGB(145, 45, 95)},
    {id = "CARRIE",       label = "CARRIE",       color = Color3.fromRGB(185, 35, 50)},
    {id = "ELEVEN",       label = "ELEVEN",       color = Color3.fromRGB(95, 115, 225)},
    {id = "ATOM",         label = "ATOM",         color = Color3.fromRGB(55, 165, 215)},
    {id = "COLOR GLOB",   label = "COLOR GLOB",   color = Color3.fromRGB(65, 155, 235)},
}

local tabButtons = {}
local tabPages = {}

local function createScrollPage(name)
    local sc = Instance.new("ScrollingFrame")
    sc.Name = "TabPage_" .. name
    sc.Size = UDim2.new(1, -30, 1, -112)
    sc.Position = UDim2.new(0, 15, 0, 104)
    sc.BackgroundTransparency = 1
    sc.ScrollBarThickness = 4
    sc.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
    sc.Visible = false
    sc.Parent = mainFrame

    local ly = Instance.new("UIListLayout", sc)
    ly.Padding = UDim.new(0, 10)
    ly.SortOrder = Enum.SortOrder.LayoutOrder

    RunService.RenderStepped:Connect(function()
        if sc and sc.Parent then
            sc.CanvasSize = UDim2.new(0, 0, 0, ly.AbsoluteContentSize.Y + 20)
        end
    end)
    return sc
end

local function selectTab(tabId)
    for _, def in ipairs(TAB_DEFS) do
        local isSel = (def.id == tabId)
        local btn = tabButtons[def.id]
        local page = tabPages[def.id]
        if page then page.Visible = isSel end
        if btn then
            TweenService:Create(btn, TweenInfo.new(0.22), {
                BackgroundColor3 = isSel and def.color or Color3.fromRGB(24, 24, 34),
                TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(155, 160, 185)
            }):Play()
        end
    end
end

for idx, def in ipairs(TAB_DEFS) do
    local btn = Instance.new("TextButton")
    btn.Name = "TabBtn_" .. def.id
    btn.LayoutOrder = idx
    btn.Size = UDim2.new(0, math.max(82, #def.label * 8 + 20), 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    btn.Text = def.label
    btn.TextColor3 = Color3.fromRGB(155, 160, 185)
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 11
    btn.Parent = tabScroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    tabButtons[def.id] = btn
    if def.id == "COLOR GLOB" then
        local frame = Instance.new("Frame")
        frame.Name = "CustomTab_" .. def.id
        frame.Size = UDim2.new(1, -30, 1, -112)
        frame.Position = UDim2.new(0, 15, 0, 104)
        frame.BackgroundTransparency = 1
        frame.Visible = false
        frame.Parent = mainFrame
        tabPages[def.id] = frame
    else
        tabPages[def.id] = createScrollPage(def.id)
    end

    btn.MouseButton1Click:Connect(function()
        selectTab(def.id)
    end)
end

-- ==========================================
-- CONSTRUCTOR DE TARJETA LIMPIA (VOLUMEN INDIVIDUAL + PREVIEW)
-- ==========================================
local function createVoicelineCard(parentScroll, config)
    local accentColor = GLOBAL_PALETTE[((config.order or 1) % #GLOBAL_PALETTE) + 1]
    local clips = config.clips or {}
    local showSubClips = (#clips > 1)
    local subRowHeight = 46
    local cardHeight = showSubClips and (64 + (#clips * (subRowHeight + 4))) or 64

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, cardHeight)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    row.LayoutOrder = config.order or 1
    row.Parent = parentScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color = Color3.fromRGB(40, 40, 50)
    rStroke.Thickness = 1

    row.MouseEnter:Connect(function()
        TweenService:Create(rStroke, TweenInfo.new(0.25), {Color = accentColor}):Play()
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(rStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(40, 40, 50)}):Play()
    end)

    local typeDot = Instance.new("Frame")
    typeDot.Size = UDim2.new(0, 8, 0, 8)
    typeDot.Position = UDim2.new(0, 14, 0, 17)
    typeDot.BackgroundColor3 = accentColor
    typeDot.Parent = row
    Instance.new("UICorner", typeDot).CornerRadius = UDim.new(1, 0)

    local lblRightPad = -110

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, lblRightPad, 0, 24)
    lbl.Position = UDim2.new(0, 28, 0, 9)
    lbl.BackgroundTransparency = 1
    lbl.Text = config.title .. (config.badge and ("  [" .. config.badge .. "]") or "")
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = row


    local previewAllBtn = Instance.new("TextButton")
    previewAllBtn.Size = UDim2.new(0, 74, 0, 24)
    previewAllBtn.Position = UDim2.new(1, -86, 0, 9)
    previewAllBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
    previewAllBtn.Text = "PREVIEW"
    previewAllBtn.TextColor3 = Color3.fromRGB(220, 225, 255)
    previewAllBtn.Font = Enum.Font.GothamBlack
    previewAllBtn.TextSize = 10
    previewAllBtn.Parent = row
    Instance.new("UICorner", previewAllBtn).CornerRadius = UDim.new(0, 7)

    previewAllBtn.MouseButton1Click:Connect(function()
        if config.onPreviewAll then
            config.onPreviewAll()
        elseif clips[1] and clips[1].onPreview then
            clips[1].onPreview()
        end
    end)

    -- Slider de volumen principal (o general cuando hay varios clips)
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -82, 0, 10)
    sliderBg.Position = UDim2.new(0, 14, 0, 42)
    sliderBg.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    sliderBg.Parent = row
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

    local currentVol = getClipVolume(config.volKey, config.defVol)
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(math.clamp(currentVol / 10, 0, 1), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderFill.Parent = sliderBg
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

    local fGrad = Instance.new("UIGradient", sliderFill)
    fGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLOR_CELESTE),
        ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
        ColorSequenceKeypoint.new(1, COLOR_VIOLETA)
    })

    local volTxt = Instance.new("TextLabel")
    volTxt.Size = UDim2.new(0, 44, 0, 18)
    volTxt.Position = UDim2.new(1, -56, 0, 38)
    volTxt.BackgroundTransparency = 1
    volTxt.Text = math.floor((currentVol / 10) * 100) .. "%"
    volTxt.TextColor3 = Color3.fromRGB(200, 200, 220)
    volTxt.Font = Enum.Font.GothamBold
    volTxt.TextSize = 11
    volTxt.Parent = row

    local subSliderUpdaters = {}

    local draggingSlider = false
    local function updateSlider(input)
        local relX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        TweenService:Create(sliderFill, TweenInfo.new(0.05, Enum.EasingStyle.Sine), {Size = UDim2.new(relX, 0, 1, 0)}):Play()
        volTxt.Text = math.floor(relX * 100) .. "%"
        local newVol = math.max(0.1, relX * 10)
        VolumeData[config.volKey] = newVol
        if config.onVolChange then config.onVolChange(newVol) end
        for _, syncFn in ipairs(subSliderUpdaters) do
            syncFn(newVol)
        end
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            updateSlider(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            draggingSlider = false
            saveConfig()
        end
    end)

    -- Botones individuales + slider de volumen propio para cada voiceline si hay 2 o más clips
    if showSubClips then
        for cIdx, clip in ipairs(clips) do
            local yOff = 60 + (cIdx - 1) * (subRowHeight + 4)
            local subFrame = Instance.new("Frame")
            subFrame.Size = UDim2.new(1, -24, 0, subRowHeight)
            subFrame.Position = UDim2.new(0, 12, 0, yOff)
            subFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
            subFrame.Parent = row
            Instance.new("UICorner", subFrame).CornerRadius = UDim.new(0, 8)

            local tagLbl = Instance.new("TextLabel")
            tagLbl.Size = UDim2.new(1, -48, 0, 20)
            tagLbl.Position = UDim2.new(0, 10, 0, 3)
            tagLbl.BackgroundTransparency = 1
            tagLbl.Text = clip.label
            tagLbl.TextColor3 = Color3.fromRGB(185, 195, 225)
            tagLbl.Font = Enum.Font.GothamSemibold
            tagLbl.TextSize = 11
            tagLbl.TextXAlignment = Enum.TextXAlignment.Left
            tagLbl.TextTruncate = Enum.TextTruncate.AtEnd
            tagLbl.Parent = subFrame

            local playMiniBtn = Instance.new("TextButton")
            playMiniBtn.Size = UDim2.new(0, 28, 0, 18)
            playMiniBtn.Position = UDim2.new(1, -34, 0, 4)
            playMiniBtn.BackgroundColor3 = Color3.fromRGB(55, 95, 210)
            playMiniBtn.Text = "▶"
            playMiniBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            playMiniBtn.Font = Enum.Font.GothamBold
            playMiniBtn.TextSize = 9
            playMiniBtn.Parent = subFrame
            Instance.new("UICorner", playMiniBtn).CornerRadius = UDim.new(0, 5)

            playMiniBtn.MouseButton1Click:Connect(function()
                if clip.onPreview then clip.onPreview() end
            end)

            local clipVolKey = clip.volKey or (config.volKey .. "_" .. tostring(cIdx))
            local clipDefVol = clip.defVol or config.defVol or 3.0
            local cVol = getClipVolume(clipVolKey, clipDefVol)

            local subSliderBg = Instance.new("Frame")
            subSliderBg.Size = UDim2.new(1, -64, 0, 7)
            subSliderBg.Position = UDim2.new(0, 10, 0, 30)
            subSliderBg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
            subSliderBg.Parent = subFrame
            Instance.new("UICorner", subSliderBg).CornerRadius = UDim.new(1, 0)

            local subSliderFill = Instance.new("Frame")
            subSliderFill.Size = UDim2.new(math.clamp(cVol / 10, 0, 1), 0, 1, 0)
            subSliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            subSliderFill.Parent = subSliderBg
            Instance.new("UICorner", subSliderFill).CornerRadius = UDim.new(1, 0)

            local subGrad = Instance.new("UIGradient", subSliderFill)
            subGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, COLOR_CELESTE),
                ColorSequenceKeypoint.new(0.5, COLOR_ROJO),
                ColorSequenceKeypoint.new(1, COLOR_VIOLETA)
            })

            local subVolTxt = Instance.new("TextLabel")
            subVolTxt.Size = UDim2.new(0, 40, 0, 14)
            subVolTxt.Position = UDim2.new(1, -46, 0, 26)
            subVolTxt.BackgroundTransparency = 1
            subVolTxt.Text = math.floor((cVol / 10) * 100) .. "%"
            subVolTxt.TextColor3 = Color3.fromRGB(165, 175, 205)
            subVolTxt.Font = Enum.Font.GothamBold
            subVolTxt.TextSize = 10
            subVolTxt.Parent = subFrame

            table.insert(subSliderUpdaters, function(masterVol)
                local r = math.clamp(masterVol / 10, 0, 1)
                subSliderFill.Size = UDim2.new(r, 0, 1, 0)
                subVolTxt.Text = math.floor(r * 100) .. "%"
                VolumeData[clipVolKey] = masterVol
            end)

            local draggingSub = false
            local function updateSubSlider(input)
                local relX = math.clamp((input.Position.X - subSliderBg.AbsolutePosition.X) / subSliderBg.AbsoluteSize.X, 0, 1)
                TweenService:Create(subSliderFill, TweenInfo.new(0.05, Enum.EasingStyle.Sine), {Size = UDim2.new(relX, 0, 1, 0)}):Play()
                subVolTxt.Text = math.floor(relX * 100) .. "%"
                local newSubVol = math.max(0.1, relX * 10)
                VolumeData[clipVolKey] = newSubVol
                if clip.onVolChange then clip.onVolChange(newSubVol) end
            end

            subSliderBg.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSub = true
                    updateSubSlider(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if draggingSub and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateSubSlider(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if draggingSub and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                    draggingSub = false
                    saveConfig()
                end
            end)
        end
    end
end

-- ==========================================
-- POBLAR PESTAÑA 1: SPIDER-MAN
-- ==========================================
do
    local spideyPage = tabPages["SPIDER-MAN"]

    local ssData = SOUND_TRACKED["71182782447096"]
    createVoicelineCard(spideyPage, {
        title = ssData.key,
        badge = "SENSE",
        order = 1,
        volKey = ssData.key .. "_1",
        defVol = ssData.defVol,
        onPreviewAll = function() playSpiderManSound(ssData, true, player.Character) end
    })

    local stData = TRACKED["126744091497158"]
    createVoicelineCard(spideyPage, {
        title = stData.key,
        badge = "2 PARTES",
        order = 2,
        volKey = stData.key .. "_1",
        defVol = stData.defVol,
        onPreviewAll = function() playSpiderManSound(stData, true, player.Character) end,
        onVolChange = function(newVol)
            VolumeData[stData.key .. "_1"] = newVol
            VolumeData[stData.key .. "_2"] = newVol
        end,
        clips = {
            {
                label = "1. Hahah",
                volKey = stData.key .. "_1",
                defVol = stData.defVol,
                onPreview = function() playSpiderManSound(stData, true, player.Character) end
            },
            {
                label = "2. Im in control bubby",
                volKey = stData.key .. "_2",
                defVol = stData.defVol,
                onPreview = function() playSpiderManSound(stData, true, player.Character, 2) end
            }
        }
    })

    local singleSpideyList = {
        {data = TRACKED["114696600161120"], badge = "VOZ", order = 3},
        {data = TRACKED["110771864835896"], badge = "VOZ", order = 4},
        {data = TRACKED["99079784262381"],  badge = "VOZ", order = 5},
        {data = SONG_DATA,                  badge = "MÚSICA", order = 6},
        {data = DEATH_VOICELINE,            badge = "DEATH", order = 7},
    }

    for _, item in ipairs(singleSpideyList) do
        local d = item.data
        createVoicelineCard(spideyPage, {
            title = d.key,
            badge = item.badge,
            order = item.order,
            volKey = d.key .. "_1",
            defVol = d.defVol,
            onPreviewAll = function() playSpiderManSound(d, true, player.Character) end,
            onVolChange = function(newVol)
                if d.isSong and activeSong and activeSong.sound and activeSong.sound.Parent and (activeSong.interrupts or 0) == 0 then
                    activeSong.sound.Volume = newVol
                end
            end
        })
    end
end

-- ==========================================
-- POBLAR PESTAÑAS DE LOS DEMÁS PERSONAJES
-- ==========================================
do
    local extraChars = {"JEAN GREY", "WANDA", "WANDA ZOMBIE", "CARRIE", "ELEVEN", "ATOM"}
    for _, charName in ipairs(extraChars) do
        local page = tabPages[charName]
        local ord = 1
        for _, d in ipairs(EXTRA_ANIM_DATA) do
            if d.char == charName then
                local clipItems = {}
                for i, dispName in ipairs(d.displayNames) do
                    local clipIdx = i
                    local vKey = tostring(d.id) .. "_" .. tostring(clipIdx)
                    table.insert(clipItems, {
                        label = clipIdx .. ". " .. dispName,
                        volKey = vKey,
                        defVol = d.defaultVols[clipIdx] or 3.0,
                        onPreview = function()
                            playExtraVoiceline(d, player.Character, nil, clipIdx, true)
                        end
                    })
                end

                createVoicelineCard(page, {
                    title = d.name,
                    badge = d.mode:upper(),
                    order = ord,
                    volKey = tostring(d.id) .. "_1",
                    defVol = d.defaultVols[1] or 3.0,
                    onPreviewAll = function()
                        playExtraVoiceline(d, player.Character, nil, nil, true)
                    end,
                    onVolChange = function(newVol)
                        for idx = 1, #d.files do
                            VolumeData[tostring(d.id) .. "_" .. tostring(idx)] = newVol
                        end
                    end,
                    clips = clipItems
                })
                ord = ord + 1
            end
        end
    end
end

-- ==========================================
-- PESTAÑA COLOR GLOB
-- ==========================================
do
    local colorGlobContainer = tabPages["COLOR GLOB"]

    local inputCard = Instance.new("Frame")
    inputCard.Size = UDim2.new(1, -6, 0, 106)
    inputCard.Position = UDim2.new(0, 3, 0, 2)
    inputCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    inputCard.Parent = colorGlobContainer
    Instance.new("UICorner", inputCard).CornerRadius = UDim.new(0, 12)

    local inputCardStroke = Instance.new("UIStroke", inputCard)
    inputCardStroke.Color = Color3.fromRGB(40, 40, 50)
    inputCardStroke.Thickness = 1

    local inputHeaderLbl = Instance.new("TextLabel")
    inputHeaderLbl.Size = UDim2.new(1, -24, 0, 20)
    inputHeaderLbl.Position = UDim2.new(0, 12, 0, 8)
    inputHeaderLbl.BackgroundTransparency = 1
    inputHeaderLbl.Text = "COLOR INTERIOR DEL GLOBO (HEX)"
    inputHeaderLbl.TextColor3 = Color3.fromRGB(185, 195, 220)
    inputHeaderLbl.Font = Enum.Font.GothamBlack
    inputHeaderLbl.TextSize = 11
    inputHeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
    inputHeaderLbl.Parent = inputCard

    local hexInput = Instance.new("TextBox")
    hexInput.Size = UDim2.new(1, -72, 0, 34)
    hexInput.Position = UDim2.new(0, 12, 0, 31)
    hexInput.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    hexInput.PlaceholderText = "#B4C0CD"
    hexInput.PlaceholderColor3 = Color3.fromRGB(115, 120, 140)
    hexInput.Text = CustomGlobeHex or ""
    hexInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    hexInput.Font = Enum.Font.GothamBold
    hexInput.TextSize = 14
    hexInput.ClearTextOnFocus = false
    hexInput.Parent = inputCard
    Instance.new("UICorner", hexInput).CornerRadius = UDim.new(0, 8)

    local previewSwatch = Instance.new("Frame")
    previewSwatch.Size = UDim2.new(0, 40, 0, 34)
    previewSwatch.Position = UDim2.new(1, -52, 0, 31)
    previewSwatch.BackgroundColor3 = CustomGlobeColor or Color3.fromRGB(180, 192, 205)
    previewSwatch.BorderSizePixel = 0
    previewSwatch.Parent = inputCard
    Instance.new("UICorner", previewSwatch).CornerRadius = UDim.new(0, 8)

    hexInput:GetPropertyChangedSignal("Text"):Connect(function()
        local col = parseHexColor(hexInput.Text)
        if col then previewSwatch.BackgroundColor3 = col end
    end)

    local applyGlobBtn = Instance.new("TextButton")
    applyGlobBtn.Size = UDim2.new(0.5, -16, 0, 28)
    applyGlobBtn.Position = UDim2.new(0, 12, 0, 71)
    applyGlobBtn.BackgroundColor3 = Color3.fromRGB(65, 115, 240)
    applyGlobBtn.Text = "APLICAR"
    applyGlobBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyGlobBtn.Font = Enum.Font.GothamBlack
    applyGlobBtn.TextSize = 11
    applyGlobBtn.Parent = inputCard
    Instance.new("UICorner", applyGlobBtn).CornerRadius = UDim.new(0, 8)

    local saveGlobBtn = Instance.new("TextButton")
    saveGlobBtn.Size = UDim2.new(0.5, -16, 0, 28)
    saveGlobBtn.Position = UDim2.new(0.5, 4, 0, 71)
    saveGlobBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 46)
    saveGlobBtn.Text = "+ GUARDAR EN LISTA"
    saveGlobBtn.TextColor3 = Color3.fromRGB(220, 225, 245)
    saveGlobBtn.Font = Enum.Font.GothamBlack
    saveGlobBtn.TextSize = 11
    saveGlobBtn.Parent = inputCard
    Instance.new("UICorner", saveGlobBtn).CornerRadius = UDim.new(0, 8)

    local activeCard = Instance.new("Frame")
    activeCard.Size = UDim2.new(1, -6, 0, 72)
    activeCard.Position = UDim2.new(0, 3, 0, 116)
    activeCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    activeCard.Parent = colorGlobContainer
    Instance.new("UICorner", activeCard).CornerRadius = UDim.new(0, 12)

    local activeSwatch = Instance.new("Frame")
    activeSwatch.Size = UDim2.new(0, 44, 0, 44)
    activeSwatch.Position = UDim2.new(0, 12, 0.5, -22)
    activeSwatch.BackgroundColor3 = CustomGlobeColor or SHIELD_MID_BLUE
    activeSwatch.BorderSizePixel = 0
    activeSwatch.Parent = activeCard
    Instance.new("UICorner", activeSwatch).CornerRadius = UDim.new(0, 9)

    local activeNameBox = Instance.new("TextBox")
    activeNameBox.Size = UDim2.new(1, -150, 0, 24)
    activeNameBox.Position = UDim2.new(0, 66, 0, 12)
    activeNameBox.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    activeNameBox.Text = CustomGlobeName
    activeNameBox.PlaceholderText = "Renombrar color..."
    activeNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    activeNameBox.Font = Enum.Font.GothamBold
    activeNameBox.TextSize = 12
    activeNameBox.TextXAlignment = Enum.TextXAlignment.Left
    activeNameBox.ClearTextOnFocus = false
    activeNameBox.Parent = activeCard
    Instance.new("UICorner", activeNameBox).CornerRadius = UDim.new(0, 6)
    Instance.new("UIPadding", activeNameBox).PaddingLeft = UDim.new(0, 8)

    local activeHexLbl = Instance.new("TextLabel")
    activeHexLbl.Size = UDim2.new(1, -150, 0, 18)
    activeHexLbl.Position = UDim2.new(0, 68, 0, 41)
    activeHexLbl.BackgroundTransparency = 1
    activeHexLbl.Text = CustomGlobeHex and ("ACTIVO: " .. CustomGlobeHex) or "ACTIVO: DEFAULT SHIELD"
    activeHexLbl.TextColor3 = Color3.fromRGB(165, 175, 200)
    activeHexLbl.Font = Enum.Font.GothamBold
    activeHexLbl.TextSize = 11
    activeHexLbl.TextXAlignment = Enum.TextXAlignment.Left
    activeHexLbl.Parent = activeCard

    local copyActiveBtn = Instance.new("TextButton")
    copyActiveBtn.Size = UDim2.new(0, 68, 0, 28)
    copyActiveBtn.Position = UDim2.new(1, -78, 0.5, -14)
    copyActiveBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
    copyActiveBtn.Text = "COPIAR"
    copyActiveBtn.TextColor3 = Color3.fromRGB(220, 230, 255)
    copyActiveBtn.Font = Enum.Font.GothamBlack
    copyActiveBtn.TextSize = 11
    copyActiveBtn.Parent = activeCard
    Instance.new("UICorner", copyActiveBtn).CornerRadius = UDim.new(0, 8)

    activeNameBox.FocusLost:Connect(function()
        local newName = activeNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if newName == "" then
            newName = CustomGlobeHex or "Color Personalizado"
            activeNameBox.Text = newName
        end
        CustomGlobeName = newName
        saveConfig()
    end)

    copyActiveBtn.MouseButton1Click:Connect(function()
        local toCopy = CustomGlobeHex or "#B4C0CD"
        if copyToClipboard then pcall(copyToClipboard, toCopy) end
        copyActiveBtn.Text = "COPIADO"
        task.delay(1.1, function()
            if copyActiveBtn and copyActiveBtn.Parent then copyActiveBtn.Text = "COPIAR" end
        end)
    end)

    local savedHeader = Instance.new("TextLabel")
    savedHeader.Size = UDim2.new(1, -8, 0, 20)
    savedHeader.Position = UDim2.new(0, 4, 0, 196)
    savedHeader.BackgroundTransparency = 1
    savedHeader.Text = "COLORES GUARDADOS"
    savedHeader.TextColor3 = Color3.fromRGB(155, 165, 190)
    savedHeader.Font = Enum.Font.GothamBlack
    savedHeader.TextSize = 11
    savedHeader.TextXAlignment = Enum.TextXAlignment.Left
    savedHeader.Parent = colorGlobContainer

    local savedScroll = Instance.new("ScrollingFrame")
    savedScroll.Size = UDim2.new(1, -6, 1, -222)
    savedScroll.Position = UDim2.new(0, 3, 0, 218)
    savedScroll.BackgroundTransparency = 1
    savedScroll.ScrollBarThickness = 4
    savedScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
    savedScroll.Parent = colorGlobContainer

    local savedListLayout = Instance.new("UIListLayout", savedScroll)
    savedListLayout.Padding = UDim.new(0, 8)
    savedListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    RunService.RenderStepped:Connect(function()
        if savedScroll and savedScroll.Parent then
            savedScroll.CanvasSize = UDim2.new(0, 0, 0, savedListLayout.AbsoluteContentSize.Y + 10)
        end
    end)

    local function applyCustomGlobeColor(col, normHex, customName)
        CustomGlobeColor = col
        CustomGlobeHex = normHex
        if customName and customName ~= "" then
            CustomGlobeName = customName
        elseif not CustomGlobeName or CustomGlobeName == "" then
            CustomGlobeName = normHex
        end

        previewSwatch.BackgroundColor3 = col
        activeSwatch.BackgroundColor3 = col
        activeHexLbl.Text = "ACTIVO: " .. normHex
        activeNameBox.Text = CustomGlobeName
        hexInput.Text = normHex

        refreshAllBillboardInnerColors()
        saveConfig()
    end

    local function rebuildSavedColorsList()
        for _, child in ipairs(savedScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        for idx, entry in ipairs(SavedGlobeColors) do
            local col, normHex = parseHexColor(entry.hex)
            if col and normHex then
                local item = Instance.new("Frame")
                item.Size = UDim2.new(1, -8, 0, 56)
                item.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
                item.LayoutOrder = idx
                item.Parent = savedScroll
                Instance.new("UICorner", item).CornerRadius = UDim.new(0, 10)

                local sw = Instance.new("Frame")
                sw.Size = UDim2.new(0, 34, 0, 34)
                sw.Position = UDim2.new(0, 10, 0.5, -17)
                sw.BackgroundColor3 = col
                sw.BorderSizePixel = 0
                sw.Parent = item
                Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 7)

                local renameBox = Instance.new("TextBox")
                renameBox.Size = UDim2.new(1, -186, 0, 22)
                renameBox.Position = UDim2.new(0, 52, 0, 7)
                renameBox.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
                renameBox.Text = entry.name or normHex
                renameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                renameBox.Font = Enum.Font.GothamBold
                renameBox.TextSize = 11
                renameBox.TextXAlignment = Enum.TextXAlignment.Left
                renameBox.ClearTextOnFocus = false
                renameBox.Parent = item
                Instance.new("UICorner", renameBox).CornerRadius = UDim.new(0, 6)
                Instance.new("UIPadding", renameBox).PaddingLeft = UDim.new(0, 6)

                renameBox.FocusLost:Connect(function()
                    local txt = renameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
                    if txt == "" then txt = normHex end
                    renameBox.Text = txt
                    SavedGlobeColors[idx].name = txt
                    if CustomGlobeHex == normHex then
                        CustomGlobeName = txt
                        activeNameBox.Text = txt
                    end
                    saveConfig()
                end)

                local hexTag = Instance.new("TextLabel")
                hexTag.Size = UDim2.new(1, -186, 0, 16)
                hexTag.Position = UDim2.new(0, 54, 0, 33)
                hexTag.BackgroundTransparency = 1
                hexTag.Text = normHex
                hexTag.TextColor3 = Color3.fromRGB(150, 160, 185)
                hexTag.Font = Enum.Font.GothamBold
                hexTag.TextSize = 10
                hexTag.TextXAlignment = Enum.TextXAlignment.Left
                hexTag.Parent = item

                local useBtn = Instance.new("TextButton")
                useBtn.Size = UDim2.new(0, 54, 0, 26)
                useBtn.Position = UDim2.new(1, -126, 0.5, -13)
                useBtn.BackgroundColor3 = Color3.fromRGB(65, 115, 240)
                useBtn.Text = "APLICAR"
                useBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                useBtn.Font = Enum.Font.GothamBlack
                useBtn.TextSize = 9
                useBtn.Parent = item
                Instance.new("UICorner", useBtn).CornerRadius = UDim.new(0, 6)
                useBtn.MouseButton1Click:Connect(function()
                    applyCustomGlobeColor(col, normHex, SavedGlobeColors[idx].name)
                end)

                local cpBtn = Instance.new("TextButton")
                cpBtn.Size = UDim2.new(0, 42, 0, 26)
                cpBtn.Position = UDim2.new(1, -68, 0.5, -13)
                cpBtn.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
                cpBtn.Text = "COPIAR"
                cpBtn.TextColor3 = Color3.fromRGB(215, 225, 255)
                cpBtn.Font = Enum.Font.GothamBlack
                cpBtn.TextSize = 9
                cpBtn.Parent = item
                Instance.new("UICorner", cpBtn).CornerRadius = UDim.new(0, 6)
                cpBtn.MouseButton1Click:Connect(function()
                    if copyToClipboard then pcall(copyToClipboard, normHex) end
                    cpBtn.Text = "OK"
                    task.delay(1.0, function() if cpBtn and cpBtn.Parent then cpBtn.Text = "COPIAR" end end)
                end)

                local delBtn = Instance.new("TextButton")
                delBtn.Size = UDim2.new(0, 18, 0, 26)
                delBtn.Position = UDim2.new(1, -22, 0.5, -13)
                delBtn.BackgroundColor3 = Color3.fromRGB(55, 28, 35)
                delBtn.Text = "×"
                delBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
                delBtn.Font = Enum.Font.GothamBold
                delBtn.TextSize = 13
                delBtn.Parent = item
                Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 6)
                delBtn.MouseButton1Click:Connect(function()
                    table.remove(SavedGlobeColors, idx)
                    saveConfig()
                    rebuildSavedColorsList()
                end)
            end
        end
    end

    applyGlobBtn.MouseButton1Click:Connect(function()
        local raw = (hexInput.Text ~= "" and hexInput.Text) or "#B4C0CD"
        local col, normHex = parseHexColor(raw)
        if col and normHex then
            local currentName = activeNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if currentName == "" or currentName == "Color Personalizado" then currentName = normHex end
            applyCustomGlobeColor(col, normHex, currentName)
            applyGlobBtn.Text = "APLICADO"
            task.delay(1.0, function() if applyGlobBtn and applyGlobBtn.Parent then applyGlobBtn.Text = "APLICAR" end end)
        else
            applyGlobBtn.Text = "HEX INVÁLIDO"
            task.delay(1.1, function() if applyGlobBtn and applyGlobBtn.Parent then applyGlobBtn.Text = "APLICAR" end end)
        end
    end)

    saveGlobBtn.MouseButton1Click:Connect(function()
        local raw = (hexInput.Text ~= "" and hexInput.Text) or CustomGlobeHex or "#B4C0CD"
        local col, normHex = parseHexColor(raw)
        if col and normHex then
            local nameToSave = activeNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if nameToSave == "" or nameToSave == "Color Personalizado" then nameToSave = normHex end
            table.insert(SavedGlobeColors, 1, {hex = normHex, name = nameToSave})
            saveConfig()
            rebuildSavedColorsList()
            saveGlobBtn.Text = "GUARDADO"
            task.delay(1.0, function() if saveGlobBtn and saveGlobBtn.Parent then saveGlobBtn.Text = "+ GUARDAR EN LISTA" end end)
        end
    end)

    rebuildSavedColorsList()
end

selectTab("SPIDER-MAN")

-- ==========================================
-- PRE-DESCARGA SILENCIOSA EN SEGUNDO PLANO
-- ==========================================
task.spawn(function()
    local done = {}
    for _, v in pairs(TRACKED) do
        if v.type == "url" and not done[v.src] then
            done[v.src] = true
            getAudioSource(v.src, v.key .. "_1", "url")
        end
        if v.nextSrc and not done[v.nextSrc] then
            done[v.nextSrc] = true
            getAudioSource(v.nextSrc, v.key .. "_2", "url")
        end
    end
    for _, v in pairs(SOUND_TRACKED) do
        if v.type == "url" and not done[v.src] then
            done[v.src] = true
            getAudioSource(v.src, v.key .. "_1", "url")
        end
        if v.extraUrl and not done[v.extraUrl] then
            done[v.extraUrl] = true
            getAudioSource(v.extraUrl, v.key .. "_extra", "url")
        end
    end
    if not done[DEATH_VOICELINE.src] then
        done[DEATH_VOICELINE.src] = true
        getAudioSource(DEATH_VOICELINE.src, DEATH_VOICELINE.key .. "_1", "url")
    end
    for _, d in ipairs(EXTRA_ANIM_DATA) do
        for idx, file in ipairs(d.files) do
            if not tonumber(file) and not done[file] then
                done[file] = true
                getAudioSource(file, "extra_" .. d.id .. "_" .. idx, "url")
            end
        end
    end
end)

-- ==========================================
-- RASTREADORES DE ANIMACIONES, SONIDOS Y MUERTE
-- ==========================================
local cooldowns = {}
local lastDeathTime = 0

local function onSoundDetected(soundObj)
    if not VoicelinesActivas or not soundObj or not soundObj:IsA("Sound") then return end
    if soundObj:GetAttribute("IsCustomVoice") then return end

    local id = string.match(tostring(soundObj.SoundId), "%d+")
    if not id or not SOUND_TRACKED[id] then return end

    local char = player.Character
    if not char or not isSpiderManDefault(char) then return end

    if not soundObj:IsDescendantOf(char) and not soundObj:IsDescendantOf(player) then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local parentPart = soundObj.Parent
        if parentPart and parentPart:IsA("BasePart") and hrp then
            if (parentPart.Position - hrp.Position).Magnitude > 25 then
                return
            end
        else
            return
        end
    end

    local data = SOUND_TRACKED[id]
    if data.replaceSoundId == id then
        pcall(function()
            soundObj.Volume = 0
            soundObj:Stop()
        end)
    end

    local now = tick()
    if cooldowns[data.key] and (now - cooldowns[data.key] < data.cd) then return end
    cooldowns[data.key] = now

    playSpiderManSound(data, false, char)
end

Workspace.DescendantAdded:Connect(onSoundDetected)
SoundService.DescendantAdded:Connect(onSoundDetected)
if player:FindFirstChild("PlayerGui") then
    player.PlayerGui.DescendantAdded:Connect(onSoundDetected)
end

local function monitorCharacter(char)
    if not char then return end
    local isLocal = (char == player.Character)

    char.DescendantAdded:Connect(function(desc)
        if isLocal and desc:IsA("Sound") then onSoundDetected(desc) end
    end)

    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end

        if isLocal then
            hum.Died:Connect(function()
                if not VoicelinesActivas then return end
                if not isSpiderManDefault(char) then return end
                local now = tick()
                if now - lastDeathTime < 3 then return end
                lastDeathTime = now
                playSpiderManSound(DEATH_VOICELINE, false, char)
            end)
        end

        local animator = hum:WaitForChild("Animator", 10)
        if not animator then return end

        animator.AnimationPlayed:Connect(function(track)
            if not VoicelinesActivas then return end
            local animObj = track.Animation
            if not animObj then return end

            local idStr = string.match(tostring(animObj.AnimationId), "%d+")
            if not idStr then return end
            local idNum = tonumber(idStr)

            -- 1. Cancelar canción de Spider-Man
            if isLocal and idStr == STOP_SONG_ANIM then
                if activeSong then stopActiveSong(true) end
                return
            end

            -- 2. Voicelines de Spider-Man (solo Default)
            if isLocal and TRACKED[idStr] then
                if isSpiderManDefault(char) then
                    local data = TRACKED[idStr]
                    local now = tick()
                    if not cooldowns[data.key] or (now - cooldowns[data.key] >= data.cd) then
                        cooldowns[data.key] = now
                        playSpiderManSound(data, false, char)
                    end
                end
                return
            end

            -- 3. Voicelines de los demás personajes (Jean Grey, Wanda, Wanda Zombie, Carrie, Eleven, Atom)
            if idNum and EXTRA_ANIM_BY_ID[idNum] then
                playExtraVoiceline(EXTRA_ANIM_BY_ID[idNum], char, track)
            end
        end)
    end)
end

-- Detección global de animaciones de todos los personajes
local monitoredChars = setmetatable({}, {__mode = "k"})
local function tryMonitorChar(char)
    if not char or monitoredChars[char] then return end
    if char:FindFirstChildOfClass("Humanoid") then
        monitoredChars[char] = true
        monitorCharacter(char)
    end
end

if player.Character then tryMonitorChar(player.Character) end
player.CharacterAdded:Connect(function(char)
    task.wait(0.15)
    tryMonitorChar(char)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr.Character then tryMonitorChar(plr.Character) end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.15)
        tryMonitorChar(char)
    end)
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.15)
        tryMonitorChar(char)
    end)
end)

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then
        tryMonitorChar(obj.Parent)
    end
end)

-- ==========================================
-- ==========================================
-- DETECTOR DE WANDA ZOMBIE POR PELO (71292732643155)
-- FIX: antes sonaba al aparecer / al cargar el pelo en cualquier parte.
-- Ahora SOLO suena 1 vez cuando ESE personaje muere, y SOLO si es Queen.
-- ==========================================
local zombieDeathArmed = setmetatable({}, {__mode = "k"}) -- [char] = true, se borra al respawnear (nuevo char = nueva vida)
local zombieDeathFired = setmetatable({}, {__mode = "k"}) -- [char] = true, 1 vez por vida

local function hasWandaZombieHair(char)
    if not char or not char:IsA("Model") then return false end
    for _, d in ipairs(char:GetDescendants()) do
        if (d:IsA("SpecialMesh") or d:IsA("MeshPart")) and tostring(d.MeshId):find(TARGET_HAIR) then
            return true
        elseif d:IsA("Accessory") and d.Name:find(TARGET_HAIR) then
            return true
        end
    end
    return false
end

local function armZombieDeath(char)
    if not char or not char:IsA("Model") then return end
    if zombieDeathArmed[char] then return end
    if not hasWandaZombieHair(char) then return end
    -- Solo armar si es Queen en este momento; si el morph cambia despues,
    -- en el momento de morir se vuelve a verificar isQueenOfTheDeadMorph.
    -- Si aun no se detecta Queen aqui, no armar todavia: el DescendantAdded
    -- del pelo / un reintento al morir lo cubre. Para no perder el caso en
    -- que Queen ya estaba puesta, armar solo si es Queen.
    if not isQueenOfTheDeadMorph(char) then return end
    zombieDeathArmed[char] = true
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.Died:Connect(function()
        if not VoicelinesActivas then return end
        if SoloMisVoces and char ~= player.Character then return end
        if zombieDeathFired[char] then return end
        -- Re-verificar Queen JUSTO al morir: si ya no es Queen, no suena.
        if not isQueenOfTheDeadMorph(char) then return end
        if not hasWandaZombieHair(char) then return end
        zombieDeathFired[char] = true
        local zombieData = EXTRA_ANIM_BY_ID[99999999999999]
        if zombieData then
            playExtraVoiceline(zombieData, char, nil, 1)
        end
    end)
end

-- Personajes que ya estan en el juego al ejecutar el script
for _, m in ipairs(Workspace:GetDescendants()) do
    if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
        task.spawn(function()
            task.wait(0.3)
            armZombieDeath(m)
        end)
    end
end

-- Cuando aparece un personaje nuevo (respawn / morph / entra otro jugador)
Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then
        local char = obj.Parent
        task.spawn(function()
            task.wait(0.3)
            armZombieDeath(char)
        end)
    end
end)

-- Cuando aparece el pelo (morph a Queen / cambio de skin): solo ARMAR,
-- nunca reproducir aqui. El sonido solo sale en hum.Died.
Workspace.DescendantAdded:Connect(function(obj)
    if (obj:IsA("SpecialMesh") or obj:IsA("MeshPart")) and tostring(obj.MeshId):find(TARGET_HAIR) then
        local char = obj:FindFirstAncestorOfClass("Model")
        if char then
            task.spawn(function()
                task.wait(0.15)
                armZombieDeath(char)
            end)
        end
    end
end)

-- Respaldo: si el pelo / Queen se detectan tarde, reintentar armar cada
-- que un personaje muere ya esta cubierto por Died, pero si el Humanoid
-- aun no existia al armar, este chequeo lo vuelve a intentar al spawnear.
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        armZombieDeath(char)
    end)
end)

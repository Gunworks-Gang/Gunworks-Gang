-- Registers the "GunworksReloadHand" ModelAttachment on the player body models so a reload prop
-- attached to the RELOAD_HAND_ATTACH_LOCATION slot actually FOLLOWS the right hand.
--
-- Why this is needed: an attached item only tracks a bone if the CHARACTER (parent) model defines a
-- ModelAttachment of that name. At render time the engine looks the prop's parent attachment up by
-- name on the body's ModelScript (AnimatedModel.transformToParent -> getAttachmentById ->
-- ModelScript.attachmentById); finding none it renders the prop at the model root (the feet). The
-- stock human models ship attach points for the two weapon-prop sockets (Bip01_Prop1 primary /
-- Bip01_Prop2 secondary) but NONE on the raw hand bones, and both of those sockets are already taken
-- (Bip01_Prop1 by the primary weapon model, Bip01_Prop2 by the off-hand ramrod), so a right-hand
-- reload prop needs its own attachment. We add one, bound to Bip01_R_Hand, that the
-- RELOAD_HAND_ATTACH_LOCATION slot targets (see AttachLocations.lua).
--
-- CRITICAL MP DETAIL: this registration must succeed on EVERY client, not just the reloader. The
-- attachment lives on the shared body ModelScript, and getAttachmentById reads it live, so once a
-- client has run this the prop resolves on that client's copy of ANY player -- including an observer's
-- copy of a remote reloader. The earlier bug was that registering only on OnGameBoot/OnGameStart could
-- miss on a joining MP client whose body ModelScript was not loaded yet at that instant: the observer
-- then had no "GunworksReloadHand" attachment and rendered the reloader's cartridge at the feet, while
-- the reloader (registered fine) saw it in-hand. Fix: a bounded per-tick retry that keeps trying until
-- both body ModelScripts confirm the attachment, then stops -- so the timing of model loading no longer
-- matters. Idempotent (skips if present) and client-only (a headless server has no body model to
-- render onto, and this file lives under lua/client so it never loads there).
--
-- SURGICAL + SAFE: we only ever touch the two body ModelScripts (FemaleBody / MaleBody), and only add
-- a BRAND-NEW id ("GunworksReloadHand") that no item model references -- so it cannot disturb existing
-- item rendering.

local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

local HAND_ATTACH_ID = ReloadAnim.RELOAD_HAND_ATTACH_LOCATION  -- "GunworksReloadHand"
local HAND_BONE      = "Bip01_R_Hand"

-- Palm offset / rotation of the held prop relative to Bip01_R_Hand. (0,0,0)/(0,0,0) sits the prop at
-- the wrist pivot, which reads well for the musket cartridge/ball. These are applied ONCE, when the
-- attachment is first created, so a value tuned live in the AttachmentEditor is never clobbered by a
-- later re-registration. To move the prop for all players, change these constants (every client bakes
-- them in at creation) -- offset units are model-space and small (~0.05 is a visible nudge).
local OFFSET = { x = 0.0, y = 0.0, z = 0.0 }
local ROTATE = { x = 0.0, y = 0.0, z = 0.0 }

local BODY_MODELS = { "FemaleBody", "MaleBody" }

local RETRY_LIMIT = 600  -- ~10s at 60fps; a backstop so a genuinely absent model never spins forever

--- Ensure the attachment exists on one body ModelScript. Returns true if it is present afterwards
--- (already there, or freshly added), false if the ModelScript is not available yet (retry later).
---@param modelName string
---@return boolean
local function ensureOne(modelName)
    local sm = getScriptManager()
    if not sm then return false end
    local ms = sm:getModelScript(modelName)
    if not ms then return false end
    if ms:getAttachmentById(HAND_ATTACH_ID) then
        return true  -- present already: do NOT re-apply the offset (would clobber an editor-tuned value)
    end

    local att = ModelAttachment.new(HAND_ATTACH_ID)
    if not att then return false end
    att:setBone(HAND_BONE)
    att:getOffset():set(OFFSET.x, OFFSET.y, OFFSET.z)  -- Vector3f, mutate in place -- creation default only
    att:getRotate():set(ROTATE.x, ROTATE.y, ROTATE.z)
    ms:addAttachment(att)
    return ms:getAttachmentById(HAND_ATTACH_ID) ~= nil
end

--- Try to register on every body model. Returns true only when ALL of them have it.
---@return boolean
local function ensureAll()
    local allPresent = true
    for i = 1, #BODY_MODELS do
        local present = false
        local ok = pcall(function() present = ensureOne(BODY_MODELS[i]) end)  -- isolate a per-model failure
        if not ok then
            present = false
        end
        if not present then
            allPresent = false
        end
    end
    return allPresent
end

local retrying = false
local retryTicks = 0

local function retryTick()
    retryTicks = retryTicks + 1
    -- Stop once every body model has it, or after the backstop so a genuinely absent model never spins.
    if ensureAll() or retryTicks >= RETRY_LIMIT then
        Events.OnTick.Remove(retryTick)
        retrying = false
    end
end

--- Register now if the models are ready; otherwise start a bounded per-tick retry until they are.
local function startEnsure()
    if ensureAll() then
        return
    end
    if not retrying then
        retrying = true
        retryTicks = 0
        Events.OnTick.Add(retryTick)
    end
end

Events.OnGameBoot.Add(startEnsure)
Events.OnGameStart.Add(startEnsure)  -- re-covers ResetLua / MP join, which OnGameBoot does not re-fire
startEnsure()                        -- also run at (re)load time so a reloadLuaFile re-applies it live

return ReloadAnim

# Gunworks Gang API Docs

# Ammunition System

This system lets you register weapons and magazines that can use more than one ammo type.
You can also register stat profiles that change how the weapon performs with each ammo type.

Typical setup:

1. Register restore stats if any ammo profile changes weapon stats.
2. Register weapons or magazines with an ammo family.
3. Register the ammo entries that belong to that family.
4. Register any ammo stat profiles used by those entries.

### Module imports

```lua
local Ammo = require("WeaponSystems/Utils/Ammo")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
```

You only need `StatsFactory` if you want ammo profiles to change weapon stats.

### 1. Restore stat registration

Use this if one or more ammo profiles change weapon stats.
The listed stats are reset to the weapon's base values before the active ammo profile is applied again.
This stops stat changes from stacking forever.

```lua
Ammo.RegisterRestoreStats(statNames)
```

Parameters:

- `statNames`: array of stat names, such as `{ "MaxDamage", "MinDamage", "CriticalChance" }`.

Example:

```lua
Ammo.RegisterRestoreStats({
	"MaxDamage",
	"MinDamage",
	"CritDmgMultiplier",
	"ConditionLowerChanceOneIn",
})
```

### 2. Item to family registration

Use this to assign one or more weapon or magazine item types to an ammo family.

```lua
Ammo.RegisterItemWithFamily(family, itemTypes)
Ammo.RegisterMultipleItemsWithFamilies(entriesTable)
```

Parameters:

- `family`: shared family name, such as `"5.56x45mm"`.
- `itemTypes`: either one full item type or an array of full item types.
- `entriesTable`: table in the form `{ [familyName] = itemTypes }`.

Examples:

```lua
Ammo.RegisterItemWithFamily("5.56x45mm", {
	"MyMod.AR15",
	"MyMod.AR15Mag30",
	"MyMod.AR15Mag60",
})
```

```lua
Ammo.RegisterMultipleItemsWithFamilies({
	["5.56x45mm"] = {
		"MyMod.AR15",
		"MyMod.AR15Mag30",
	},
	["7.62x51mm"] = {
		"MyMod.M14",
		"MyMod.M14Mag20",
	},
})
```

### 3. Ammo family registration

Use this to declare which ammo item types belong to a family.

```lua
Ammo.RegisterAmmoFamily(family, bullets)
Ammo.RegisterMultipleAmmoFamilies(entriesTable)
```

Parameters:

- `family`: shared family name.
- `bullets`: array of ammo entry tables.
- `entriesTable`: table in the form `{ [familyName] = bullets }`.

Each ammo entry uses this shape:

```lua
{
	type = "Full.ItemType",
	enum = SomeAmmoEnumValue,
	profile = "OptionalProfileName",
}
```

Fields:

- `type`: full item type of the ammo item.
- `enum`: ammo enum value used when this ammo type is selected. Use only the enum value. If you pass the wrong thing here, setting `ammoType` will not work.
- `profile`: optional ammo stat profile name registered through `Ammo.RegisterAmmoStats`, used to apply custom stats to this ammo type.

Example:

```lua
Ammo.RegisterAmmoFamily("5.56x45mm", {
	{ type = "Base.556Bullets", enum = AmmoType.BULLETS_556, profile = "556x45mmBaseAmmo" },
	{ type = "MyMod.223Bullets", enum = MyMod_AmmoTypes.BULLETS_223, profile = "556x45mmCivilianAmmo" },
})
```

If the family already exists, `Ammo.RegisterAmmoFamily` adds the new entries to it.

### 4. Ammo stat profile registration

Use this to define the stat changes referenced by a `profile` field.

```lua
Ammo.RegisterAmmoStats(profileName, modifiers)
Ammo.RegisterMultipleAmmoStats(entriesTable)
```

Parameters:

- `profileName`: unique profile name.
- `modifiers`: array of modifier functions, usually made with `StatsFactory.Adjust`, `StatsFactory.Set`, or `StatsFactory.Multiply`.
- `entriesTable`: table in the form `{ [profileName] = modifiers }`.

Example:

```lua
Ammo.RegisterAmmoStats("556x45mmCivilianAmmo", {
	StatsFactory.Multiply("MaxDamage", 0.7),
	StatsFactory.Multiply("MinDamage", 0.7),
	StatsFactory.Multiply("CritDmgMultiplier", 0.80),
	StatsFactory.Multiply("ConditionLowerChanceOneIn", 1.50),
})
```

```lua
Ammo.RegisterMultipleAmmoStats({
	["556x45mmBaseAmmo"] = {
		-- Ammo that uses the weapon's base stats does not need a profile.
		-- This empty one is here only for organization.
	},
	["556x45mmArmorPiercingAmmo"] = {
		StatsFactory.Multiply("MaxDamage", 0.85),
		StatsFactory.Multiply("MinDamage", 0.85),
		StatsFactory.Set("PiercingBullets", true),
		StatsFactory.Set("MaxHitCount", 5),
	},
})
```

If you register the same profile name again, the new one replaces the old one.

### Complete example

```lua
local Ammo = require("WeaponSystems/Utils/Ammo")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

Ammo.RegisterRestoreStats({
	"MaxDamage",
	"MinDamage",
	"CritDmgMultiplier",
	"ConditionLowerChanceOneIn",
})

Ammo.RegisterItemWithFamily("5.56x45mm", {
	"MyMod.AR15",
	"MyMod.AR15Mag30",
	"MyMod.AR15Mag60",
})

Ammo.RegisterAmmoFamily("5.56x45mm", {
	{ type = "Base.556Bullets", enum = AmmoType.BULLETS_556, profile = "556x45mmBaseAmmo" },
	{ type = "MyMod.223Bullets", enum = MyMod_AmmoTypes.BULLETS_223, profile = "556x45mmCivilianAmmo" },
})

Ammo.RegisterMultipleAmmoStats({
	["556x45mmBaseAmmo"] = {
		-- no modifiers, use base stats
	},
	["556x45mmCivilianAmmo"] = {
		StatsFactory.Multiply("MaxDamage", 0.7),
		StatsFactory.Multiply("MinDamage", 0.7),
		StatsFactory.Multiply("CritDmgMultiplier", 0.80),
		StatsFactory.Multiply("ConditionLowerChanceOneIn", 1.50),
	},
})
```

# Animations System

This system lets you animate parts of a weapon to simulate cycling and racking.
You can do this with attached parts or with model swaps.

Typical setup:

1. Register animated parts for weapons that swap attachments or models between open and locked states.
2. Register custom ammo-count states for weapons that need extra visual stages, for example an LMG belt.

### Module import

```lua
local Animations = require("WeaponSystems/Utils/Animations")
```

### 1. Animated parts registration

Use this to register a weapon that changes attachments or models while firing, racking, or cycling.

```lua
Animations.RegisterWeaponWithAnimatedParts(fullType, entry)
Animations.RegisterMultipleWeaponsWithAnimatedParts(entriesTable)
```

Parameters:

- `fullType`: full item type of the weapon, such as `"MyMod.AR15"`.
- `entry`: table that describes the two visual states. Use either `attachments` or `models`.
- `entriesTable`: table in the form `{ [fullType] = entry }`.

Optional field:

- `cycleTicks`: how long, in ticks (60 ticks = 1 second), the action stays racked open before it auto-closes. Defaults to `Animations.DEFAULT_CYCLE_TICKS` (`10`, i.e. 10/60 seconds) when omitted.

```lua
{
	attachments = {
		open = "MyMod.Slide_Open",
		locked = "MyMod.Slide_Locked",
	},
	cycleTicks = 15, -- optional, defaults to 10 (10/60s)
}
```

Attachment shape:

```lua
{
	attachments = {
		open = "MyMod.Slide_Open",
		locked = "MyMod.Slide_Locked",
	}
}
```

Model shape:

```lua
{
	models = {
		open = "MyWeapon_Open",
		locked = "MyWeapon_Locked",
	}
}
```

Fields:

- `open`: visual state used while the action is open.
- `locked`: visual state used while the action is closed or locked.

Examples:

```lua
local Slide = {
	attachments = {
		open = "MyMod.Slide_Fired",
		locked = "MyMod.Slide_Lock",
	}
}

Animations.RegisterWeaponWithAnimatedParts("MyMod.M92FS", Slide)
Animations.RegisterWeaponWithAnimatedParts("MyMod.USP", Slide)
```

```lua
Animations.RegisterWeaponWithAnimatedParts("MyMod.TestWeapon", {
	models = {
		open = "TestWeapon_Open",
		locked = "TestWeapon_Locked",
	}
})
```

```lua
Animations.RegisterMultipleWeaponsWithAnimatedParts({
	["MyMod.USP"] = = {
		attachments = {
			open = "MyMod.Slide_Fired",
			locked = "MyMod.Slide_Lock",
		}
	},
	["MyMod.AR15"] = {
		attachments = {
			open = "MyMod.Bolt_Fired",
			locked = "MyMod.Bolt_Lock",
		}
	},
})
```

IMPORTANT
For racking to work, your animset needs the `rackStart` and `rackEnd` events.
If you extend a base animset, add them to the correct racking node.
Example:

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode x_extends="loadRifle_HB.xml">
	<m_Name>RackRifle</m_Name>
	<m_AnimName>Bob_Reload_Bolt_Rack</m_AnimName>
	<m_BlendTime>0.10</m_BlendTime>
	<m_ConditionPriority>10</m_ConditionPriority>
	<m_Conditions />
	<m_Conditions />
	<m_Conditions>
		<m_Name>isRacking</m_Name>
	</m_Conditions>
	<m_Events>
		<m_EventName>rackingFinished</m_EventName>
	</m_Events>
	<m_Events>
		<m_Time>Start</m_Time>
		<m_ParameterValue>rack</m_ParameterValue>
	</m_Events>
	<m_Events>
		<m_EventName>rackBullet</m_EventName>
		<m_ParameterValue></m_ParameterValue>
	</m_Events>
	<m_Events>
		<m_EventName>ejectCasing</m_EventName>
		<m_TimePc>0.46</m_TimePc>
	</m_Events>
	<m_Events>
		<m_EventName>rackStart</m_EventName>  ------------- Opens during the rack
		<m_TimePc>0.49</m_TimePc>
	</m_Events>
	<m_Events>
		<m_EventName>rackEnd</m_EventName>  ---------------- Closes it again
		<m_TimePc>0.68</m_TimePc>
	</m_Events>
</animNode>
```

### 2. Custom state registration

Use this to register extra visual stages for a weapon based on its current ammo count.

```lua
Animations.RegisterWeaponsWithCustomStates(fullType, paramsTable)
```

Parameters:

- `fullType`: full item type of the weapon.
- `paramsTable`: array of stage entries.

Each stage entry uses this shape:

```lua
{
	threshold = 1,
	part = "MyMod.Bullet_1",
	slot = "Animated1",
}
```

Fields:

- `threshold`: minimum ammo count needed for that state to be shown.
- `part`: weapon part item type to attach when the threshold is met.
- `slot`: attachment slot used to remove or replace that state.

Example:

```lua
Animations.RegisterWeaponsWithCustomStates("MyMod.M60", {
	{ threshold = 1, part = "MyMod.Bullet_1", slot = "Animated1" },
	{ threshold = 2, part = "MyMod.Bullet_2", slot = "Animated2" },
	{ threshold = 3, part = "MyMod.Bullet_3", slot = "Animated3" },
})
```

### Complete example

```lua
local Animations = require("WeaponSystems/Utils/Animations")

local Bolt = {
	attachments = {
		open = "MyMod.Bolt_Fired",
		locked = "MyMod.Bolt_Lock",
	}
}

Animations.RegisterWeaponWithAnimatedParts("MyMod.AR15", Bolt)
Animations.RegisterWeaponWithAnimatedParts("MyMod.M14", Bolt)

Animations.RegisterWeaponsWithCustomStates("MyMod.M60", {
	{ threshold = 1, part = "MyMod.Bullet_1", slot = "Animated1" },
	{ threshold = 2, part = "MyMod.Bullet_2", slot = "Animated2" },
	{ threshold = 3, part = "MyMod.Bullet_3", slot = "Animated3" },
})
```

# Bayonet System

The bayonet system supports two kinds of bayonets:

1. Attachable bayonets, where a knife item can be mounted on a weapon.
2. Integrated bayonets, where the weapon already has a built-in bayonet.

This section only covers the registry functions.

Typical setup for attachable bayonets:

1. Register which weapons can accept a bayonet attachment.
2. Register the knife item, the attachment item, and the spear-style weapon used for melee.
3. Optionally register exclusives if some parts should block the bayonet, for example a suppressor.

Typical setup for integrated bayonets:

1. Register the weapon.
2. Set the spear-style weapon used for melee.
3. Choose either attachment swaps or model swaps for folded and deployed states.

### Module import

```lua
local Bayonet = require("WeaponSystems/Utils/Bayonet")
```

### 1. Mountable weapon registration

Use this to tell the system which weapons can use which bayonet attachments.

```lua
Bayonet.RegisterMountableWeapon(bayonetType, weaponTypes)
```

Parameters:

- `bayonetType`: one bayonet attachment type or an array of attachment types.
- `weaponTypes`: one full weapon type or an array of full weapon types.

Examples:

```lua
Bayonet.RegisterMountableWeapon("MyMod.M9_Bayonet_Attachment", {
	"MyMod.M16A2",
	"MyMod.M16A3",
	"MyMod.M14",
})
```

```lua
Bayonet.RegisterMountableWeapon({
	"MyMod.K98_Bayonet_Attachment",
	"MyMod.M5_Bayonet_Attachment",
	"MyMod.M9_Bayonet_Attachment",
}, {
	"MyMod.M16A2",
	"MyMod.M14",
	"MyMod.MOSIN",
})
```

### 2. Bayonet knife registration

Use this to link the knife item, the bayonet attachment, and the spear-style weapon used for bayonet melee attacks.

```lua
Bayonet.RegisterBayonetKnife(knifeType, bayonetType, spearType)
```

Parameters:

- `knifeType`: full item type of the knife, for example a hunting knife.
- `bayonetType`: full item type of the bayonet attachment.
- `spearType`: full item type of the spear-style weapon used as the melee reference.

Example:

```lua
Bayonet.RegisterBayonetKnife("MyMod.M9_BAYONET", "MyMod.M9_Bayonet_Attachment", "Base.SpearHuntingKnife")
```

### 3. Exclusive parts registration

Use this if some parts should stop a bayonet from being mounted. A common use is blocking bayonets when a muzzle device is installed.

```lua
Bayonet.SetExclusives(bayonetType, itemB)
```

Parameters:

- `bayonetType`: one bayonet attachment type or an array of attachment types.
- `itemB`: one blocking part type or an array of blocking part types.

Example:

```lua
Bayonet.SetExclusives({
	"MyMod.K98_Bayonet_Attachment",
	"MyMod.M5_Bayonet_Attachment",
	"MyMod.M9_Bayonet_Attachment",
}, {
	"MyMod.Suppressor",
	"MyMod.MuzzleBrake",
	"MyMod.GrenadeLauncher",
})
```

### 4. Integrated bayonet registration

Use this to register a weapon that already has a built-in bayonet.

```lua
Bayonet.RegisterIntegratedBayonet(weaponType, entry)
```

Parameters:

- `weaponType`: one weapon full type or an array of weapon full types.
- `entry`: either a full entry table or a simple spear-style weapon type string.

Simple form:

```lua
Bayonet.RegisterIntegratedBayonet("MyMod.Type56", "Base.SpearHuntingKnife")
```

Full entry shape:

```lua
{
	weaponRef = "Base.SpearHuntingKnife",
	initialState = "folded",
	attachments = {
		partType = "BayonetIntegrated",
		deployed = "MyMod.SKS_Bayonet_Deployed",
		folded = "MyMod.SKS_Bayonet_Folded",
	}
}
```

Fields:

- `weaponRef`: the spear-style weapon used for melee.
- `initialState`: optional. Use `"folded"` or `"deployed"`. If not set, the default is `"folded"`.
- `attachments`: use this if the weapon changes attached parts.
- `models`: use this if the weapon swaps full weapon models instead.

Use either `models` or `attachments`, not both.

If you use the full entry, choose one visual mode:

Attachment mode:

```lua
attachments = {
	partType = "BayonetIntegrated",
	deployed = "MyMod.SKS_Bayonet_Deployed",
	folded = "MyMod.SKS_Bayonet_Folded",
}
```

Model mode:

```lua
models = {
	deployed = "MyWeapon_Bayonet_Deployed",
	folded = "MyWeapon_Bayonet_Folded",
}
```

Examples:

```lua
Bayonet.RegisterIntegratedBayonet("MyMod.SKS", {
	weaponRef = "Base.SpearHuntingKnife",
	attachments = {
		partType = "BayonetIntegrated",
		deployed = "MyMod.SKS_Bayonet_Deployed",
		folded = "MyMod.SKS_Bayonet_Folded",
	}
})
```

```lua
Bayonet.RegisterIntegratedBayonet("MyMod.Type56", "Base.SpearHuntingKnife")
```

### Complete example

```lua
local Bayonet = require("WeaponSystems/Utils/Bayonet")

Bayonet.RegisterMountableWeapon({
	"MyMod.K98_Bayonet_Attachment",
	"MyMod.M5_Bayonet_Attachment",
	"MyMod.M9_Bayonet_Attachment",
}, {
	"MyMod.M16A2",
	"MyMod.M16A3",
	"MyMod.M14",
	"MyMod.MOSIN",
})

Bayonet.RegisterBayonetKnife("MyMod.K98_BAYONET", "MyMod.K98_Bayonet_Attachment", "Base.SpearHuntingKnife")
Bayonet.RegisterBayonetKnife("MyMod.M5_BAYONET", "MyMod.M5_Bayonet_Attachment", "Base.SpearHuntingKnife")
Bayonet.RegisterBayonetKnife("MyMod.M9_BAYONET", "MyMod.M9_Bayonet_Attachment", "Base.SpearHuntingKnife")

Bayonet.SetExclusives({
	"MyMod.K98_Bayonet_Attachment",
	"MyMod.M5_Bayonet_Attachment",
	"MyMod.M9_Bayonet_Attachment",
}, {
	"MyMod.Suppressor",
	"MyMod.MuzzleBrake",
	"MyMod.GrenadeLauncher",
})

Bayonet.RegisterIntegratedBayonet("MyMod.SKS", {
	weaponRef = "Base.SpearHuntingKnife",
	attachments = {
		partType = "BayonetIntegrated",
		deployed = "MyMod.SKS_Bayonet_Deployed",
		folded = "MyMod.SKS_Bayonet_Folded",
	}
})
```

# Custom Stats Attachment System

This system lets weapon parts change weapon stats while attached.
If a weapon has more than one registered part attached, all of their modifiers are combined and applied together.

Typical setup:

1. Register restore stats for any weapon stats your attachment modifiers will change.
2. Register one part with `RegisterPart`, or register many parts with `RegisterMultipleParts`.
3. Use `StatsFactory` to define the stat changes for each part.

### Module imports

```lua
local CustomStatsAttachments = require("WeaponSystems/Utils/CustomStatsAttachments")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
```

You need `StatsFactory` because each part entry uses modifier functions from that module.

### 1. Restore stat registration

Use this if any registered part changes weapon stats.
The listed stats are reset to the weapon's base values before the part modifiers are applied again.
This stops stat changes from stacking forever.

```lua
CustomStatsAttachments.RegisterRestoreStats(statNames)
```

Parameters:

- `statNames`: array of stat names, such as `{ "SoundRadius", "SoundVolume", "RecoilDelay" }`.

Example:

```lua
CustomStatsAttachments.RegisterRestoreStats({
	"SoundRadius",
	"SoundVolume",
	"RecoilDelay",
})
```

### 2. Single attachment registration

Use this to register one weapon part and the stat changes it gives while attached.

```lua
CustomStatsAttachments.RegisterPart(partFullType, modifiers)
```

Parameters:

- `partFullType`: full item type of the weapon part, such as `"MyMod.Suppressor_556"`.
- `modifiers`: array of modifier functions, usually made with `StatsFactory.Adjust`, `StatsFactory.Set`, or `StatsFactory.Multiply`.

Example:

```lua
CustomStatsAttachments.RegisterPart("MyMod.Suppressor_556", {
	StatsFactory.Multiply("SoundRadius", 0.55),
	StatsFactory.Multiply("SoundVolume", 0.65),
	StatsFactory.Adjust("RecoilDelay", 2),
})
```

If you register the same part again, the new entry replaces the old one.

### 3. Multiple attachment registration

Use this to register many weapon parts in one call.

```lua
CustomStatsAttachments.RegisterMultipleParts(partsTable)
```

Parameters:

- `partsTable`: table in the form `{ [partFullType] = modifiers }`.

Example:

```lua
CustomStatsAttachments.RegisterMultipleParts({
	["MyMod.Suppressor_556"] = {
		StatsFactory.Multiply("SoundRadius", 0.55),
		StatsFactory.Multiply("SoundVolume", 0.65),
	},
	["MyMod.MatchTrigger"] = {
		StatsFactory.Adjust("HitChance", 5),
		StatsFactory.Adjust("AimingTime", -4),
	},
})
```

Each registered part on the weapon adds its own modifiers.
If more than one registered part is attached, all of them are combined.

### Complete example

```lua
local CustomStatsAttachments = require("WeaponSystems/Utils/CustomStatsAttachments")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

CustomStatsAttachments.RegisterRestoreStats({
	"SoundRadius",
	"SoundVolume",
	"RecoilDelay",
	"HitChance",
	"AimingTime",
})

CustomStatsAttachments.RegisterMultipleParts({
	["MyMod.Suppressor_556"] = {
		StatsFactory.Multiply("SoundRadius", 0.55),
		StatsFactory.Multiply("SoundVolume", 0.65),
		StatsFactory.Adjust("RecoilDelay", 2),
	},
	["MyMod.MatchTrigger"] = {
		StatsFactory.Adjust("HitChance", 5),
		StatsFactory.Adjust("AimingTime", -4),
	},
})
```

# Dynamic Attachments System

This system lets one installed attachment swap into another attachment.
A common use is a part with two states, such as a folded bipod and a deployed bipod.

Typical setup:

1. Register the two attachment item types as a pair.
2. Check whether the weapon has a swappable attachment installed.
3. Call the swap helper when the player toggles that attachment.

### Module import

```lua
local DynamicAttachment = require("WeaponSystems/Utils/DynamicAttachment")
```

For most content mods, `RegisterPair` is the only setup function you need.
The other functions are runtime helpers.

### 1. Pair registration

Use this to register two attachment item types that should swap into each other.

```lua
DynamicAttachment.RegisterPair(attachmentA, attachmentB)
```

Parameters:

- `attachmentA`: full item type of the first attachment, such as `"MyMod.Bipod_Deployed"`.
- `attachmentB`: full item type of the second attachment, such as `"MyMod.Bipod_Folded"`.

Example:

```lua
DynamicAttachment.RegisterPair("MyMod.Bipod_Deployed", "MyMod.Bipod_Folded")
```

Registering a pair adds both directions automatically.
That means the system can swap from `attachmentA` to `attachmentB`, and from `attachmentB` back to `attachmentA`.

# Folding Bipod System

This system lets you register weapons with a foldable bipod.
It can change weapon stats and visuals between folded and deployed states.

Typical setup:

1. Register restore stats if the bipod changes weapon stats.
2. Register one weapon or many weapons with a bipod entry.
3. Choose one visual mode: attachment swaps or model swaps.
4. Optionally add folded and deployed stat modifiers (Recommended and needed if you use whole models instead of attachments, with attachments you can delegate the Custom Stats Attachment system to the attachment options, or use this.).

### Module imports

```lua
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
```

You only need `StatsFactory` if the bipod changes weapon stats.

### 1. Restore stat registration

Use this if the folded or deployed bipod state changes weapon stats.
The listed stats are reset to the weapon's base values before the active bipod state is applied again.
This stops stat changes from stacking forever.

```lua
FoldingBipod.RegisterRestoreStats(statNames)
```

Parameters:

- `statNames`: array of stat names, such as `{ "RecoilDelay", "MinAngle", "MaxAngle" }`.

Example:

```lua
FoldingBipod.RegisterRestoreStats({
	"RecoilDelay",
	"MinAngle",
	"MaxAngle",
})
```

### 2. Single weapon registration

Use this to register one weapon with a foldable bipod.

```lua
FoldingBipod.RegisterWeapon(weaponType, entry)
```

Parameters:

- `weaponType`: full item type of the weapon, such as `"MyMod.M249"`.
- `entry`: bipod config table for that weapon.

Entry shape:

```lua
{
	modifiers = {
		folded = {
			StatsFactory.Adjust("RecoilDelay", 2),
		},
		deployed = {
			StatsFactory.Adjust("RecoilDelay", -6),
		},
	},
	initialState = "folded",
	attachments = {
		partType = "Bipod",
		folded = "MyMod.Bipod_Folded",
		deployed = "MyMod.Bipod_Deployed",
	}
}
```

Fields:

- `modifiers`: optional table of stat modifier arrays for the `folded` and `deployed` states. Each state is optional.
- `initialState`: optional. Use `"folded"` or `"deployed"`. If not set, the default is `"folded"`.
- `attachments`: use this if the bipod swaps attached parts.
- `models`: use this if the bipod swaps weapon visuals instead.

If you use `attachments`, the shape is:

```lua
attachments = {
	partType = "Bipod",
	folded = "MyMod.Bipod_Folded",
	deployed = "MyMod.Bipod_Deployed",
}
```

Fields:

- `partType`: attachment slot name used by the bipod part.
- `folded`: full item type of the folded bipod attachment.
- `deployed`: full item type of the deployed bipod attachment.

If you use `models`, the shape is:

```lua
models = {
	folded = "MyWeapon_Bipod_Folded",
	deployed = "MyWeapon_Bipod_Deployed",
}
```

Use either `attachments` or `models`, not both.

Example:

```lua
FoldingBipod.RegisterWeapon("MyMod.M249", {
	modifiers = {
		deployed = {
			StatsFactory.Adjust("RecoilDelay", -6),
			StatsFactory.Adjust("MinAngle", -0.2),
			StatsFactory.Adjust("MaxAngle", -0.4),
		},
	},
	attachments = {
		partType = "Bipod",
		folded = "MyMod.Bipod_Folded",
		deployed = "MyMod.Bipod_Deployed",
	}
})
```

If you register the same weapon again, the new entry replaces the old one.

### 3. Multiple weapon registration

Use this to register many weapons in one call.

```lua
FoldingBipod.RegisterMultipleWeapons(entriesTable)
```

Parameters:

- `entriesTable`: table in the form `{ [weaponType] = entry }`.

Example:

```lua
FoldingBipod.RegisterMultipleWeapons({
	["MyMod.M249"] = {
		attachments = {
			partType = "Bipod",
			folded = "MyMod.Bipod_Folded",
			deployed = "MyMod.Bipod_Deployed",
		}
	},
	["MyMod.M60"] = {
		models = {
			folded = "M60_Bipod_Folded",
			deployed = "M60_Bipod_Deployed",
		}
	},
})
```

### Complete example

```lua
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

FoldingBipod.RegisterRestoreStats({
	"RecoilDelay",
	"MinAngle",
	"MaxAngle",
})

FoldingBipod.RegisterMultipleWeapons({
	["MyMod.M249"] = {
		modifiers = {
			deployed = {
				StatsFactory.Adjust("RecoilDelay", -6),
				StatsFactory.Adjust("MinAngle", -0.2),
				StatsFactory.Adjust("MaxAngle", -0.4),
			},
		},
		attachments = {
			partType = "Bipod",
			folded = "MyMod.Bipod_Folded",
			deployed = "MyMod.Bipod_Deployed",
		},
	},
	["MyMod.M60"] = {
		initialState = "deployed",
		models = {
			folded = "M60_Bipod_Folded",
			deployed = "M60_Bipod_Deployed",
		},
	},
})
```

# Folding Stock System

This follows the same idea as Folding Bipod, but for folding stocks.
It can change weapon stats and visuals between folded and deployed states.

Typical setup:

1. Register restore stats if the stock changes weapon stats.
2. Register one weapon or many weapons with a stock entry.
3. Choose one visual mode: attachment swaps or model swaps.

### Module imports

```lua
local FoldingStock = require("WeaponSystems/Utils/FoldingStock")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
```

You only need `StatsFactory` if the stock changes weapon stats.

### 1. Restore stat registration

```lua
FoldingStock.RegisterRestoreStats(statNames)
```

Use this if the folded or deployed stock state changes weapon stats.

### 2. Single weapon registration

```lua
FoldingStock.RegisterWeapon(weaponType, entry)
```

Parameters:

- `weaponType`: full item type of the weapon, such as `"MyMod.AKS74U"`.
- `entry`: stock config table for that weapon.

Entry shape:

```lua
{
	modifiers = {
		folded = {
			StatsFactory.Adjust("MinRangeRanged", -2),
		},
		deployed = {
			StatsFactory.Adjust("MinRangeRanged", 0),
		},
	},
	initialState = "deployed",
	attachments = {
		partType = "Stock",
		folded = "MyMod.Stock_Folded",
		deployed = "MyMod.Stock_Deployed",
	}
}
```

Fields:

- `modifiers`: optional table of stat modifier arrays for the `folded` and `deployed` states.
- `initialState`: optional. Use `"folded"` or `"deployed"`. If not set, the default is `"folded"`.
- `attachments`: use this if the stock swaps attached parts.
- `models`: use this if the stock swaps weapon visuals instead.

Use either `attachments` or `models`, not both.

Example:

```lua
FoldingStock.RegisterWeapon("MyMod.AKS74U", {
	modifiers = {
		folded = {
			StatsFactory.Adjust("MinRangeRanged", -2),
			StatsFactory.Adjust("HitChance", -5),
		},
	},
	attachments = {
		partType = "Stock",
		folded = "MyMod.Stock_Folded",
		deployed = "MyMod.Stock_Deployed",
	}
})
```

### 3. Multiple weapon registration

```lua
FoldingStock.RegisterMultipleWeapons(entriesTable)
```

Use this to register many weapons in one call.

Example:

```lua
FoldingStock.RegisterMultipleWeapons({
	["MyMod.AKS74U"] = {
		attachments = {
			partType = "Stock",
			folded = "MyMod.Stock_Folded",
			deployed = "MyMod.Stock_Deployed",
		}
	},
	["MyMod.FAL_Para"] = {
		models = {
			folded = "FAL_Para_Folded",
			deployed = "FAL_Para_Deployed",
		}
	},
})
```

# Magazine Systems

This system lets you assign weapons to magazine profiles and define which magazines belong to each profile.

Typical setup:

1. Register one weapon or many weapons with a magazine profile.
2. Register the ordered magazine list for that profile.
3. If the weapon uses visible magazines, add the reload anim event note below.

### Module import

```lua
local Magazine = require("WeaponSystems/Utils/Magazine")
```

### 1. Weapon to profile registration

Use this to assign one or more weapons to a magazine profile.

```lua
Magazine.RegisterWeaponWithProfile(profileName, weaponTypes)
Magazine.RegisterMultipleWeaponsWithProfiles(entriesTable)
```

Parameters:

- `profileName`: shared profile name, such as `"AR15_Magazines"`.
- `weaponTypes`: one full weapon type or an array of full weapon types.
- `entriesTable`: table in the form `{ [profileName] = weaponTypes }`.

Examples:

```lua
Magazine.RegisterWeaponWithProfile("AR15_Magazines", {
	"MyMod.AR15",
	"MyMod.M4A1",
})
```

```lua
Magazine.RegisterMultipleWeaponsWithProfiles({
	["AR15_Magazines"] = {
		"MyMod.AR15",
		"MyMod.M4A1",
	},
	["FAL_Magazines"] = {
		"MyMod.FAL",
	},
})
```

### 2. Magazine profile registration

Use this to define which magazines belong to a profile.

```lua
Magazine.RegisterMagazineProfile(profileName, magazineTypes)
Magazine.RegisterMultipleMagazineProfiles(entriesTable)
```

Parameters:

- `profileName`: shared profile name.
- `magazineTypes`: ordered array of full magazine item types.
- `entriesTable`: table in the form `{ [profileName] = magazineTypes }`.

The list is ordered, so keep your preferred magazine types in the order you want to use them.

Examples:

```lua
Magazine.RegisterMagazineProfile("AR15_Magazines", {
	"MyMod.STANAG30",
	"MyMod.STANAG20",
	"MyMod.STANAG60",
})
```

```lua
Magazine.RegisterMultipleMagazineProfiles({
	["AR15_Magazines"] = {
		"MyMod.STANAG30",
		"MyMod.STANAG20",
		"MyMod.STANAG60",
	},
	["FAL_Magazines"] = {
		"MyMod.FAL20",
		"MyMod.FAL30",
	},
})
```

### Complete example

```lua
local Magazine = require("WeaponSystems/Utils/Magazine")

Magazine.RegisterMultipleWeaponsWithProfiles({
	["AR15_Magazines"] = {
		"MyMod.AR15",
		"MyMod.M4A1",
	},
	["FAL_Magazines"] = {
		"MyMod.FAL",
	},
})

Magazine.RegisterMultipleMagazineProfiles({
	["AR15_Magazines"] = {
		"MyMod.STANAG30",
		"MyMod.STANAG20",
		"MyMod.STANAG60",
	},
	["FAL_Magazines"] = {
		"MyMod.FAL20",
		"MyMod.FAL30",
	},
})
```

### Visual magazine note

Visible magazine syncing does not need a separate registry function.
If your weapon uses a visible detachable magazine, add the `InsertMag` anim event to the reload anim when the hand reaches the magazine well.
The weapon model should use the `Clip` part slot for the magazine visual.

# Prevent Removal System

This lets you mark weapon parts as permanent.
Registered parts will not appear in the vanilla `Remove Weapon Upgrade` submenu.

### Module import

```lua
local PreventRemoval = require("WeaponSystems/Utils/PreventRemovals")
```

### Registration

Use this to register one part or many parts as non-removable.

```lua
PreventRemoval.Register(parts)
```

Parameters:

- `parts`: one full part type or an array of full part types.

Examples:

```lua
PreventRemoval.Register("MyMod.WeldedRail")
```

```lua
PreventRemoval.Register({
	"MyMod.WeldedRail",
	"MyMod.FixedFrontSight",
	"MyMod.IntegratedStock",
})
```

### Complete example

```lua
local PreventRemoval = require("WeaponSystems/Utils/PreventRemovals")

PreventRemoval.Register({
	"MyMod.WeldedRail",
	"MyMod.FixedFrontSight",
	"MyMod.IntegratedStock",
})
```

# Railing System

This system lets you register rails and define which accessories each rail can accept.
You can also block specific accessories on specific weapons and set exclusives.

Typical setup:

1. Register the rail and the accessory list it accepts.
2. Optionally block some accessories on specific weapons.
3. Optionally set exclusives for parts that cannot be used together.

### Module import

```lua
local Railing = require("WeaponSystems/Utils/Railing")
```

### 1. Rail registration

Use this to register one rail or many rails with the accessory list they accept.

```lua
Railing.RegisterRailing(railingType, accessories)
```

Parameters:

- `railingType`: one full rail part type or an array of full rail part types.
- `accessories`: array of full accessory part types.

Examples:

```lua
Railing.RegisterRailing("MyMod.PICATINNY_RAIL", {
	"Base.RedDot",
	"Base.2xScope",
	"Base.Laser",
})
```

```lua
Railing.RegisterRailing({
	"MyMod.PICATINNY_RAIL",
	"MyMod.AK_SIDE_MOUNT",
}, {
	"Base.RedDot",
	"Base.2xScope",
	"Base.Laser",
})
```

### 2. Weapon exclusions

Use this when a shared rail can accept an accessory in general, but a specific weapon should block it.

```lua
Railing.RegisterWeaponExclusions(weaponType, accessories)
```

Parameters:

- `weaponType`: one full weapon type or an array of full weapon types.
- `accessories`: one full accessory part type or an array of full accessory part types.

Example:

```lua
Railing.RegisterWeaponExclusions({
	"MyMod.AA12",
	"MyMod.AA13",
}, {
	"Base.8xScope",
	"Base.Laser",
})
```

### 3. Exclusives registration

Use this when one item should block one or more other items, even if they use different part slots.

```lua
Railing.SetExclusives(itemA, itemB)
```

Parameters:

- `itemA`: one full part type or an array of full part types.
- `itemB`: one full part type or an array of full part types.

Example:

````lua
Railing.SetExclusives({
	"MyMod.BIPOD_DEPLOYED",
	"MyMod.BIPOD_FOLDED",
}, {
	"MyMod.GRIP_VERTICAL",
	"MyMod.GRIP_ANGLED",
})

### Complete example

```lua
local Railing = require("WeaponSystems/Utils/Railing")

Railing.RegisterRailing({
	"MyMod.PICATINNY_RAIL",
	"MyMod.AK_SIDE_MOUNT",
}, {
	"Base.RedDot",
	"Base.2xScope",
	"Base.Laser",
	"Base.8xScope",
})

Railing.RegisterWeaponExclusions("MyMod.AA12", {
	"Base.8xScope",
})

Railing.SetExclusives({
	"MyMod.BIPOD_DEPLOYED",
	"MyMod.BIPOD_FOLDED",
}, {
	"MyMod.GRIP_VERTICAL",
	"MyMod.GRIP_ANGLED",
})
````

# Rate Of Fire System

This system lets you register custom RPM, burst count, and optional spread settings for weapons.
You can also register spread multipliers for weapon parts and ammo.

Typical setup:

1. Register one weapon or many weapons with a rate-of-fire profile.
2. Optionally register spread modifiers for parts.
3. Optionally register spread modifiers for ammo.

### Module import

```lua
local RateOfFire = require("WeaponSystems/Utils/RateOfFire")
```

### 1. Weapon profile registration

Use this to register RPM, burst count, and optional spread settings for a weapon.

```lua
RateOfFire.RegisterWeapon(weaponType, entry)
RateOfFire.RegisterMultipleWeaponsWithSameProfile(weaponTypes, entry)
RateOfFire.RegisterMultipleWeapons(entriesTable)
```

Parameters:

- `weaponType`: full item type of the weapon.
- `weaponTypes`: array of full weapon types.
- `entry`: weapon profile table.
- `entriesTable`: table in the form `{ [weaponType] = entry }`.

Entry shape:

```lua
{
	rpm = 750,
	burstCount = 3,
	enableSpread = true,
	initialSpread = 0.0,
	sustainedSpread = 0.12,
	maxSpread = 2.5,
}
```

Fields:

- `rpm`: optional. If not set, the default is `600`.
- `burstCount`: optional. If not set, the default is `3`.
- `enableSpread`: optional. Set this to `true` to enable the spread system for this weapon.
- `initialSpread`: optional starting spread value.
- `sustainedSpread`: optional spread added during sustained fire.
- `maxSpread`: optional spread cap.

If spread is enabled and you do not set spread values, the defaults are `0.0`, `0.1`, and `3`.

Examples:

```lua
RateOfFire.RegisterWeapon("MyMod.M16A3", {
	rpm = 800,
	burstCount = 3,
	enableSpread = true,
	initialSpread = 0.0,
	sustainedSpread = 0.10,
	maxSpread = 2.0,
})
```

```lua
RateOfFire.RegisterMultipleWeaponsWithSameProfile({
	"MyMod.M4A1",
	"MyMod.C7A2",
}, {
	rpm = 750,
	burstCount = 3,
	enableSpread = true,
	initialSpread = 0.0,
	sustainedSpread = 0.12,
	maxSpread = 2.4,
})
```

```lua
RateOfFire.RegisterMultipleWeapons({
	["MyMod.AKM"] = {
		rpm = 600,
		enableSpread = true,
		sustainedSpread = 0.14,
		maxSpread = 2.8,
	},
	["MyMod.MP5"] = {
		rpm = 800,
		burstCount = 3,
		enableSpread = true,
		sustainedSpread = 0.09,
		maxSpread = 1.8,
	},
})
```

If you register the same weapon again, the new entry replaces the old one.

### 2. Spread part modifier registration

Use this to change sustained spread and max spread when a weapon part is installed.

```lua
RateOfFire.RegisterSpreadPartModifier(partType, entry)
RateOfFire.RegisterMultipleSpreadPartModifier(modifiersTable)
```

Parameters:

- `partType`: full item type of the weapon part.
- `entry`: modifier table.
- `modifiersTable`: table in the form `{ [partType] = entry }`.

Entry shape:

```lua
{
	sustainedSpreadMult = 0.85,
	maxSpreadMult = 0.90,
}
```

These multipliers affect `sustainedSpread` and `maxSpread` only.
They do not change `initialSpread`.

Example:

```lua
RateOfFire.RegisterSpreadPartModifier("MyMod.ForegripVert", {
	sustainedSpreadMult = 0.85,
	maxSpreadMult = 0.90,
})
```

### 3. Spread ammo modifier registration

Use this to change sustained spread and max spread for a specific ammo type.

```lua
RateOfFire.RegisterSpreadAmmoModifier(ammoType, entry)
RateOfFire.RegisterMultipleSpreadAmmoModifier(modifiersTable)
```

Parameters:

- `ammoType`: full item type of the ammo.
- `entry`: modifier table.
- `modifiersTable`: table in the form `{ [ammoType] = entry }`.

Example:

```lua
RateOfFire.RegisterSpreadAmmoModifier("MyMod.556x45Tracer", {
	sustainedSpreadMult = 1.10,
	maxSpreadMult = 1.05,
})
```

### Complete example

```lua
local RateOfFire = require("WeaponSystems/Utils/RateOfFire")

RateOfFire.RegisterMultipleWeapons({
	["MyMod.M16A3"] = {
		rpm = 800,
		burstCount = 3,
		enableSpread = true,
		initialSpread = 0.0,
		sustainedSpread = 0.10,
		maxSpread = 2.0,
	},
	["MyMod.MP5"] = {
		rpm = 800,
		burstCount = 3,
		enableSpread = true,
		sustainedSpread = 0.09,
		maxSpread = 1.8,
	},
})

RateOfFire.RegisterMultipleSpreadPartModifier({
	["MyMod.ForegripVert"] = {
		sustainedSpreadMult = 0.85,
		maxSpreadMult = 0.90,
	},
})

RateOfFire.RegisterMultipleSpreadAmmoModifier({
	["MyMod.556x45Tracer"] = {
		sustainedSpreadMult = 1.10,
		maxSpreadMult = 1.05,
	},
})
```

# Stats Factory - Short Explanation

`StatsFactory` is the helper module used by other systems when you want to change weapon stats.
Most of the time, you only need three modifier helpers.

```lua
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
```

### 1. Set

Use `Set` when you want the stat to become one exact value.

```lua
StatsFactory.Set("PiercingBullets", true)
StatsFactory.Set("MaxHitCount", 5)
```

- `StatsFactory.Set("PiercingBullets", true)` means the weapon will use `true` for that stat.
- `StatsFactory.Set("MaxHitCount", 5)` means the weapon will use `5` for that stat.

### 2. Multiply

Use `Multiply` when you want to scale the current stat up or down.

```lua
StatsFactory.Multiply("MaxDamage", 0.85)
StatsFactory.Multiply("SoundRadius", 1.20)
```

- `0.85` means the stat becomes 85% of its current value.
- `1.20` means the stat becomes 120% of its current value.

### 3. Add

Use `StatsFactory.Adjust` when you want to add or subtract from the current stat.

```lua
StatsFactory.Adjust("HitChance", 5)
StatsFactory.Adjust("AimingTime", -4)
```

- `5` adds 5 to the current stat.
- `-4` subtracts 4 from the current stat.

Quick rule:

- `Set` replaces the value.
- `Multiply` scales the value.
- `Adjust` adds or subtracts from the value.

You usually place these inside systems like ammo, attachments, bipods, or stocks when those systems ask for a `modifiers` table.
Feel free to extend this system in a custom module. Contact me directly if I miss a getter/setter that you wish to see in the main table.

# SpeedLoader System

This system lets direct-load firearms use one or more compatible speedloaders.
You register the weapon and the allowed speedloader item types.
After that, the framework can find a compatible loaded speedloader and transfer rounds into the gun.

Keep it simple:

1. Register one weapon or many weapons with compatible speedloader types.
2. If you register more than one speedloader type for the same gun, keep them in the order you prefer.
3. Let the framework handle the reload flow, or use the helper functions if you need custom logic.

### Module import

```lua
local SpeedLoader = require("WeaponSystems/Utils/SpeedLoader")
```

### 1. Weapon registration

Use this to register one weapon or many weapons with one or more compatible speedloader item types.

```lua
SpeedLoader.RegisterWeapon(weaponTypes, speedLoaderTypes)
```

Parameters:

- `weaponTypes`: one full weapon type or an array of full weapon types.
- `speedLoaderTypes`: one full speedloader type or an array of full speedloader types.

Examples:

```lua
SpeedLoader.RegisterWeapon("MyMod.Python357", "MyMod.SpeedLoader357")
```

```lua
SpeedLoader.RegisterWeapon({
	"MyMod.Redhawk44",
	"MyMod.Anaconda44",
}, {
	"MyMod.SpeedLoader44",
	"MyMod.QuickLoader44",
})
```

If you register the same weapon again, the new speedloader list replaces the old one.

### 2. Multiple weapon registration

Use this to register many weapons in one call.

```lua
SpeedLoader.RegisterMultipleWeapons(entriesTable)
```

Parameters:

- `entriesTable`: table in the form `{ [weaponType] = speedLoaderType|string[] }`.

Example:

```lua
SpeedLoader.RegisterMultipleWeapons({
	["MyMod.Python357"] = "MyMod.SpeedLoader357",
	["MyMod.Redhawk44"] = {
		"MyMod.SpeedLoader44",
		"MyMod.QuickLoader44",
	},
	["MyMod.Anaconda44"] = "MyMod.SpeedLoader44",
})
```

### Complete example

```lua
local SpeedLoader = require("WeaponSystems/Utils/SpeedLoader")

SpeedLoader.RegisterMultipleWeapons({
	["MyMod.Python357"] = "MyMod.SpeedLoader357",
	["MyMod.Redhawk44"] = {
		"MyMod.SpeedLoader44",
		"MyMod.QuickLoader44",
	},
})

local loader = SpeedLoader.GetBestSpeedLoaderForGun(playerObj, gun)
if loader then
	local moved = SpeedLoader.TransferAmmoToGun(gun, loader)
	if moved > 0 then
		print("Loaded rounds: " .. tostring(moved))
	end
end
```

# Underbarrel System

This system lets a weapon switch to an underbarrel weapon, such as a grenade launcher or shotgun.

Pressing the toggle key (`U` by default) **swaps the equipped item entirely**: the weapon in
your hand is removed from the inventory and the registered underbarrel weapon is equipped in
its place. Pressing it again rebuilds the original weapon and re-equips it.

Nothing is simulated on top of the host weapon. When you swap away, the framework takes a
full snapshot of the host and stores it in the swapped-in weapon's modData; when you swap
back, the host is rebuilt from that snapshot. The reverse is also true — the underbarrel
weapon's own state (loaded round, condition) is snapshotted on the host and restored the next
time you deploy it.

What survives a toggle, in both directions:

- condition, condition max, repair count, custom name
- every attached `WeaponPart` (optic, grip, laser, sling, integrated parts…) with its own
  condition and modData
- ammo count, chambered / spent-round state, jam state, magazine + which magazine type, the
  Gunworks mixed-ammo `AmmoList`, fire mode
- the **entire weapon modData table** (minus this system's own keys), so any per-weapon state
  another Gunworks subsystem or another mod stores is carried across for free

The swap is server-authoritative in multiplayer.

> Note: the swapped-in weapon is a **new item each toggle** (new item ID). Do not hold a
> weapon's item ID across a toggle.

### Module import

```lua
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
```

### Registration

```lua
Underbarrel.Register({
    attachment = "MyMod.M203_Attachment",   -- attachment (or integrated) part fullType
    weapon     = "MyMod.M203_Weapon",       -- standalone underbarrel weapon fullType
    model      = "host",                    -- "host" (default) | "self"
})
```

- `attachment`: full item type of the underbarrel attachment part. Its `PartType` must be
  `Underbarrel` (attachment) or `UnderbarrelIntegrated` (built-in / permanent).
- `weapon`: full item type of the standalone underbarrel weapon that gets equipped.
- `model`:
  - `"host"` *(default)* — the swapped-in weapon takes on the host weapon's model/sprite, so
    you still visually hold your rifle. Use this for a true underbarrel launcher.
  - `"self"` — the swapped-in weapon shows its own script model. Use this when the underbarrel
    weapon should look like its own thing.
  - In **both** modes the host's attached parts (optic, grip, laser, sling, integrated
    parts…) are cloned onto the swapped-in weapon. The two modes differ only in the
    sprite / model. Author the underbarrel `weapon` script without a randomising `OnCreate`.

IMPORTANT: for the framework to detect the attachment, the `PartType` on your underbarrel
attachment part must be `Underbarrel` (or `UnderbarrelIntegrated` for a built-in one):

```
item M203_Attachment
    {
        DisplayCategory  = WeaponPart,
        ItemType         = base:weaponpart,
        Icon             = M203,
        Weight           = 0.9,
        WeightModifier   = 0.9,
        MountOn          = MyMod.FakeItemRifles,
        PartType         = Underbarrel,   <------------------- IMPORTANT!
        Tooltip          = Tooltip_Underbarrel_m203,
        WorldStaticModel = MyMod.M203,
        CanAttach        = ItemCodeOnTest.hasScrewdriver,
        CanDetach        = ItemCodeOnTest.hasScrewdriver,
    }
```

The underbarrel `weapon` is an ordinary firearm script item — it uses its own ammo type,
reload type, sounds and (with `model = "self"`) its own model.

### Built-in underbarrels

Put the permanent part in the weapon's `UnderbarrelIntegrated` slot (via the script's
`OnCreate`) and register that part type the same way:

```lua
Underbarrel.Register({ attachment = "MyMod.M203_IntegratedPart", weapon = "MyMod.M203_Weapon" })
```

### Preserving state outside modData

Almost everything a subsystem needs is already in the weapon's modData and is carried across
automatically. If you have state that lives somewhere else (an engine field, a toggled visual
part), register a preserver:

```lua
Underbarrel.RegisterStatePreserver("myFeature", {
    snapshot = function(weapon) return { deployed = weapon:getSomeEngineFlag() } end,
    restore  = function(weapon, data) weapon:setSomeEngineFlag(data.deployed) end,
})
```

### Complete example

```lua
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")

Underbarrel.Register({ attachment = "MyMod.M203_Attachment",     weapon = "MyMod.M203_Weapon" })
Underbarrel.Register({ attachment = "MyMod.Masterkey_Attachment", weapon = "MyMod.Masterkey_Weapon" })
Underbarrel.Register({ attachment = "MyMod.M203_IntegratedPart",  weapon = "MyMod.M203_Weapon" })
```

### Backwards compatibility

The old `Underbarrel.RegisterUnderbarrelAttachment(attachment, weapon, manualRemoval, swapStats)`
still works. It maps to `Register{ attachment, weapon, model = "host" }`; the `manualRemoval`
and `swapStats` arguments are accepted and ignored (the real underbarrel weapon script now
drives spent-round handling, and there are no stats to swap).

The query functions are unchanged: `Underbarrel.IsWeaponInUnderbarrelMode(weapon)`,
`CanToggleUnderbarrel(weapon)`, `CanSwapToUnderbarrel(weapon)`, `IsUsingUnderbarrel(player)`,
`GetModeUnderbarrelType(weapon)`, `ToggleUnderbarrel(weapon, player)`.

# Universal Attachment System

This system lets one generic item install different real weapon parts depending on the weapon.
A common use is a universal rail kit or adapter item.

You register the generic item and the possible outcome parts.
After that, the framework menu handles the install and remove flow.

Typical setup:

1. Register one generic item with its possible outcome parts for a weapon.
2. Or register all generic items for one weapon in one table.
3. Or register many weapons at once.

### Module import

```lua
local UniversalAttachment = require("WeaponSystems/Utils/UniversalAttachment")
```

### 1. Outcome registration

Use this to register one generic item for one weapon.

```lua
UniversalAttachment.RegisterOutcomes(weaponType, genericItemType, outcomes)
```

Parameters:

- `weaponType`: full item type of the weapon.
- `genericItemType`: full item type of the generic item the player uses.
- `outcomes`: array of full item types for the real weapon parts that item can become.

Each outcome should be a real weapon part item for that weapon.

Example:

```lua
UniversalAttachment.RegisterOutcomes("MyMod.AR15", "MyMod.UniversalRailKit", {
	"MyMod.AR15_TopRail",
	"MyMod.AR15_HandguardRail",
})
```

If you register the same generic item again for the same weapon, the new outcome list replaces the old one.

### 2. Single weapon registration

Use this to register all generic items for one weapon in one call.

```lua
UniversalAttachment.RegisterWeapon(weaponType, entries)
```

Parameters:

- `weaponType`: full item type of the weapon.
- `entries`: table in the form `{ [genericItemType] = outcomes }`.

Example:

```lua
UniversalAttachment.RegisterWeapon("MyMod.AR15", {
	["MyMod.UniversalRailKit"] = {
		"MyMod.AR15_TopRail",
		"MyMod.AR15_HandguardRail",
	},
	["MyMod.UniversalMuzzleKit"] = {
		"MyMod.AR15_FlashHider",
		"MyMod.AR15_MuzzleBrake",
	},
})
```

### 3. Multiple weapon registration

Use this to register many weapons at once.

```lua
UniversalAttachment.RegisterWeapons(entriesTable)
```

Parameters:

- `entriesTable`: table in the form `{ [weaponType] = entries }`.

This is the easiest way to register the same generic item across many weapons.

Example:

```lua
UniversalAttachment.RegisterWeapons({
	["MyMod.AR15"] = {
		["MyMod.UniversalRailKit"] = {
			"MyMod.AR15_TopRail",
			"MyMod.AR15_HandguardRail",
		},
	},
	["MyMod.AKM"] = {
		["MyMod.UniversalRailKit"] = {
			"MyMod.AKM_SideRail",
			"MyMod.AKM_HandguardRail",
		},
	},
})
```

### Complete example

```lua
local UniversalAttachment = require("WeaponSystems/Utils/UniversalAttachment")

UniversalAttachment.RegisterWeapons({
	["MyMod.AR15"] = {
		["MyMod.UniversalRailKit"] = {
			"MyMod.AR15_TopRail",
			"MyMod.AR15_HandguardRail",
		},
		["MyMod.UniversalMuzzleKit"] = {
			"MyMod.AR15_FlashHider",
			"MyMod.AR15_MuzzleBrake",
		},
	},
	["MyMod.AKM"] = {
		["MyMod.UniversalRailKit"] = {
			"MyMod.AKM_SideRail",
			"MyMod.AKM_HandguardRail",
		},
	},
})
```

# Upgrade Exclusives System

This system lets you block normal weapon upgrade parts from being installed together.
If one exclusive part is already mounted, the other upgrade option is hidden.

Typical setup:

1. Register one exclusive pair.
2. Or register several exclusive pairs in one table.

### Module import

```lua
local UpgradeExclusives = require("WeaponSystems/Utils/UpgradeExclusives")
```

### 1. Single exclusive registration

Use this to make one part exclusive with one or more other parts.

```lua
UpgradeExclusives.SetExclusives(itemA, itemB)
```

Parameters:

- `itemA`: full item type of the first part.
- `itemB`: one full item type or an array of full item types that should be blocked with `itemA`.

This works both ways automatically.
If `itemA` blocks `itemB`, then `itemB` also blocks `itemA`.

Examples:

```lua
UpgradeExclusives.SetExclusives("Base.Bipod", "Base.Foregrip")
```

```lua
UpgradeExclusives.SetExclusives("Base.Scope", {
	"Base.Sling",
	"Base.Laser",
})
```

### 2. Multiple exclusive registration

Use this to register many exclusives in one call.

```lua
UpgradeExclusives.RegisterMultipleSetOfExclusives(entriesTable)
```

Parameters:

- `entriesTable`: table in the form `{ [itemA] = itemB }`.

Example:

```lua
UpgradeExclusives.RegisterMultipleSetOfExclusives({
	["Base.Bipod"] = "Base.Foregrip",
	["Base.Scope"] = {
		"Base.Sling",
		"Base.Laser",
	},
})
```

### Complete example

```lua
local UpgradeExclusives = require("WeaponSystems/Utils/UpgradeExclusives")

UpgradeExclusives.RegisterMultipleSetOfExclusives({
	["Base.Bipod"] = "Base.Foregrip",
	["Base.Scope"] = {
		"Base.Sling",
		"Base.Laser",
	},
})
```

# Explosives Systems (Experimental WIP)

This system lets you register throwable explosives and explosive ammo as ordnance projectiles.
Unspecified values use the framework defaults.

Keep it simple:

1. Register thrown explosives with `Register`.
2. Register explosive ammo with `RegisterAmmo`.
3. Only pass the fields you want to change.

### Module import

```lua
local OrdnanceFactory = require("ExplosivesSystems/OrdnanceFactory")
```

### 1. Throwable explosive registration

Use this for grenades, thrown bombs, or other thrown ordnance items.

```lua
OrdnanceFactory.Register(fullType, overrides)
```

Parameters:

- `fullType`: full item type of the throwable item. --> this should point to a existing explosive script, example Base.Pipeboms, so it overwrites the vanilla throwing behavior.
- `overrides`: table of optional ordnance settings.

Common override fields:

- `throwForce`: how hard the item is thrown.
- `maxThrowDist`: max throw distance.
- `floorBounces`: how many floor bounces it gets.
- `bounceEnergy`: how much bounce it keeps.
- `detonateOnImpact`: set to `true` for impact detonation.
- `detonationDelay`: fuse time before detonation.
- `explosionPower`: explosion power.
- `explosionRange`: explosion radius.
- `worldModel`: optional projectile model shown in flight.

Example:

```lua
OrdnanceFactory.Register("MyMod.M67", {
	throwForce = 8,
	maxThrowDist = 15,
	floorBounces = 5,
	bounceEnergy = 0.2,
	detonateOnImpact = false,
	detonationDelay = 3,
	explosionPower = 220,
	explosionRange = 5,
})
```

### 2. Explosive ammo registration

Use this for ammo that should spawn an ordnance projectile instead of acting like a normal bullet.

```lua
OrdnanceFactory.RegisterAmmo(bulletFullType, overrides)
```

Parameters:

- `bulletFullType`: full item type of the ammo.
- `overrides`: table of optional ordnance settings.

This is commonly used for rounds like 40mm grenades.

Example:

```lua
OrdnanceFactory.RegisterAmmo("MyMod.40mm_HE", {
	throwSpeed = 25,
	maxThrowDist = 40,
	arcFactor = 0.03,
	detonateOnImpact = true,
	explosionPower = 180,
	explosionRange = 4,
	worldModel = "MyMod.40mm_Projectile",
})
```

### Complete example

```lua
local OrdnanceFactory = require("ExplosivesSystems/OrdnanceFactory")

OrdnanceFactory.Register("MyMod.M67", {
	throwForce = 8,
	maxThrowDist = 15,
	floorBounces = 5,
	bounceEnergy = 0.2,
	detonationDelay = 3,
	explosionPower = 220,
	explosionRange = 5,
})

OrdnanceFactory.RegisterAmmo("MyMod.40mm_HE", {
	throwSpeed = 25,
	maxThrowDist = 40,
	arcFactor = 0.03,
	detonateOnImpact = true,
	explosionPower = 180,
	explosionRange = 4,
	worldModel = "MyMod.40mm_Projectile",
})
```

# Distribution Functions

These helpers let you add, remove, or change items in loot tables.
They work with zombie loot and normal container loot.

They look for an existing item first, then use that item as the reference.
If the reference item is not found, nothing is changed.

### Module import

```lua
local WeaponDistribution = require("Distribution/Functions")
```

### 1. Insert items

Use this when you want a new item to appear anywhere an existing item already appears.

```lua
WeaponDistribution.Insert(baseItem, chance, tables, newItem)
WeaponDistribution.InsertMany(baseItem, chance, tables, ...)
```

Parameters:

- `baseItem`: existing item already present in the loot table.
- `chance`: chance multiplier copied from the base item. `1` means same chance, `0.5` means half, `2` means double.
- `tables`: loot tables to search through.
- `newItem`: full item type to add.
- `...`: extra item types for `InsertMany`.

Example:

```lua
local WeaponDistribution = require("Distribution/Functions")

WeaponDistribution.Insert("Base.Pistol", 0.5, {
	SuburbsDistributions,
	ProceduralDistributions.list,
}, "MyMod.CustomPistol")
```

### 2. Remove items

Use this when you want to delete one item or several items from the tables you pass in.

```lua
WeaponDistribution.RemoveEverywhere(tables, item)
WeaponDistribution.RemoveMany(tables, ...)
```

Parameters:

- `tables`: loot tables to search through.
- `item`: full item type to remove.
- `...`: extra item types for `RemoveMany`.

This removes the item from normal `items` lists and from `weapons` lists.

### 3. Change chance

Use this when the item is already in the loot table and you only want to change its spawn chance.

```lua
WeaponDistribution.SetChance(item, chance, tables)
WeaponDistribution.SetChanceMany(chance, tables, ...)
```

Parameters:

- `item`: full item type to update.
- `chance`: new chance value to write into the loot table.
- `tables`: loot tables to search through.
- `...`: extra item types for `SetChanceMany`.

This only changes entries in normal `items` lists.
It does not change `weapons` lists.

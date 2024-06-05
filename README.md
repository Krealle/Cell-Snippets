# Cell - Snippets

Various snippets I've made for the addon [Cell](https://www.curseforge.com/wow/addons/cell).

> [!IMPORTANT]
> These snippets are not made, nor maintained, by Cell's developer, so please don't ask them about any issues you might be experiencing.

### DebuffAuraAnchor

<details><summary>
Anchors tooltips to their respective Aura, instead of using general tooltip settings.
</summary>

![image](https://github.com/Krealle/Cell-Snippets/assets/3404958/b3b09dc2-9bfa-48a4-92c0-4783bfe8713e)

</details>

### IndicatorTalentOption

<details><summary>
Show or hide Indicators based on talents.
</summary>

![image](https://github.com/Krealle/Cell-Snippets/assets/3404958/2bf3b9e7-472a-43d3-8654-01c67ecd0a4c)

</details>

### PartySortOptions

<details><summary>
Adds more options for player position on party frames. eg. adds the ability to always show yourself first.
</summary>

![image](https://github.com/Krealle/Cell-Snippets/assets/3404958/fd836871-d48d-43b7-a92c-91b024995681)

Note:

- If "Sort By Role" is enabled groups will only be sorted if you are playing DPS
- Sorting will only happen outside of combat.

Todo:

- Figure out a secure way to update in combat.
- Implement a priority list.
- Implement a fixed list.
</details>

### RaidSortOptions

<details><summary>
Adds more sorting options for your raid!
</summary>

**Imporant:** Important information below, make sure read this before using, or asking for help!

**1. Sorting does not work in combat!**

Due to how SecureFrames, (Which Cells raid frames are based on), are handled in combat. Custom sorting only works outside of combat; therefore will any roster changes in combat trigger a delayed update that fires when you exit combat.

**2. Frames update twice on roster changes**

Due to the implementation used, when roster changes happens the frames will be subjected to blizzards base sorting, and then, later, re-sorted by this snippet.

There is one workaround to this that I'll implement soon<sup><small>TM</small></sup>. That involves the usage of a `nameList` filter. This will only trigger updates when a new `nameList` is pushed. This also, to an extend, solves point 1.

The problem with that solution is that due to not being able to interact with the `nameList` during combat. Any new players, who weren't on the list before combat started, will not be added until after leaving combat.

**3. Without `Combine Groups` enabled, only your own subgroup will be sorted.**

**4. With `Combine Groups` enabled, the entire raid will be sorted.**

### Configuration

This snippet provides several options for customizing the way your raid frames will be sorted.

All tables have their first/highest entry as the highest priority.

**All of these options are found at the TOP of the snippet!**

#### Sorting Order

This table dictates the type of sort methods you want to use, and their priority.

Included in this example is all (currently) available sorting methods, feel free to move them around, or remove any unwanted methods.

```
local SORTING_ORDER = {
    "PLAYER",
    "NAME",
    "SPEC",
    "ROLE",
    "SPECROLE"
}
```

#### Name Priority

Choose the order in which to show players, based on their names.

**NOTE:** Currently this only supports `Name` format, so don't try to add `-Realm` suffix.

```
local NAME_PRIORITY = {"Xephyris","Entro"}
```

#### Role Priority

Choose the order in which to show players, based on their roles.

```
local ROLE_PRIORITY = {"HEALER","DAMAGER","TANK"}
```

#### Spec Role Priority

Choose the order in which to show players, based on their spec roles.

**NOTE:** If no spec information can be found for a player, they will be defaulted to their normal role, eg. `RANGED` will show up as `DAMAGER`

```
local SPECROLE_PRIORITY = {"RANGED","MELEE","DAMAGER","HEALER","TANK"}
```

#### Spec Priority

Choose the order in which to show players, based on their specs.

**NOTE:** Spec information is not always available.

```
local SPEC_PRIORITY = {
  -- Specs
}
```

#### Utility options

Set these to `false` to suppress error/info messages during sorting.

```
local showErrorMessages = true
local showInfoMessages = true
```

Whether to sort `Ascending` or `Descending`. Supports `ASC`or `DESC`.

```
local sortDirection = "ASC"
```

How long in seconds to wait before updating raid frames. Should be kept high to prevent oversorting on rapid roster changes. eg. start/end of raid

```
local QUE_TIMER = 1
```

</details>

global function RespawnInit;

bool justGameStart = true;
float shieldTime = 2.0;

struct {
    table <entity, entity> shield
} file

void function RespawnInit() {
    AddCallback_OnPlayerRespawned(RespawnProtect);
    shieldTime = GetConVarFloat("rs_shield_time");
}

void function RespawnProtect(entity player) {
    if (!justGameStart) {
        thread RespawnProtectThread(player);
    } else {
        thread EnableProtectShield();
    }
}

void function EnableProtectShield() {
    wait 5.0;
    justGameStart = false;
}

void function RespawnProtectThread(entity player) {
    #if SERVER
    if (player != null) {
        WaitFrame();
        player.SetInvulnerable();
        entity bubbleShield = CreateEntity("prop_dynamic");
        bubbleShield.SetValueForModelKey($"models/fx/xo_shield.mdl");
        bubbleShield.kv.solid = SOLID_VPHYSICS;
        bubbleShield.kv.rendercolor = "81 130 151";
        bubbleShield.kv.contents = (int(bubbleShield.kv.contents) | CONTENTS_NOGRAPPLE);
        vector angles = player.EyeAngles();
        bubbleShield.SetOrigin(player.GetOrigin());
        bubbleShield.SetAngles(angles);
        bubbleShield.SetBlocksRadiusDamage(true);
        DispatchSpawn(bubbleShield);
        SetTeam(bubbleShield, player.GetTeam());
        array<entity> bubbleShieldFXs;
        int team = player.GetTeam();
        vector coloredFXOrigin = player.GetOrigin();
        table bubbleShieldDotS = expect table(bubbleShield.s);
        if (team == TEAM_UNASSIGNED) {
            entity neutralColoredFX = StartParticleEffectInWorld_ReturnEntity(BUBBLE_SHIELD_FX_PARTICLE_SYSTEM_INDEX, coloredFXOrigin, <0, 0, 0>);
            SetTeam(neutralColoredFX, team);
            bubbleShieldDotS.neutralColoredFX <- neutralColoredFX;
            bubbleShieldFXs.append(neutralColoredFX);
        } else {
            entity friendlyColoredFX = StartParticleEffectInWorld_ReturnEntity(BUBBLE_SHIELD_FX_PARTICLE_SYSTEM_INDEX, coloredFXOrigin, <0, 0, 0>);
            SetTeam(friendlyColoredFX, team);
            friendlyColoredFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY;
            EffectSetControlPointVector(friendlyColoredFX, 1, FRIENDLY_COLOR_FX);
            entity enemyColoredFX = StartParticleEffectInWorld_ReturnEntity(BUBBLE_SHIELD_FX_PARTICLE_SYSTEM_INDEX, coloredFXOrigin, <0, 0, 0>);
            SetTeam(enemyColoredFX, team);
            enemyColoredFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_ENEMY;
            EffectSetControlPointVector(enemyColoredFX, 1, ENEMY_COLOR_FX);
            bubbleShieldDotS.friendlyColoredFX <- friendlyColoredFX;
            bubbleShieldDotS.enemyColoredFX <- enemyColoredFX;
            bubbleShieldFXs.append(friendlyColoredFX);
            bubbleShieldFXs.append(enemyColoredFX);
        }
        file.shield[player] <- bubbleShield;
        EmitSoundOnEntity(bubbleShield, "BubbleShield_Sustain_Loop");
        thread CleanupRespawnProtect(player, bubbleShield, bubbleShieldFXs);
    } else {
        printl("[respawnShield][ERROR] Player is NULL");
    }
    #endif
}

void function CleanupRespawnProtect(entity player, entity bubbleShield, array<entity> bubbleShieldFXs) {
    player.EndSignal("OnDeath");
    player.EndSignal("OnDestroy");
    bubbleShield.EndSignal("OnDestroy");
    OnThreadEnd(
        function(): (player, bubbleShield, bubbleShieldFXs) {
            player.ClearInvulnerable();
            player.SetHealth(player.GetMaxHealth());
            if (IsValid_ThisFrame(bubbleShield)) {
                StopSoundOnEntity(bubbleShield, "BubbleShield_Sustain_Loop");
                EmitSoundOnEntity(bubbleShield, "BubbleShield_End");
                DestroyBubbleShield(bubbleShield);
            }
            foreach(fx in bubbleShieldFXs) {
                if (IsValid_ThisFrame(fx)) {
                    EffectStop(fx);
                }
            }
        }
    )
    wait shieldTime;
}

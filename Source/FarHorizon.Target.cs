using UnrealBuildTool;

public class FarHorizonTarget : TargetRules
{
    public FarHorizonTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V6;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("FarHorizon");
    }
}

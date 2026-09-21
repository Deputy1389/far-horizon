using UnrealBuildTool;

public class FarHorizonEditorTarget : TargetRules
{
    public FarHorizonEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V6;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("FarHorizon");
    }
}

using UnrealBuildTool;

public class FarHorizon : ModuleRules
{
    public FarHorizon(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "InputCore",
            "EnhancedInput",
            "AIModule",
            "NavigationSystem",
            "GameplayAbilities",
            "GameplayTags",
            "GameplayTasks",
            "PhysicsCore",
            "StateTreeModule",
            "GameplayStateTreeModule"
        });
    }
}

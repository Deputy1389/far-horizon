#include "FHFrontierWorld.h"

#include "FHEnemyCharacter.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Components/SkyLightComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "Materials/Material.h"
#include "Materials/MaterialInterface.h"
#include "NavMesh/NavMeshBoundsVolume.h"
#include "NavigationSystem.h"
#include "UObject/SoftObjectPath.h"

AFHFrontierWorld::AFHFrontierWorld()
    : RandomStream(1389)
{
    PrimaryActorTick.bCanEverTick = false;

    SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
    SetRootComponent(SceneRoot);

    CubeMesh = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Cube.Cube"));

    CylinderMesh = LoadObject<UStaticMesh>(
        nullptr,
        TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));

    auto CreateInstances = [this](
        const TCHAR* Name,
        UStaticMesh* Mesh,
        UMaterialInterface* Material)
    {
        UHierarchicalInstancedStaticMeshComponent* Component =
            CreateDefaultSubobject<UHierarchicalInstancedStaticMeshComponent>(Name);

        Component->SetupAttachment(GetRootComponent());
        Component->SetStaticMesh(Mesh);
        Component->SetMobility(EComponentMobility::Movable);
        Component->SetCollisionProfileName(TEXT("BlockAll"));
        Component->SetCanEverAffectNavigation(true);
        Component->SetCastShadow(true);

        if (Material)
        {
            Component->SetMaterial(0, Material);
        }

        return Component;
    };

    UMaterialInterface* Sand = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Sand.M_SWG_Sand"));
    UMaterialInterface* Road = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Road.M_SWG_Road"));
    UMaterialInterface* Wall = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Wall.M_SWG_Wall"));
    UMaterialInterface* CapitalWall = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_CapitalWall.M_SWG_CapitalWall"));
    UMaterialInterface* Concrete = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Concrete.M_SWG_Concrete"));
    UMaterialInterface* Metal = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Metal.M_SWG_Metal"));
    UMaterialInterface* Pad = LoadLocalMaterial(
        TEXT("/Game/FarHorizon/LocalSWG/Materials/M_SWG_Pad.M_SWG_Pad"));

    SandInstances = CreateInstances(TEXT("Sand"), CubeMesh, Sand);
    RoadInstances = CreateInstances(TEXT("Roads"), CubeMesh, Road);
    WallInstances = CreateInstances(TEXT("Walls"), CubeMesh, Wall);
    CapitalWallInstances = CreateInstances(TEXT("CapitalWalls"), CubeMesh, CapitalWall);
    ConcreteInstances = CreateInstances(TEXT("Concrete"), CubeMesh, Concrete);
    MetalInstances = CreateInstances(TEXT("Metal"), CubeMesh, Metal);
    LandingPadInstances = CreateInstances(TEXT("LandingPads"), CylinderMesh, Pad);
    AntennaInstances = CreateInstances(TEXT("Antennas"), CylinderMesh, Metal);
}

UMaterialInterface* AFHFrontierWorld::LoadLocalMaterial(
    const TCHAR* AssetPath) const
{
    return LoadObject<UMaterialInterface>(nullptr, AssetPath);
}

void AFHFrontierWorld::BeginPlay()
{
    Super::BeginPlay();

    BuildEnvironment();
    BuildCity();
    BuildStarport();
    BuildOutskirts();
    BuildLighting();
    BuildNavigation();
    SpawnCombatPopulation();

    UE_LOG(
        LogTemp,
        Display,
        TEXT("FAR_HORIZON_FRONTIER_READY seed=1389 cityRadius=%.0f"),
        CityRadius);
}

void AFHFrontierWorld::AddBox(
    UHierarchicalInstancedStaticMeshComponent* Component,
    const FVector& Location,
    const FVector& SizeCm,
    const FRotator& Rotation)
{
    if (!Component || !CubeMesh)
    {
        return;
    }

    const FVector Scale(
        SizeCm.X / 100.0f,
        SizeCm.Y / 100.0f,
        SizeCm.Z / 100.0f);

    Component->AddInstance(
        FTransform(
            Rotation,
            Location,
            Scale));
}

void AFHFrontierWorld::AddCylinder(
    UHierarchicalInstancedStaticMeshComponent* Component,
    const FVector& Location,
    const FVector& SizeCm,
    const FRotator& Rotation)
{
    if (!Component || !CylinderMesh)
    {
        return;
    }

    const FVector Scale(
        SizeCm.X / 100.0f,
        SizeCm.Y / 100.0f,
        SizeCm.Z / 100.0f);

    Component->AddInstance(
        FTransform(
            Rotation,
            Location,
            Scale));
}

void AFHFrontierWorld::BuildEnvironment()
{
    // A broad desert ground plane. Later planet chunks replace this with
    // curved terrain, but the gameplay scale and visual language already match
    // the Far Horizon desert-settlement target.
    AddBox(
        SandInstances,
        FVector(0.0f, 0.0f, -60.0f),
        FVector(WorldRadius * 2.0f, WorldRadius * 2.0f, 100.0f));

    // Main arterial roads through the settlement.
    constexpr float RoadWidth = 700.0f;
    AddBox(
        RoadInstances,
        FVector(0.0f, 0.0f, 2.0f),
        FVector(WorldRadius * 1.6f, RoadWidth, 12.0f));

    AddBox(
        RoadInstances,
        FVector(0.0f, 0.0f, 2.0f),
        FVector(RoadWidth, WorldRadius * 1.6f, 12.0f));

    // Secondary streets form irregular blocks rather than one arena.
    for (int32 Index = -4; Index <= 4; ++Index)
    {
        if (Index == 0)
        {
            continue;
        }

        const float Offset = Index * 1850.0f;

        AddBox(
            RoadInstances,
            FVector(Offset, 0.0f, 4.0f),
            FVector(300.0f, CityRadius * 1.9f, 10.0f));

        AddBox(
            RoadInstances,
            FVector(0.0f, Offset, 4.0f),
            FVector(CityRadius * 1.9f, 300.0f, 10.0f));
    }
}

void AFHFrontierWorld::BuildCity()
{
    constexpr float Cell = 1850.0f;

    for (int32 GridX = -5; GridX <= 5; ++GridX)
    {
        for (int32 GridY = -5; GridY <= 5; ++GridY)
        {
            const FVector2D CellCenter(
                GridX * Cell,
                GridY * Cell);

            const float Radius = CellCenter.Size();
            if (Radius > CityRadius || Radius < 2200.0f)
            {
                continue;
            }

            const float Density =
                FMath::Clamp(1.15f - Radius / CityRadius, 0.18f, 0.95f);

            const int32 BuildingCount =
                FMath::Clamp(
                    FMath::RoundToInt(2.0f + Density * 7.0f + RandomStream.FRandRange(0.0f, 2.0f)),
                    2,
                    10);

            for (int32 BuildingIndex = 0; BuildingIndex < BuildingCount; ++BuildingIndex)
            {
                const float X =
                    CellCenter.X + RandomStream.FRandRange(-620.0f, 620.0f);

                const float Y =
                    CellCenter.Y + RandomStream.FRandRange(-620.0f, 620.0f);

                const float Width =
                    RandomStream.FRandRange(550.0f, 1250.0f);

                const float Depth =
                    RandomStream.FRandRange(500.0f, 1200.0f);

                const float Height =
                    RandomStream.FRandRange(380.0f, 850.0f) *
                    (1.0f + Density * 1.9f);

                UHierarchicalInstancedStaticMeshComponent* Facade =
                    Density > 0.63f && RandomStream.FRand() > 0.55f
                        ? CapitalWallInstances
                        : WallInstances;

                const float Yaw =
                    RandomStream.FRandRange(-7.0f, 7.0f);

                AddBox(
                    Facade,
                    FVector(X, Y, Height * 0.5f),
                    FVector(Width, Depth, Height),
                    FRotator(0.0f, Yaw, 0.0f));

                // Stepped desert-city roofline.
                if (RandomStream.FRand() > 0.34f)
                {
                    const float UpperHeight =
                        RandomStream.FRandRange(180.0f, 420.0f);

                    AddBox(
                        ConcreteInstances,
                        FVector(
                            X + RandomStream.FRandRange(-Width * 0.12f, Width * 0.12f),
                            Y + RandomStream.FRandRange(-Depth * 0.12f, Depth * 0.12f),
                            Height + UpperHeight * 0.5f),
                        FVector(
                            Width * RandomStream.FRandRange(0.38f, 0.7f),
                            Depth * RandomStream.FRandRange(0.38f, 0.7f),
                            UpperHeight),
                        FRotator(0.0f, Yaw, 0.0f));
                }

                if (RandomStream.FRand() > 0.72f)
                {
                    AddCylinder(
                        AntennaInstances,
                        FVector(X, Y, Height + 420.0f),
                        FVector(35.0f, 35.0f, 800.0f));
                }
            }
        }
    }
}

void AFHFrontierWorld::BuildStarport()
{
    // Monumental center visible from much of the city.
    AddCylinder(
        LandingPadInstances,
        FVector(0.0f, 0.0f, 35.0f),
        FVector(5200.0f, 5200.0f, 70.0f));

    AddBox(
        CapitalWallInstances,
        FVector(0.0f, 0.0f, 850.0f),
        FVector(3200.0f, 3200.0f, 1700.0f));

    AddBox(
        MetalInstances,
        FVector(0.0f, 0.0f, 2150.0f),
        FVector(1250.0f, 1250.0f, 900.0f));

    AddCylinder(
        AntennaInstances,
        FVector(0.0f, 0.0f, 3450.0f),
        FVector(140.0f, 140.0f, 1700.0f));

    for (int32 PadIndex = 0; PadIndex < 8; ++PadIndex)
    {
        const float Angle =
            static_cast<float>(PadIndex) / 8.0f * UE_TWO_PI;

        const float Radius =
            PadIndex % 2 == 0 ? 5200.0f : 6500.0f;

        const FVector PadLocation(
            FMath::Cos(Angle) * Radius,
            FMath::Sin(Angle) * Radius,
            18.0f);

        AddCylinder(
            LandingPadInstances,
            PadLocation,
            FVector(2200.0f, 2200.0f, 36.0f));

        // Readable grounded ship proxy: fuselage + wings + tail. These are
        // placeholders only until the local SWG mesh importer supplies real
        // converted ships.
        AddBox(
            MetalInstances,
            PadLocation + FVector(0.0f, 0.0f, 260.0f),
            FVector(1250.0f, 320.0f, 260.0f),
            FRotator(0.0f, FMath::RadiansToDegrees(Angle), 0.0f));

        AddBox(
            MetalInstances,
            PadLocation + FVector(0.0f, 0.0f, 245.0f),
            FVector(420.0f, 1350.0f, 80.0f),
            FRotator(0.0f, FMath::RadiansToDegrees(Angle), 0.0f));

        AddBox(
            MetalInstances,
            PadLocation + FVector(-430.0f, 0.0f, 480.0f),
            FVector(180.0f, 80.0f, 520.0f),
            FRotator(0.0f, FMath::RadiansToDegrees(Angle), 0.0f));
    }
}

void AFHFrontierWorld::BuildOutskirts()
{
    for (int32 Index = 0; Index < 130; ++Index)
    {
        const float Angle =
            RandomStream.FRandRange(0.0f, UE_TWO_PI);

        const float Radius =
            RandomStream.FRandRange(CityRadius + 1000.0f, WorldRadius * 0.88f);

        const float X = FMath::Cos(Angle) * Radius;
        const float Y = FMath::Sin(Angle) * Radius;

        if (RandomStream.FRand() < 0.58f)
        {
            const float Width = RandomStream.FRandRange(400.0f, 900.0f);
            const float Depth = RandomStream.FRandRange(380.0f, 950.0f);
            const float Height = RandomStream.FRandRange(300.0f, 700.0f);

            AddBox(
                WallInstances,
                FVector(X, Y, Height * 0.5f),
                FVector(Width, Depth, Height),
                FRotator(0.0f, RandomStream.FRandRange(0.0f, 360.0f), 0.0f));
        }
        else
        {
            // Moisture-vaporator-like silhouette.
            AddCylinder(
                MetalInstances,
                FVector(X, Y, 240.0f),
                FVector(150.0f, 150.0f, 480.0f));

            AddCylinder(
                AntennaInstances,
                FVector(X, Y, 610.0f),
                FVector(40.0f, 40.0f, 740.0f));
        }
    }
}

void AFHFrontierWorld::BuildLighting()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    USkyAtmosphereComponent* Atmosphere =
        NewObject<USkyAtmosphereComponent>(this, TEXT("FrontierSkyAtmosphere"));

    if (Atmosphere)
    {
        Atmosphere->SetMobility(EComponentMobility::Movable);
        Atmosphere->RegisterComponent();
    }

    ADirectionalLight* Sun = World->SpawnActor<ADirectionalLight>(
        FVector::ZeroVector,
        FRotator(-26.0f, -38.0f, 0.0f));

    if (Sun)
    {
        if (UDirectionalLightComponent* SunComponent =
            Cast<UDirectionalLightComponent>(Sun->GetLightComponent()))
        {
            SunComponent->SetMobility(EComponentMobility::Movable);
            SunComponent->SetIntensity(8.4f);
            SunComponent->SetLightColor(FLinearColor(1.0f, 0.78f, 0.55f));
            SunComponent->SetAtmosphereSunLight(true);
            SunComponent->SetAtmosphereSunLightIndex(0);
            SunComponent->SetDynamicShadowDistanceMovableLight(30000.0f);
        }
    }

    ASkyLight* Sky = World->SpawnActor<ASkyLight>();
    if (Sky && Sky->GetLightComponent())
    {
        Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);
        Sky->GetLightComponent()->SetIntensity(0.72f);
        Sky->GetLightComponent()->SetRealTimeCaptureEnabled(true);
    }

    AExponentialHeightFog* Fog =
        World->SpawnActor<AExponentialHeightFog>();

    if (Fog && Fog->GetComponent())
    {
        Fog->GetComponent()->SetMobility(EComponentMobility::Movable);
        Fog->GetComponent()->SetFogDensity(0.0038f);
        Fog->GetComponent()->SetFogHeightFalloff(0.21f);
        Fog->GetComponent()->SetStartDistance(4500.0f);
        Fog->GetComponent()->SetVolumetricFog(true);
    }
}

void AFHFrontierWorld::BuildNavigation()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    ANavMeshBoundsVolume* NavBounds =
        World->SpawnActor<ANavMeshBoundsVolume>(
            FVector(0.0f, 0.0f, 1200.0f),
            FRotator::ZeroRotator,
            Params);

    if (!NavBounds)
    {
        return;
    }

    NavBounds->SetActorScale3D(
        FVector(
            WorldRadius / 100.0f,
            WorldRadius / 100.0f,
            40.0f));

    if (UNavigationSystemV1* Navigation =
        FNavigationSystem::GetCurrent<UNavigationSystemV1>(World))
    {
        Navigation->OnNavigationBoundsUpdated(NavBounds);
    }
}

void AFHFrontierWorld::SpawnCombatPopulation()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    const FSoftClassPath EpicNpcPath(
        TEXT("/Game/Variant_Shooter/Blueprints/AI/BP_ShooterNPC.BP_ShooterNPC_C"));

    UClass* NpcClass = EpicNpcPath.TryLoadClass<APawn>();
    if (!NpcClass)
    {
        NpcClass = AFHEnemyCharacter::StaticClass();
    }

    const TArray<FVector> SpawnPoints = {
        FVector(5600.0f, 1800.0f, 120.0f),
        FVector(4200.0f, -2700.0f, 120.0f),
        FVector(-3600.0f, 3300.0f, 120.0f),
        FVector(-5200.0f, -1600.0f, 120.0f),
        FVector(1200.0f, 6100.0f, 120.0f),
        FVector(-1400.0f, -6000.0f, 120.0f),
    };

    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride =
        ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

    for (const FVector& SpawnPoint : SpawnPoints)
    {
        World->SpawnActor<APawn>(
            NpcClass,
            SpawnPoint,
            FRotator::ZeroRotator,
            Params);
    }
}
